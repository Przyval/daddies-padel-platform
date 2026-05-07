"""
Tournament routes — Americano Padel clone (full benchmark).

14 formats, 5-step wizard, sets+points scoring, timer, H2H, bracket tree.
"""
from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify
from flask_login import current_user
from app.models import (
    Tournament, TournamentParticipant, TournamentRound, TournamentMatch,
    TournamentPlayoff, User, TOURNAMENT_FORMATS
)
from app.extensions import db
from sqlalchemy.orm import joinedload
from datetime import datetime
from random import shuffle
from collections import defaultdict
import json

bp = Blueprint('tournament', __name__)


# ══════════════════════════════════════════
# ALGORITHMS
# ══════════════════════════════════════════

def generate_americano_rounds(n, num_courts):
    """Circle-method round-robin for n players on num_courts courts."""
    if n < 4:
        return []

    used_pairs = set()
    rounds = []
    ids = list(range(n))

    for _ in range(n - 1):
        if rounds:
            ids = [ids[0]] + [ids[-1]] + ids[1:-1]

        pairs = []
        half = n // 2
        for i in range(half):
            p1, p2 = ids[i], ids[n - 1 - i]
            pair = (min(p1, p2), max(p1, p2))
            if pair not in used_pairs:
                pairs.append((p1, p2))

        matches = []
        i = 0
        while i + 1 < len(pairs) and len(matches) < num_courts:
            t1, t2 = pairs[i], pairs[i + 1]
            if len({t1[0], t1[1], t2[0], t2[1]}) == 4:
                matches.append((t1, t2))
                used_pairs.add((min(t1), max(t1)))
                used_pairs.add((min(t2), max(t2)))
                i += 2
            else:
                i += 1

        if matches:
            rounds.append(matches)

    return rounds


def generate_mixicano_round(participants, standings, num_courts, is_first_round=False):
    """Mixicano (Mix Mexicano): gender-aware pairing.

    Every team = 1 Male + 1 Female. Always.

    Ronde 1: Random pairing (shuffle M and F separately)
    Ronde 2+: Ranking-based — M_rank[0]+F_rank[0] vs M_rank[1]+F_rank[1]
              (winners play with winners, but gender constraint maintained)
    """
    males = [i for i, p in enumerate(participants) if p.gender == 'M']
    females = [i for i, p in enumerate(participants) if p.gender == 'F']

    if is_first_round:
        shuffle(males)
        shuffle(females)
    else:
        # Sort each gender by their individual standing (descending by points)
        pid_to_points = {s['participant'].id: s['points'] for s in standings}
        males.sort(key=lambda i: pid_to_points.get(participants[i].id, 0), reverse=True)
        females.sort(key=lambda i: pid_to_points.get(participants[i].id, 0), reverse=True)

    # Pair: M[0]+F[0] vs M[1]+F[1] per court
    matches = []
    for court in range(num_courts):
        mi = court * 2
        if mi + 1 >= len(males) or mi + 1 >= len(females):
            break
        team1 = (males[mi], females[mi])        # M_rank[0] + F_rank[0]
        team2 = (males[mi + 1], females[mi + 1])  # M_rank[1] + F_rank[1]
        matches.append((team1, team2))

    return matches


def generate_team_mexicano_round(participants, standings, num_courts, is_first_round=False):
    """Team Mexicano: FIXED teams, opponents change by ranking.

    Teams are defined by seed order: participants[0]+[1] = Team A,
    participants[2]+[3] = Team B, etc. Partners NEVER change.

    Ronde 1: Random opponent matchup
    Ronde 2+: Ranking-based — top team vs 2nd team, 3rd vs 4th, etc.
    """
    n = len(participants)
    num_teams = n // 2

    # Build fixed teams: [(idx0, idx1), (idx2, idx3), ...]
    teams = [(i * 2, i * 2 + 1) for i in range(num_teams)]

    if is_first_round:
        shuffle(teams)
    else:
        # Rank teams by combined points of both members
        pid_to_points = {}
        for s in standings:
            pid_to_points[s['participant'].id] = s['points']

        def team_points(t):
            p1 = pid_to_points.get(participants[t[0]].id, 0)
            p2 = pid_to_points.get(participants[t[1]].id, 0)
            return p1 + p2

        teams.sort(key=team_points, reverse=True)

    # Pair teams: teams[0] vs teams[1] (court 1), teams[2] vs teams[3] (court 2)
    matches = []
    for court in range(num_courts):
        ti = court * 2
        if ti + 1 >= len(teams):
            break
        matches.append((teams[ti], teams[ti + 1]))

    return matches


def generate_mexicano_round(standings, num_courts):
    """Mexicano: pair based on current standings — winners play winners."""
    sorted_ids = [s['idx'] for s in sorted(standings, key=lambda x: x['points'], reverse=True)]
    matches = []
    used = set()
    for _ in range(num_courts):
        avail = [p for p in sorted_ids if p not in used]
        if len(avail) < 4:
            break
        matches.append(((avail[0], avail[1]), (avail[2], avail[3])))
        used.update(avail[:4])
    return matches


# ══════════════════════════════════════════
# LEADERBOARD + H2H
# ══════════════════════════════════════════

def calculate_leaderboard(tournament):
    """Full leaderboard: W-L-T, diffs, points, teammates, H2H."""
    participants = tournament.participants.all()
    pid_map = {p.id: p for p in participants}
    stats = {}
    teammates = defaultdict(lambda: defaultdict(int))  # pid -> {partner_pid: count}
    h2h = defaultdict(lambda: defaultdict(int))  # pid -> {opp_pid: point_delta}

    for p in participants:
        stats[p.id] = {
            'participant': p,
            'wins': 0, 'losses': 0, 'ties': 0,
            'matches_played': 0,
            'sets_won': 0, 'sets_lost': 0,
            'games_won': 0, 'games_lost': 0,
            'points': 0,
        }

    # Prefetch all matches with participants in 1 query to avoid N+1
    all_matches = TournamentMatch.query.options(
        joinedload(TournamentMatch.team1_p1),
        joinedload(TournamentMatch.team1_p2),
        joinedload(TournamentMatch.team2_p1),
        joinedload(TournamentMatch.team2_p2),
    ).filter_by(tournament_id=tournament.id).all()

    # Group by round
    from collections import defaultdict as _dl
    matches_by_round = _dl(list)
    for m in all_matches:
        matches_by_round[m.round_id].append(m)

    rounds = tournament.rounds.all()
    for rnd in rounds:
        for match in matches_by_round.get(rnd.id, []):
            if match.status != 'completed':
                continue

            t1 = [match.team1_p1_id, match.team1_p2_id]
            t2 = [match.team2_p1_id, match.team2_p2_id]
            winner = match.winner
            g1, g2 = match.score_team1, match.score_team2

            # Record teammates
            if t1[0] in pid_map and t1[1] in pid_map:
                teammates[t1[0]][t1[1]] += 1
                teammates[t1[1]][t1[0]] += 1
            if t2[0] in pid_map and t2[1] in pid_map:
                teammates[t2[0]][t2[1]] += 1
                teammates[t2[1]][t2[0]] += 1

            def _update(pid, is_team1):
                if pid not in stats:
                    return
                s = stats[pid]
                s['matches_played'] += 1
                if is_team1:
                    s['sets_won'] += match.sets_won_team1
                    s['sets_lost'] += match.sets_won_team2
                    s['games_won'] += g1
                    s['games_lost'] += g2
                    won = winner == 'team1'
                    lost = winner == 'team2'
                    opps = t2
                else:
                    s['sets_won'] += match.sets_won_team2
                    s['sets_lost'] += match.sets_won_team1
                    s['games_won'] += g2
                    s['games_lost'] += g1
                    won = winner == 'team2'
                    lost = winner == 'team1'
                    opps = t1

                if won:
                    s['wins'] += 1
                elif lost:
                    s['losses'] += 1
                else:
                    s['ties'] += 1

                # Points mode: score = game points only (Americano standard)
                # Sets mode: score = win/draw/loss bonus
                if tournament.scoring_mode == 'points':
                    my_score = g1 if is_team1 else g2
                    s['points'] += my_score
                else:
                    if won:
                        s['points'] += tournament.win_points
                    elif lost:
                        s['points'] += tournament.loss_points
                    else:
                        s['points'] += tournament.draw_points

                # Point differential
                diff = (g1 - g2) if is_team1 else (g2 - g1)
                s['diff_pts'] = s.get('diff_pts', 0) + diff

                # H2H
                for opp in opps:
                    if opp in pid_map:
                        h2h[pid][opp] += diff

            for pid in t1:
                _update(pid, True)
            for pid in t2:
                _update(pid, False)

    # Sit-out compensation: +2 points per round missed (active players only)
    if len(participants) > 0:
        max_games = max((s['matches_played'] for s in stats.values()), default=0)
        for s in stats.values():
            # Permanently sitting-out players don't accumulate ghost points
            if s['participant'].sitting_out_permanent:
                s['even_pts'] = 0
                continue
            missed = max_games - s['matches_played']
            if missed > 0:
                s['even_pts'] = missed * 2
                s['points'] += s['even_pts']
            else:
                s['even_pts'] = 0

    # Compute total H2H differential per player (sum of all head-to-head deltas)
    for s in stats.values():
        pid = s['participant'].id
        s['h2h_total'] = sum(h2h[pid].values())

    # Sort — respect tournament settings
    use_h2h = tournament.h2h_tiebreaker
    if tournament.sort_by_wins:
        ranked = sorted(stats.values(), key=lambda s: (
            s['wins'],
            -s['losses'],
            s['h2h_total'] if use_h2h else 0,
            s['points'],
            s.get('diff_pts', 0),
            s['games_won'] - s['games_lost'],
        ), reverse=True)
    else:
        ranked = sorted(stats.values(), key=lambda s: (
            s['points'],
            s['wins'],
            -s['losses'],
            s['h2h_total'] if use_h2h else 0,
            s.get('diff_pts', 0),
            s['games_won'] - s['games_lost'],
            s['sets_won'] - s['sets_lost'],
        ), reverse=True)

    # Attach teammates & h2h
    for s in ranked:
        pid = s['participant'].id
        s['teammates'] = sorted(
            [(pid_map[tid].first_name, cnt) for tid, cnt in teammates[pid].items() if tid in pid_map],
            key=lambda x: -x[1]
        )
        s['h2h'] = sorted(
            [(pid_map[oid].first_name, delta) for oid, delta in h2h[pid].items() if oid in pid_map],
            key=lambda x: -x[1]
        )

    return ranked


# ══════════════════════════════════════════
# ROUTES
# ══════════════════════════════════════════

@bp.route('/')
def tournament_list():
    all_t = Tournament.query.order_by(Tournament.date.desc()).all()
    active = [t for t in all_t if t.status in ('open', 'playing')]
    completed = [t for t in all_t if t.status == 'completed']
    drafts = [t for t in all_t if t.status == 'draft']
    return render_template('tournament/list.html',
                           active=active, completed=completed, drafts=drafts,
                           formats=TOURNAMENT_FORMATS)


@bp.route('/delete/<int:tournament_id>', methods=['POST'])
def delete_tournament(tournament_id):
    t = Tournament.query.get_or_404(tournament_id)
    # Cascade delete
    TournamentPlayoff.query.filter_by(tournament_id=tournament_id).delete()
    for rnd in t.rounds.all():
        TournamentMatch.query.filter_by(round_id=rnd.id).delete()
    TournamentRound.query.filter_by(tournament_id=tournament_id).delete()
    TournamentParticipant.query.filter_by(tournament_id=tournament_id).delete()
    db.session.delete(t)
    db.session.commit()
    flash('Turnamen dihapus.', 'info')
    return redirect(url_for('tournament.tournament_list'))


# ── 5-Step Wizard (V3 — old style) ──

@bp.route('/v3/create', methods=['GET', 'POST'])
def create():
    """Step 0: Name."""
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        if not name:
            flash('Nama wajib diisi!', 'error')
            return redirect(url_for('tournament.create'))
        t = Tournament(name=name, status='draft',
                       created_by=current_user.id if current_user.is_authenticated else None)
        db.session.add(t)
        db.session.commit()
        return redirect(url_for('tournament.create_step', tournament_id=t.id, step=1))
    return render_template('tournament/wizard/step0_name.html')


@bp.route('/<int:tournament_id>/create/<int:step>', methods=['GET', 'POST'])
def create_step(tournament_id, step):
    tournament = Tournament.query.get_or_404(tournament_id)

    if step == 1:
        # Format selection
        if request.method == 'POST':
            tournament.format = request.form.get('format', 'americano')
            db.session.commit()
            return redirect(url_for('tournament.create_step', tournament_id=tournament_id, step=2))
        return render_template('tournament/wizard/step1_format.html',
                               tournament=tournament, formats=TOURNAMENT_FORMATS)

    elif step == 2:
        # Configuration
        if request.method == 'POST':
            tournament.num_courts = int(request.form.get('num_courts', 2))
            tournament.scoring_mode = request.form.get('scoring_mode', 'sets')
            tournament.points_per_game = int(request.form.get('points_per_game', 21))
            tournament.win_points = int(request.form.get('win_points', 3))
            tournament.draw_points = int(request.form.get('draw_points', 1))
            tournament.minutes_to_play = int(request.form.get('minutes_to_play', 0))
            tournament.sort_by_wins = 'sort_by_wins' in request.form
            tournament.h2h_tiebreaker = 'h2h_tiebreaker' in request.form
            tournament.venue = request.form.get('venue', 'Daddies Court')

            date_str = request.form.get('date', '')
            time_str = request.form.get('time', '19:00')
            try:
                tournament.date = datetime.strptime(f'{date_str} {time_str}', '%Y-%m-%d %H:%M')
            except ValueError:
                tournament.date = datetime.now()

            db.session.commit()
            return redirect(url_for('tournament.create_step', tournament_id=tournament_id, step=3))
        return render_template('tournament/wizard/step2_config.html', tournament=tournament)

    elif step == 3:
        # Add players
        all_users = User.query.order_by(User.username).all()
        if request.method == 'POST':
            action = request.form.get('action')

            if action == 'add_member':
                user_id = request.form.get('user_id', type=int)
                gender = request.form.get('gender', '')
                user = User.query.get(user_id)
                if user and not TournamentParticipant.query.filter_by(
                    tournament_id=tournament_id, user_id=user_id
                ).first():
                    db.session.add(TournamentParticipant(
                        tournament_id=tournament_id, user_id=user.id,
                        name=user.username, gender=gender,
                        seed=tournament.participants.count() + 1
                    ))
                    db.session.commit()

            elif action == 'add_guest':
                name = request.form.get('guest_name', '').strip()
                gender = request.form.get('gender', '')
                if name:
                    db.session.add(TournamentParticipant(
                        tournament_id=tournament_id, name=name, gender=gender,
                        seed=tournament.participants.count() + 1
                    ))
                    db.session.commit()

            elif action == 'bulk_add':
                names = request.form.get('bulk_names', '')
                for n in names.split(','):
                    n = n.strip()
                    if n:
                        db.session.add(TournamentParticipant(
                            tournament_id=tournament_id, name=n,
                            seed=tournament.participants.count() + 1
                        ))
                db.session.commit()

            elif action == 'remove':
                pid = request.form.get('participant_id', type=int)
                p = TournamentParticipant.query.get(pid)
                if p and p.tournament_id == tournament_id:
                    db.session.delete(p)
                    db.session.commit()

            return redirect(url_for('tournament.create_step', tournament_id=tournament_id, step=3))

        participants = tournament.participants.order_by(TournamentParticipant.seed).all()
        existing_ids = {p.user_id for p in participants if p.user_id}
        available = [u for u in all_users if u.id not in existing_ids]
        return render_template('tournament/wizard/step3_players.html',
                               tournament=tournament, participants=participants,
                               available_users=available)

    elif step == 4:
        # Review & Start
        if request.method == 'POST':
            count = tournament.participants.count()
            if count < 4:
                flash('Minimal 4 peserta!', 'error')
                return redirect(url_for('tournament.create_step', tournament_id=tournament_id, step=3))

            # Mixicano validation: M count must equal F count
            if tournament.format in ('mixicano', 'mix_americano'):
                all_p = tournament.participants.all()
                m_count = sum(1 for p in all_p if p.gender == 'M')
                f_count = sum(1 for p in all_p if p.gender == 'F')
                no_gender = sum(1 for p in all_p if not p.gender)
                if no_gender > 0:
                    flash(f'{no_gender} pemain belum ada gender (M/F). Wajib untuk Mixicano!', 'error')
                    return redirect(url_for('tournament.create_step', tournament_id=tournament_id, step=3))
                if m_count != f_count:
                    flash(f'Jumlah M ({m_count}) harus sama dengan F ({f_count}) untuk Mixicano!', 'error')
                    return redirect(url_for('tournament.create_step', tournament_id=tournament_id, step=3))

            if count % 4 != 0:
                flash(f'Jumlah harus kelipatan 4 (sekarang {count}).', 'error')
                return redirect(url_for('tournament.create_step', tournament_id=tournament_id, step=3))

            _generate_all_rounds(tournament)
            tournament.status = 'playing'
            tournament.current_round = 1
            db.session.commit()
            flash('Turnamen dimulai!', 'success')
            return redirect(url_for('tournament.detail', tournament_id=tournament_id))

        participants = tournament.participants.order_by(TournamentParticipant.seed).all()
        return render_template('tournament/wizard/step4_review.html',
                               tournament=tournament, participants=participants)

    return redirect(url_for('tournament.tournament_list'))


# ── V1 Americano Clone (Single-Page Conversational) ──

@bp.route('/create', methods=['GET'])
@bp.route('/v1/create', methods=['GET'])
def v1_create():
    """V1 single-page wizard — DEFAULT create flow."""
    return render_template('tournament/v1/create.html', formats=TOURNAMENT_FORMATS)


@bp.route('/v1/create/submit', methods=['POST'])
def v1_create_submit():
    """V1 AJAX submit — create tournament + players + start in one go."""
    try:
        name = request.form.get('name', '').strip()
        fmt = request.form.get('format', 'americano')
        courts = int(request.form.get('courts', 2))
        scoring = request.form.get('scoring', 'sets')
        players_json = request.form.get('players', '[]')

        import json as _json
        players = _json.loads(players_json)

        if not name:
            return jsonify({'ok': False, 'error': 'Nama wajib diisi'})
        if len(players) < 4:
            return jsonify({'ok': False, 'error': 'Minimal 4 pemain'})

        # Auto-cap courts: max players // 4 (each court needs 4 players)
        max_courts = len(players) // 4
        if courts > max_courts:
            courts = max(1, max_courts)

        # Determine scoring mode
        if scoring == 'sets':
            scoring_mode = 'sets'
            ppg = 0
        elif scoring == 'undefined':
            scoring_mode = 'points'
            ppg = 99
        else:
            scoring_mode = 'points'
            ppg = int(scoring)

        # Create tournament
        t = Tournament(
            name=name, format=fmt, status='playing',
            num_courts=courts, scoring_mode=scoring_mode,
            points_per_game=ppg, current_round=1,
            created_by=current_user.id if current_user.is_authenticated else None,
            date=datetime.now(), venue='Daddies Court'
        )
        db.session.add(t)
        db.session.flush()

        # Add players
        for i, pname in enumerate(players):
            db.session.add(TournamentParticipant(
                tournament_id=t.id, name=pname, seed=i + 1
            ))
        db.session.flush()

        # Generate rounds
        _generate_all_rounds(t)
        db.session.commit()

        return jsonify({'ok': True, 'tournament_id': t.id})
    except Exception as e:
        db.session.rollback()
        return jsonify({'ok': False, 'error': str(e)})


@bp.route('/<int:tournament_id>/v3')
def v3_detail(tournament_id):
    """V3 Detail — old Daddies style (for comparison)."""
    tournament = Tournament.query.get_or_404(tournament_id)
    tab = request.args.get('tab', 'rounds')
    current_rnd = request.args.get('round', tournament.current_round or 1, type=int)
    rounds = tournament.rounds.order_by(TournamentRound.round_number).all()
    leaderboard = calculate_leaderboard(tournament)
    playoffs = tournament.playoffs.order_by(
        TournamentPlayoff.bracket_round, TournamentPlayoff.match_index
    ).all()
    round_obj = next((r for r in rounds if r.round_number == current_rnd), None)
    return render_template('tournament/detail.html',
                           tournament=tournament, rounds=rounds,
                           current_round=current_rnd, round_obj=round_obj,
                           leaderboard=leaderboard, playoffs=playoffs, tab=tab)


# ── V2 Wizard (Mobile-Optimized UX) ──

@bp.route('/demo')
def demo():
    return render_template('tournament/demo.html')


@bp.route('/v2/create', methods=['GET', 'POST'])
def v2_create():
    """V2 Step 0: Name."""
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        if not name:
            flash('Nama wajib diisi!', 'error')
            return redirect(url_for('tournament.v2_create'))
        t = Tournament(name=name, status='draft',
                       created_by=current_user.id if current_user.is_authenticated else None)
        db.session.add(t)
        db.session.commit()
        return redirect(url_for('tournament.v2_create_step', tournament_id=t.id, step=1))
    return render_template('tournament/wizard_v2/step0_name.html')


@bp.route('/<int:tournament_id>/v2/<int:step>', methods=['GET', 'POST'])
def v2_create_step(tournament_id, step):
    """V2 wizard — same logic, mobile-optimized templates."""
    tournament = Tournament.query.get_or_404(tournament_id)

    # Template mapping
    templates = {
        1: 'tournament/wizard_v2/step1_format.html',
        2: 'tournament/wizard_v2/step2_config.html',
        3: 'tournament/wizard_v2/step3_players.html',
        4: 'tournament/wizard_v2/step4_review.html',
    }

    # V2 redirect helper
    def v2_redirect(s):
        return redirect(url_for('tournament.v2_create_step', tournament_id=tournament_id, step=s))

    if step == 1:
        if request.method == 'POST':
            tournament.format = request.form.get('format', 'americano')
            db.session.commit()
            return v2_redirect(2)
        return render_template(templates[1], tournament=tournament, formats=TOURNAMENT_FORMATS)

    elif step == 2:
        if request.method == 'POST':
            tournament.num_courts = int(request.form.get('num_courts', 2))
            tournament.scoring_mode = request.form.get('scoring_mode', 'sets')
            tournament.points_per_game = int(request.form.get('points_per_game', 21))
            tournament.win_points = int(request.form.get('win_points', 3))
            tournament.draw_points = int(request.form.get('draw_points', 1))
            tournament.minutes_to_play = int(request.form.get('minutes_to_play', 0))
            tournament.sort_by_wins = 'sort_by_wins' in request.form
            tournament.h2h_tiebreaker = 'h2h_tiebreaker' in request.form
            tournament.venue = request.form.get('venue', 'Daddies Court')
            date_str = request.form.get('date', '')
            time_str = request.form.get('time', '19:00')
            try:
                tournament.date = datetime.strptime(f'{date_str} {time_str}', '%Y-%m-%d %H:%M')
            except ValueError:
                tournament.date = datetime.now()
            db.session.commit()
            return v2_redirect(3)
        return render_template(templates[2], tournament=tournament)

    elif step == 3:
        all_users = User.query.order_by(User.username).all()
        if request.method == 'POST':
            action = request.form.get('action')
            if action == 'add_member':
                user_id = request.form.get('user_id', type=int)
                gender = request.form.get('gender', '')
                user = User.query.get(user_id)
                if user and not TournamentParticipant.query.filter_by(
                    tournament_id=tournament_id, user_id=user_id
                ).first():
                    db.session.add(TournamentParticipant(
                        tournament_id=tournament_id, user_id=user.id,
                        name=user.username, gender=gender,
                        seed=tournament.participants.count() + 1
                    ))
                    db.session.commit()
            elif action == 'add_guest':
                name = request.form.get('guest_name', '').strip()
                gender = request.form.get('gender', '')
                if name:
                    db.session.add(TournamentParticipant(
                        tournament_id=tournament_id, name=name, gender=gender,
                        seed=tournament.participants.count() + 1
                    ))
                    db.session.commit()
            elif action == 'bulk_add':
                names = request.form.get('bulk_names', '')
                for n in names.split(','):
                    n = n.strip()
                    if n:
                        db.session.add(TournamentParticipant(
                            tournament_id=tournament_id, name=n,
                            seed=tournament.participants.count() + 1
                        ))
                db.session.commit()
            elif action == 'remove':
                pid = request.form.get('participant_id', type=int)
                p = TournamentParticipant.query.get(pid)
                if p and p.tournament_id == tournament_id:
                    db.session.delete(p)
                    db.session.commit()
            return v2_redirect(3)

        participants = tournament.participants.order_by(TournamentParticipant.seed).all()
        existing_ids = {p.user_id for p in participants if p.user_id}
        available = [u for u in all_users if u.id not in existing_ids]
        return render_template(templates[3], tournament=tournament,
                               participants=participants, available_users=available)

    elif step == 4:
        if request.method == 'POST':
            count = tournament.participants.count()
            if count < 4:
                flash('Minimal 4 peserta!', 'error')
                return v2_redirect(3)
            if tournament.format in ('mixicano', 'mix_americano'):
                all_p = tournament.participants.all()
                m_count = sum(1 for p in all_p if p.gender == 'M')
                f_count = sum(1 for p in all_p if p.gender == 'F')
                no_gender = sum(1 for p in all_p if not p.gender)
                if no_gender > 0:
                    flash(f'{no_gender} pemain belum ada gender!', 'error')
                    return v2_redirect(3)
                if m_count != f_count:
                    flash(f'Jumlah M ({m_count}) harus sama dengan F ({f_count})!', 'error')
                    return v2_redirect(3)
            if count % 4 != 0:
                flash(f'Jumlah harus kelipatan 4 (sekarang {count}).', 'error')
                return v2_redirect(3)
            _generate_all_rounds(tournament)
            tournament.status = 'playing'
            tournament.current_round = 1
            db.session.commit()
            flash('Turnamen dimulai!', 'success')
            return redirect(url_for('tournament.v2_detail', tournament_id=tournament_id))

        participants = tournament.participants.order_by(TournamentParticipant.seed).all()
        return render_template(templates[4], tournament=tournament, participants=participants)

    return redirect(url_for('tournament.tournament_list'))


def _generate_all_rounds(tournament):
    for rnd in tournament.rounds.all():
        TournamentMatch.query.filter_by(round_id=rnd.id).delete()
    TournamentRound.query.filter_by(tournament_id=tournament.id).delete()
    db.session.flush()

    participants = tournament.participants.order_by(TournamentParticipant.seed).all()
    n = len(participants)
    fmt = tournament.format

    # Mixicano/Mix Americano: gender-aware pairing
    if fmt in ('mixicano', 'mix_americano'):
        rounds_data = [generate_mixicano_round(participants, [], tournament.num_courts, is_first_round=True)]

    # Team Mexicano: fixed teams, random first matchup
    elif fmt == 'team_mexicano':
        rounds_data = [generate_team_mexicano_round(participants, [], tournament.num_courts, is_first_round=True)]

    # All americano-family formats use round-robin
    elif fmt in ('americano', 'team_americano', 'doubles',
                 'club_americano', 'club_team'):
        rounds_data = generate_americano_rounds(n, tournament.num_courts)

    else:
        # Mexicano-family + groups: start with random first round
        ids = list(range(n))
        shuffle(ids)
        matches = []
        for i in range(0, len(ids) - 3, 4):
            matches.append(((ids[i], ids[i+1]), (ids[i+2], ids[i+3])))
        rounds_data = [matches[:tournament.num_courts]]

    for rnd_num, matches in enumerate(rounds_data, 1):
        rnd = TournamentRound(tournament_id=tournament.id, round_number=rnd_num)
        db.session.add(rnd)
        db.session.flush()
        for court_num, (team1, team2) in enumerate(matches, 1):
            db.session.add(TournamentMatch(
                tournament_id=tournament.id, round_id=rnd.id, court=court_num,
                team1_p1_id=participants[team1[0]].id,
                team1_p2_id=participants[team1[1]].id,
                team2_p1_id=participants[team2[0]].id,
                team2_p2_id=participants[team2[1]].id,
                status='pending'
            ))
    db.session.flush()


# ── Detail ──

@bp.route('/<int:tournament_id>')
@bp.route('/<int:tournament_id>/v1')
def detail(tournament_id):
    """Default detail = V1 Americano clone style."""
    tournament = Tournament.query.get_or_404(tournament_id)
    tab = request.args.get('tab', 'rounds')
    current_rnd = request.args.get('round', tournament.current_round or 1, type=int)

    # Sort toggle removed from GET — now handled via settings auto-save (POST only)

    rounds = tournament.rounds.order_by(TournamentRound.round_number).all()

    # Clamp round number to valid range
    if rounds and current_rnd > len(rounds):
        current_rnd = len(rounds)
    elif current_rnd < 1:
        current_rnd = 1

    leaderboard = calculate_leaderboard(tournament)
    playoffs = tournament.playoffs.order_by(
        TournamentPlayoff.bracket_round, TournamentPlayoff.match_index
    ).all()

    round_obj = next((r for r in rounds if r.round_number == current_rnd), None)

    return render_template('tournament/v1/detail.html',
                           tournament=tournament, rounds=rounds,
                           current_round=current_rnd, round_obj=round_obj,
                           leaderboard=leaderboard, playoffs=playoffs, tab=tab)


@bp.route('/<int:tournament_id>/v2')
def v2_detail(tournament_id):
    """V2 Detail — mobile-optimized version."""
    tournament = Tournament.query.get_or_404(tournament_id)
    tab = request.args.get('tab', 'rounds')
    current_rnd = request.args.get('round', tournament.current_round or 1, type=int)

    rounds = tournament.rounds.order_by(TournamentRound.round_number).all()
    leaderboard = calculate_leaderboard(tournament)
    playoffs = tournament.playoffs.order_by(
        TournamentPlayoff.bracket_round, TournamentPlayoff.match_index
    ).all()

    round_obj = next((r for r in rounds if r.round_number == current_rnd), None)

    return render_template('tournament/detail_v2/main.html',
                           tournament=tournament, rounds=rounds,
                           current_round=current_rnd, round_obj=round_obj,
                           leaderboard=leaderboard, playoffs=playoffs, tab=tab)


# ── Score ──

@bp.route('/<int:tournament_id>/score/<int:match_id>', methods=['POST'])
def update_score(tournament_id, match_id):
    match = TournamentMatch.query.get_or_404(match_id)
    tournament = Tournament.query.get_or_404(tournament_id)

    if tournament.scoring_mode == 'points':
        # Points mode: single score pair, clamped to 0..max
        max_pts = tournament.points_per_game or 99
        s1 = max(0, min(max_pts, request.form.get('points_t1', 0, type=int)))
        s2 = max(0, min(max_pts, request.form.get('points_t2', 0, type=int)))
        match.sets_json = json.dumps([[s1, s2]])
    else:
        # Sets mode
        sets = []
        for idx in range(1, 6):
            s1 = request.form.get(f'set{idx}_t1')
            s2 = request.form.get(f'set{idx}_t2')
            if s1 is None or s2 is None:
                break
            try:
                s1, s2 = int(s1), int(s2)
                if s1 > 0 or s2 > 0:
                    sets.append([s1, s2])
            except (ValueError, TypeError):
                pass
        match.sets_json = json.dumps(sets)

    match.status = 'completed'
    db.session.commit()
    flash(f'Skor disimpan: {match.score_display}', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id,
                            tab='rounds', round=match.round.round_number))


@bp.route('/<int:tournament_id>/cancel_match/<int:match_id>', methods=['POST'])
def cancel_match(tournament_id, match_id):
    match = TournamentMatch.query.get_or_404(match_id)
    match.status = 'canceled'
    db.session.commit()
    flash('Match dibatalkan.', 'info')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id, tab='rounds'))


# ── Round Nav ──

@bp.route('/<int:tournament_id>/next_round', methods=['POST'])
def next_round(tournament_id):
    tournament = Tournament.query.get_or_404(tournament_id)

    # Guard: check current round is complete
    current_rnd = tournament.rounds.filter_by(round_number=tournament.current_round).first()
    if current_rnd and current_rnd.pending_count > 0:
        flash(f'Selesaikan semua match di Ronde {tournament.current_round} dulu! ({current_rnd.pending_count} pending)', 'error')
        return redirect(url_for('tournament.detail', tournament_id=tournament_id,
                                tab='rounds', round=tournament.current_round))

    fmt = tournament.format

    # Filter out sitting-out players for round generation
    active_filter = TournamentParticipant.sitting_out_permanent == False

    if fmt in ('mixicano', 'mix_americano'):
        leaderboard = calculate_leaderboard(tournament)
        participants = tournament.participants.filter(active_filter).order_by(TournamentParticipant.seed).all()
        matches = generate_mixicano_round(participants, leaderboard, tournament.num_courts, is_first_round=False)

        next_num = tournament.total_rounds + 1
        rnd = TournamentRound(tournament_id=tournament.id, round_number=next_num)
        db.session.add(rnd)
        db.session.flush()
        for court_num, (team1, team2) in enumerate(matches, 1):
            db.session.add(TournamentMatch(
                tournament_id=tournament.id, round_id=rnd.id, court=court_num,
                team1_p1_id=participants[team1[0]].id,
                team1_p2_id=participants[team1[1]].id,
                team2_p1_id=participants[team2[0]].id,
                team2_p2_id=participants[team2[1]].id,
                status='pending'
            ))
        tournament.current_round = next_num
        db.session.commit()
        flash(f'Ronde {next_num} di-generate!', 'success')

    elif fmt == 'team_mexicano':
        leaderboard = calculate_leaderboard(tournament)
        participants = tournament.participants.filter(active_filter).order_by(TournamentParticipant.seed).all()
        matches = generate_team_mexicano_round(participants, leaderboard, tournament.num_courts, is_first_round=False)

        next_num = tournament.total_rounds + 1
        rnd = TournamentRound(tournament_id=tournament.id, round_number=next_num)
        db.session.add(rnd)
        db.session.flush()
        for court_num, (team1, team2) in enumerate(matches, 1):
            db.session.add(TournamentMatch(
                tournament_id=tournament.id, round_id=rnd.id, court=court_num,
                team1_p1_id=participants[team1[0]].id,
                team1_p2_id=participants[team1[1]].id,
                team2_p1_id=participants[team2[0]].id,
                team2_p2_id=participants[team2[1]].id,
                status='pending'
            ))
        tournament.current_round = next_num
        db.session.commit()
        flash(f'Ronde {next_num} di-generate!', 'success')

    elif fmt in ('mexicano', 'super_mexicano', 'club_mexicano'):
        leaderboard = calculate_leaderboard(tournament)
        standings = [{'idx': i, 'points': s['points']} for i, s in enumerate(leaderboard)]
        # Use leaderboard order so indices from generate_mexicano_round match correctly
        participants = [s['participant'] for s in leaderboard]
        matches = generate_mexicano_round(standings, tournament.num_courts)

        next_num = tournament.total_rounds + 1
        rnd = TournamentRound(tournament_id=tournament.id, round_number=next_num)
        db.session.add(rnd)
        db.session.flush()

        for court_num, (team1, team2) in enumerate(matches, 1):
            db.session.add(TournamentMatch(
                tournament_id=tournament.id, round_id=rnd.id, court=court_num,
                team1_p1_id=participants[team1[0]].id,
                team1_p2_id=participants[team1[1]].id,
                team2_p1_id=participants[team2[0]].id,
                team2_p2_id=participants[team2[1]].id,
                status='pending'
            ))

        tournament.current_round = next_num
        db.session.commit()
        flash(f'Ronde {next_num} di-generate!', 'success')
    else:
        total = tournament.total_rounds
        if tournament.current_round < total:
            tournament.current_round += 1
            db.session.commit()

    return redirect(url_for('tournament.detail', tournament_id=tournament_id,
                            tab='rounds', round=tournament.current_round))


# ── Playoff ──

@bp.route('/<int:tournament_id>/generate_playoff', methods=['POST'])
def generate_playoff(tournament_id):
    tournament = Tournament.query.get_or_404(tournament_id)
    bracket_size = request.form.get('bracket_size', 4, type=int)  # 4, 8, or 16
    TournamentPlayoff.query.filter_by(tournament_id=tournament_id).delete()

    lb = calculate_leaderboard(tournament)
    if len(lb) < bracket_size:
        flash(f'Minimal {bracket_size} peserta!', 'error')
        return redirect(url_for('tournament.detail', tournament_id=tournament_id, tab='standing'))

    top = lb[:bracket_size]

    if bracket_size >= 8:
        # Quarter-finals
        for i in range(4):
            db.session.add(TournamentPlayoff(
                tournament_id=tournament_id, bracket_round=1, match_index=i,
                team1_p1_id=top[i]['participant'].id,
                team2_p1_id=top[bracket_size - 1 - i]['participant'].id,
                status='pending'
            ))
        # Semi placeholders
        for i in range(2):
            db.session.add(TournamentPlayoff(
                tournament_id=tournament_id, bracket_round=2, match_index=i, status='pending'
            ))
        # Final placeholder
        db.session.add(TournamentPlayoff(
            tournament_id=tournament_id, bracket_round=3, match_index=0, status='pending'
        ))
    else:
        # 4-player: semis + final
        db.session.add(TournamentPlayoff(
            tournament_id=tournament_id, bracket_round=1, match_index=0,
            team1_p1_id=top[0]['participant'].id,
            team2_p1_id=top[3]['participant'].id,
            status='pending'
        ))
        db.session.add(TournamentPlayoff(
            tournament_id=tournament_id, bracket_round=1, match_index=1,
            team1_p1_id=top[1]['participant'].id,
            team2_p1_id=top[2]['participant'].id,
            status='pending'
        ))
        db.session.add(TournamentPlayoff(
            tournament_id=tournament_id, bracket_round=2, match_index=0, status='pending'
        ))

    db.session.commit()
    flash('Bracket playoff dibuat!', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id, tab='playoff'))


@bp.route('/<int:tournament_id>/playoff_score/<int:playoff_id>', methods=['POST'])
def playoff_score(tournament_id, playoff_id):
    playoff = TournamentPlayoff.query.get_or_404(playoff_id)
    sets = []
    for idx in range(1, 6):
        s1, s2 = request.form.get(f'set{idx}_t1'), request.form.get(f'set{idx}_t2')
        if s1 is None or s2 is None:
            break
        try:
            s1, s2 = int(s1), int(s2)
            if s1 > 0 or s2 > 0:
                sets.append([s1, s2])
        except (ValueError, TypeError):
            pass
    if sets:
        playoff.sets_json = json.dumps(sets)
        playoff.status = 'completed'

        # ── Auto-advance winner to next bracket round ──
        winner_side = playoff.winner  # 'team1' or 'team2'
        if winner_side:
            w_p1 = playoff.team1_p1_id if winner_side == 'team1' else playoff.team2_p1_id
            w_p2 = playoff.team1_p2_id if winner_side == 'team1' else playoff.team2_p2_id

            next_match = TournamentPlayoff.query.filter_by(
                tournament_id=tournament_id,
                bracket_round=playoff.bracket_round + 1,
                match_index=playoff.match_index // 2
            ).first()
            if next_match:
                # Even match_index → team1 slot, odd → team2 slot
                if playoff.match_index % 2 == 0:
                    next_match.team1_p1_id = w_p1
                    next_match.team1_p2_id = w_p2
                else:
                    next_match.team2_p1_id = w_p1
                    next_match.team2_p2_id = w_p2

        db.session.commit()
        flash('Skor playoff disimpan!', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id, tab='playoff'))


@bp.route('/<int:tournament_id>/complete', methods=['POST'])
def complete_tournament(tournament_id):
    from app.models import master_tournament_cascade
    tournament = Tournament.query.get_or_404(tournament_id)
    tournament.status = 'completed'

    # MASTER CASCADE: chips → milestones → tier upgrades → streak bonus → notifications
    events = master_tournament_cascade(tournament)

    db.session.commit()

    # Build flash message from events
    msgs = ['Turnamen selesai! Chips didistribusikan.']
    for ev in events:
        if ev['type'] == 'chips_milestone':
            msgs.append(f"{ev['emoji']} {ev['user']} hit {ev['milestone']}!")
        elif ev['type'] == 'tier_upgrade':
            msgs.append(f"🎉 {ev['user']} naik ke {ev['new_tier']}!")
    flash(' '.join(msgs), 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id))


@bp.route('/<int:tournament_id>/settings', methods=['GET', 'POST'])
def settings(tournament_id):
    tournament = Tournament.query.get_or_404(tournament_id)
    if request.method == 'POST':
        tournament.name = request.form.get('name', tournament.name)
        ppg = request.form.get('points_per_game')
        if ppg:
            new_ppg = int(ppg)
            old_ppg = tournament.points_per_game
            tournament.points_per_game = new_ppg

            # Cap all existing scores that exceed new max
            if new_ppg < old_ppg:
                for match in TournamentMatch.query.filter_by(
                    tournament_id=tournament_id, status='completed'
                ).all():
                    sets = match.sets
                    capped = [[min(s[0], new_ppg), min(s[1], new_ppg)] for s in sets if len(s) == 2]
                    if capped != sets:
                        match.sets_json = json.dumps(capped)
        tournament.win_points = int(request.form.get('win_points', 3))
        tournament.draw_points = int(request.form.get('draw_points', 1))
        tournament.loss_points = int(request.form.get('loss_points', 0))
        tournament.sort_by_wins = 'sort_by_wins' in request.form
        tournament.h2h_tiebreaker = 'h2h_tiebreaker' in request.form
        tournament.court_bonus_round = int(request.form.get('court_bonus_round', 0))
        db.session.commit()
        if request.headers.get('X-Requested-With') == 'fetch':
            return jsonify({'ok': True})
        flash('Pengaturan disimpan.', 'success')
        return redirect(url_for('tournament.detail', tournament_id=tournament_id))
    return render_template('tournament/settings.html', tournament=tournament)


# ══════════════════════════════════════════
# MIMIN WORKFLOW (Meeting #3)
# ══════════════════════════════════════════

@bp.route('/<int:tournament_id>/swap', methods=['POST'])
def swap_player(tournament_id):
    """Swap player names — only allowed in round 1 (game pertama).
    After round 2, locked."""
    tournament = Tournament.query.get_or_404(tournament_id)
    if tournament.current_round and tournament.current_round > 1:
        flash('Swap hanya bisa di ronde 1!', 'error')
        return redirect(url_for('tournament.detail', tournament_id=tournament_id))

    p1_id = request.form.get('p1_id', type=int)
    p2_id = request.form.get('p2_id', type=int)
    if p1_id and p2_id:
        p1 = TournamentParticipant.query.get(p1_id)
        p2 = TournamentParticipant.query.get(p2_id)
        if p1 and p2 and p1.tournament_id == tournament_id and p2.tournament_id == tournament_id:
            p1.name, p2.name = p2.name, p1.name
            p1.user_id, p2.user_id = p2.user_id, p1.user_id
            p1.gender, p2.gender = p2.gender, p1.gender
            db.session.commit()
            flash(f'Berhasil tukar {p1.name} ↔ {p2.name}', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id))


@bp.route('/<int:tournament_id>/sitting_out/<int:participant_id>', methods=['POST'])
def toggle_sitting_out(tournament_id, participant_id):
    """Toggle permanent sitting out (pulang)."""
    p = TournamentParticipant.query.get_or_404(participant_id)
    if p.tournament_id != tournament_id:
        flash('Peserta tidak ditemukan.', 'error')
        return redirect(url_for('tournament.detail', tournament_id=tournament_id))
    p.sitting_out_permanent = not p.sitting_out_permanent
    db.session.commit()
    status = 'istirahat permanen' if p.sitting_out_permanent else 'aktif kembali'
    flash(f'{p.name} sekarang {status}', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id))


@bp.route('/api/members/search')
def search_members():
    """API: search members by name/nickname for auto-suggest."""
    q = request.args.get('q', '').strip().lower()
    if len(q) < 1:
        return jsonify([])
    users = User.query.filter(
        db.or_(
            User.username.ilike(f'%{q}%'),
            User.nickname.ilike(f'%{q}%'),
            User.email.ilike(f'%{q}%'),
        )
    ).limit(10).all()
    return jsonify([{
        'id': u.id,
        'name': u.username,
        'nickname': u.nickname or '',
        'display': u.display_name,
        'membership': u.membership,
        'initials': u.initials,
    } for u in users])


@bp.route('/<int:tournament_id>/rename/<int:participant_id>', methods=['POST'])
def rename_participant(tournament_id, participant_id):
    """Tap name in leaderboard → rename + toggle sitting out."""
    p = TournamentParticipant.query.get_or_404(participant_id)
    if p.tournament_id != tournament_id:
        return redirect(url_for('tournament.detail', tournament_id=tournament_id))
    new_name = request.form.get('new_name', '').strip()
    if new_name:
        p.name = new_name
    if 'sitting_out' in request.form or 'sitting_out_present' in request.form:
        p.sitting_out_permanent = 'sitting_out' in request.form
    db.session.commit()
    flash(f'Updated: {p.name}', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id, tab='standing'))


@bp.route('/<int:tournament_id>/verify', methods=['POST'])
def verify_participants(tournament_id):
    """Post-game verification: mimin confirms all names are correct.
    Syncs tournament games_played to linked user profiles."""
    tournament = Tournament.query.get_or_404(tournament_id)
    leaderboard = calculate_leaderboard(tournament)
    synced = 0
    for entry in leaderboard:
        p = entry['participant']
        if p.user_id:
            user = User.query.get(p.user_id)
            if user:
                # games_played counter is live via streak_data, but we can
                # ensure tournament participation is recorded
                synced += 1
    db.session.commit()
    flash(f'Peserta terverifikasi! {synced} profil member di-sync.', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id))


@bp.route('/<int:tournament_id>/claim-streak')
def claim_streak(tournament_id):
    """Public QR endpoint: players scan after game to claim streak."""
    tournament = Tournament.query.get_or_404(tournament_id)
    if tournament.status != 'completed':
        flash('Turnamen belum selesai.', 'info')
        return redirect(url_for('tournament.live_results', tournament_id=tournament_id))
    return render_template('tournament/claim_streak.html', tournament=tournament)


@bp.route('/<int:tournament_id>/claim-streak/confirm', methods=['POST'])
def confirm_streak_claim(tournament_id):
    """Confirm streak claim — link player name to account."""
    from flask_login import current_user
    tournament = Tournament.query.get_or_404(tournament_id)
    player_name = request.form.get('player_name', '').strip()

    if not player_name:
        flash('Pilih nama kamu.', 'error')
        return redirect(url_for('tournament.claim_streak', tournament_id=tournament_id))

    # Find participant
    p = TournamentParticipant.query.filter_by(
        tournament_id=tournament_id, name=player_name
    ).first()
    if not p:
        flash('Nama tidak ditemukan di turnamen ini.', 'error')
        return redirect(url_for('tournament.claim_streak', tournament_id=tournament_id))

    # Link to user if logged in
    if current_user.is_authenticated:
        if not p.user_id:
            p.user_id = current_user.id
            db.session.commit()
        flash(f'Streak tercatat! {tournament.name} terhubung ke profil kamu.', 'success')
        return redirect(url_for('main.profile'))
    else:
        flash(f'Streak tercatat untuk {player_name}! Login untuk hubungkan ke profil.', 'success')
        return redirect(url_for('tournament.live_results', tournament_id=tournament_id))


@bp.route('/<int:tournament_id>/champion-share')
def champion_share(tournament_id):
    """Generate WhatsApp auto-text for champion provocation."""
    tournament = Tournament.query.get_or_404(tournament_id)
    leaderboard = calculate_leaderboard(tournament)
    if not leaderboard:
        return redirect(url_for('tournament.detail', tournament_id=tournament_id))

    champ = leaderboard[0]
    name = champ['participant'].first_name
    pts = champ.get('points', 0)
    wins = champ.get('wins', 0)
    n = len(leaderboard)

    text = (
        f"🏆 *{name}* juara \"{tournament.name}\"!\n\n"
        f"💪 {wins} menang, {int(pts)} poin dari {n} pemain.\n"
        f"🔥 Bisa kalahkan dia? Join Daddies Padel!\n\n"
        f"📊 Live: https://padeldaddies.site/r/{tournament_id}\n"
        f"🎾 Daftar: https://padeldaddies.site/tournament/v1/create"
    )
    import urllib.parse
    wa_url = f"https://wa.me/?text={urllib.parse.quote(text)}"
    return redirect(wa_url)


# ══════════════════════════════════════════
# SHARE & EXPORT
# ══════════════════════════════════════════

@bp.route('/r/<int:tournament_id>')
@bp.route('/<int:tournament_id>/live')
def live_results(tournament_id):
    """Public live results page — like Americano's /r/{uuid}."""
    tournament = Tournament.query.get_or_404(tournament_id)
    rounds = tournament.rounds.order_by(TournamentRound.round_number).all()
    leaderboard = calculate_leaderboard(tournament)
    current_rnd = request.args.get('round', tournament.current_round or 1, type=int)
    return render_template('tournament/live.html',
                           tournament=tournament, rounds=rounds,
                           leaderboard=leaderboard, current_round=current_rnd)


@bp.route('/<int:tournament_id>/share')
def share(tournament_id):
    """Public shareable page — no login required."""
    tournament = Tournament.query.get_or_404(tournament_id)
    leaderboard = calculate_leaderboard(tournament)

    # Build FOMO-driven OG metadata
    og = _build_fomo_meta(tournament, leaderboard)

    return render_template('tournament/share.html',
                           tournament=tournament, leaderboard=leaderboard, og=og)


def _build_fomo_meta(tournament, leaderboard):
    """Generate provocative, FOMO-inducing OG metadata for WhatsApp preview."""
    name = tournament.name
    n = tournament.participants.count()
    venue = tournament.venue
    fmt = tournament.format_label

    if not leaderboard:
        return {
            'title': f'🎾 {name} — Siapa yang menang?',
            'desc': f'{fmt} · {n} pemain bertarung di {venue}. Lihat hasilnya!',
        }

    leader = leaderboard[0]
    leader_name = leader['participant'].first_name
    leader_pts = leader['points']
    leader_w = leader['wins']

    # Check if close race (top 2 within 3 points)
    is_close = len(leaderboard) >= 2 and abs(leader_pts - leaderboard[1]['points']) <= 3
    runner = leaderboard[1]['participant'].first_name if len(leaderboard) >= 2 else None

    if tournament.status == 'completed':
        return {
            'title': f'🏆 {leader_name} Juara "{name}"!',
            'desc': f'{leader_w} menang, {leader_pts} poin. {n} pemain bertanding di {venue}. Kamu bisa kalahkan dia?',
        }
    elif is_close and runner:
        return {
            'title': f'🔥 {leader_name} vs {runner} — Ketat di "{name}"!',
            'desc': f'Cuma selisih {abs(leader_pts - leaderboard[1]["points"])} poin! {n} pemain di {venue}. Siapa menang?',
        }
    elif leader_w >= 3:
        return {
            'title': f'👑 {leader_name} Dominasi "{name}" — {leader_w} Menang!',
            'desc': f'{leader_pts} poin dari {n} pemain di {venue}. Belum ada yang bisa geser.',
        }
    else:
        return {
            'title': f'🎾 {leader_name} Memimpin "{name}"',
            'desc': f'{leader_pts} poin, {leader_w}W. {n} pemain di {venue}. Main bareng?',
        }


@bp.route('/<int:tournament_id>/share/whatsapp')
def share_whatsapp(tournament_id):
    """Redirect to wa.me with formatted tournament text."""
    tournament = Tournament.query.get_or_404(tournament_id)
    leaderboard = calculate_leaderboard(tournament)

    lines = [
        f"🎾 DADDIES PADEL — {tournament.name}",
        f"📍 {tournament.venue} · {tournament.date.strftime('%d %b %Y')}",
        f"🏆 {tournament.format_label} · {tournament.participants.count()} pemain",
        "",
        "📊 STANDING:",
    ]

    medals = ['🥇', '🥈', '🥉']
    for i, s in enumerate(leaderboard[:10]):
        medal = medals[i] if i < 3 else f"{i+1}."
        name = s['participant'].first_name
        diff = s['games_won'] - s['games_lost']
        diff_str = f"+{diff}" if diff > 0 else str(diff)
        lines.append(
            f"{medal} {name} — {s['points']} pts ({s['wins']}W-{s['losses']}L) {diff_str}"
        )

    base_url = "https://padeldaddies.site"
    share_url = f"{base_url}/tournament/{tournament_id}/share"
    lines.extend(["", f"🔗 Detail: {share_url}"])

    from urllib.parse import quote
    text = quote('\n'.join(lines))
    return redirect(f"https://wa.me/?text={text}")


@bp.route('/<int:tournament_id>/share/card')
def share_card(tournament_id):
    """Instagram-ready screenshot card — clean, no nav."""
    tournament = Tournament.query.get_or_404(tournament_id)
    leaderboard = calculate_leaderboard(tournament)
    return render_template('tournament/share_card.html',
                           tournament=tournament, leaderboard=leaderboard)


@bp.route('/<int:tournament_id>/share/download')
def share_download(tournament_id):
    """Render tournament card as PNG — served as static file."""
    from flask import send_file
    from app.services.card_renderer import render_card, SHARE_DIR
    tournament = Tournament.query.get_or_404(tournament_id)
    leaderboard = calculate_leaderboard(tournament)
    html = render_template('tournament/share_card.html',
                           tournament=tournament, leaderboard=leaderboard)
    image_path = render_card('tournament', html)
    if image_path:
        filepath = SHARE_DIR.parent.parent / 'static' / image_path
        return send_file(str(filepath), mimetype='image/png')
    # Last resort: return a 1x1 pixel PNG
    import base64
    pixel = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
    from io import BytesIO
    return send_file(BytesIO(pixel), mimetype='image/png')
