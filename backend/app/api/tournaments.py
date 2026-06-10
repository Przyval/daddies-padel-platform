"""Tournament endpoints. Reuses the existing engine in routes/tournament.py
(calculate_leaderboard, round generators, _generate_all_rounds) and the
master_tournament_cascade — no logic is duplicated, only exposed as JSON.
"""
import json
from flask import request
from flask_jwt_extended import jwt_required
from app.extensions import db
from app.models import (
    Tournament, TournamentParticipant, TournamentRound, TournamentMatch,
    TournamentPlayoff, master_tournament_cascade,
)
from app.routes.tournament import (
    calculate_leaderboard, _generate_all_rounds,
    generate_mixicano_round, generate_team_mexicano_round, generate_mexicano_round,
)
from . import api_bp
from .helpers import ok, err, current_api_user, member_required
from .serializers import (
    tournament_summary, tournament_detail, tmatch_public, standing_row,
    playoff_public,
)


# ── helpers ────────────────────────────────────────────────────────────────

def _owner_or_admin(t, user):
    return user is not None and (user.role == 'admin' or t.created_by == user.id)


def _standings_rows(t):
    return [standing_row(s, i + 1) for i, s in enumerate(calculate_leaderboard(t))]


def _advance_round(t):
    """Generate / advance to the next round. Mirrors routes.tournament.next_round
    dispatch but returns (ok, message) instead of redirecting."""
    current = t.rounds.filter_by(round_number=t.current_round).first()
    if current and current.pending_count > 0:
        return False, f'Selesaikan Ronde {t.current_round} dulu ({current.pending_count} pending)'

    fmt = t.format
    active = TournamentParticipant.sitting_out_permanent == False  # noqa: E712

    def _materialize(matches, participants):
        next_num = t.total_rounds + 1
        rnd = TournamentRound(tournament_id=t.id, round_number=next_num)
        db.session.add(rnd)
        db.session.flush()
        for court_num, (team1, team2) in enumerate(matches, 1):
            db.session.add(TournamentMatch(
                tournament_id=t.id, round_id=rnd.id, court=court_num,
                team1_p1_id=participants[team1[0]].id,
                team1_p2_id=participants[team1[1]].id,
                team2_p1_id=participants[team2[0]].id,
                team2_p2_id=participants[team2[1]].id,
                status='pending',
            ))
        t.current_round = next_num
        return next_num

    if fmt in ('mixicano', 'mix_americano'):
        lb = calculate_leaderboard(t)
        parts = t.participants.filter(active).order_by(TournamentParticipant.seed).all()
        _materialize(generate_mixicano_round(parts, lb, t.num_courts, is_first_round=False), parts)
    elif fmt == 'team_mexicano':
        lb = calculate_leaderboard(t)
        parts = t.participants.filter(active).order_by(TournamentParticipant.seed).all()
        _materialize(generate_team_mexicano_round(parts, lb, t.num_courts, is_first_round=False), parts)
    elif fmt in ('mexicano', 'super_mexicano', 'club_mexicano'):
        lb = calculate_leaderboard(t)
        standings = [{'idx': i, 'points': s['points']} for i, s in enumerate(lb)]
        parts = [s['participant'] for s in lb]
        _materialize(generate_mexicano_round(standings, t.num_courts), parts)
    else:
        # Americano family: all rounds pre-generated; just advance the pointer.
        if t.current_round < t.total_rounds:
            t.current_round += 1
        else:
            return False, 'Sudah ronde terakhir'
    db.session.commit()
    return True, f'Ronde {t.current_round} siap'


# ── list / create ──────────────────────────────────────────────────────────

@api_bp.route('/tournaments', methods=['GET'])
@jwt_required()
def list_tournaments():
    status = request.args.get('status')
    q = Tournament.query.order_by(Tournament.date.desc())
    if status in ('draft', 'open', 'playing', 'completed'):
        q = q.filter_by(status=status)
    return ok([tournament_summary(t) for t in q.all()])


@api_bp.route('/tournaments', methods=['POST'])
@member_required
def create_tournament():
    user = current_api_user()
    data = request.get_json(silent=True) or {}
    name = (data.get('name') or '').strip()
    fmt = (data.get('format') or 'americano').strip()
    participants = data.get('participants') or []

    if not name:
        return err('VALIDATION', 'name wajib diisi', 422)
    if not isinstance(participants, list) or len(participants) < 4:
        return err('VALIDATION', 'Minimal 4 peserta', 422)

    t = Tournament(
        name=name,
        format=fmt,
        num_courts=int(data.get('num_courts') or 2),
        scoring_mode=(data.get('scoring_mode') or 'points'),
        points_per_game=int(data.get('points_per_game') or 21),
        status='playing',
        current_round=1,
        created_by=user.id,
    )
    db.session.add(t)
    db.session.flush()

    for i, p in enumerate(participants):
        if isinstance(p, str):
            p = {'name': p}
        db.session.add(TournamentParticipant(
            tournament_id=t.id,
            name=(p.get('name') or f'Player {i+1}').strip(),
            gender=(p.get('gender') or ''),
            user_id=p.get('user_id'),
            seed=p.get('seed', i + 1),
        ))
    db.session.flush()

    try:
        _generate_all_rounds(t)
    except Exception as e:  # generator can reject bad player counts per format
        db.session.rollback()
        return err('SCHEDULE_FAILED', f'Gagal membuat jadwal: {e}', 422)

    db.session.commit()
    return ok(tournament_detail(t, _standings_rows(t)), 201)


# ── detail / standings / delete ────────────────────────────────────────────

@api_bp.route('/tournaments/<int:tid>', methods=['GET'])
@jwt_required()
def get_tournament(tid):
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    return ok(tournament_detail(t, _standings_rows(t)))


@api_bp.route('/tournaments/<int:tid>/standings', methods=['GET'])
@jwt_required()
def get_standings(tid):
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    return ok(_standings_rows(t))


@api_bp.route('/tournaments/<int:tid>', methods=['DELETE'])
@jwt_required()
def delete_tournament(tid):
    user = current_api_user()
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    if not _owner_or_admin(t, user):
        return err('FORBIDDEN', 'Hanya pembuat/admin yang bisa menghapus', 403)
    db.session.delete(t)
    db.session.commit()
    return ok({'deleted': tid})


# ── scoring / rounds / complete ────────────────────────────────────────────

@api_bp.route('/tournaments/<int:tid>/score/<int:match_id>', methods=['POST'])
@jwt_required()
def score_match(tid, match_id):
    t = Tournament.query.get(tid)
    m = TournamentMatch.query.get(match_id)
    if t is None or m is None:
        return err('NOT_FOUND', 'Turnamen/match tidak ditemukan', 404)
    if m.tournament_id != tid:
        return err('FORBIDDEN', 'Match bukan bagian dari turnamen ini', 403)

    data = request.get_json(silent=True) or {}
    if t.scoring_mode == 'points':
        max_pts = t.points_per_game or 99
        try:
            s1 = max(0, min(max_pts, int(data.get('points_t1', 0))))
            s2 = max(0, min(max_pts, int(data.get('points_t2', 0))))
        except (ValueError, TypeError):
            return err('VALIDATION', 'points_t1/points_t2 harus angka', 422)
        m.sets = [[s1, s2]]
    else:
        raw = data.get('sets') or []
        sets = []
        for s in raw:
            try:
                a, b = int(s[0]), int(s[1])
                if a > 0 or b > 0:
                    sets.append([a, b])
            except (ValueError, TypeError, IndexError):
                return err('VALIDATION', 'sets harus list pasangan angka [[a,b],...]', 422)
        if not sets:
            return err('VALIDATION', 'Minimal satu set', 422)
        m.sets = sets

    m.status = 'completed'
    db.session.commit()
    return ok(tmatch_public(m))


@api_bp.route('/tournaments/<int:tid>/matches/<int:match_id>/cancel', methods=['POST'])
@jwt_required()
def cancel_match(tid, match_id):
    user = current_api_user()
    t = Tournament.query.get(tid)
    m = TournamentMatch.query.get(match_id)
    if t is None or m is None or m.tournament_id != tid:
        return err('NOT_FOUND', 'Match tidak ditemukan', 404)
    if not _owner_or_admin(t, user):
        return err('FORBIDDEN', 'Hanya pembuat/admin', 403)
    m.status = 'canceled'
    db.session.commit()
    return ok(tmatch_public(m))


@api_bp.route('/tournaments/<int:tid>/next_round', methods=['POST'])
@jwt_required()
def next_round(tid):
    user = current_api_user()
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    if not _owner_or_admin(t, user):
        return err('FORBIDDEN', 'Hanya pembuat/admin', 403)
    success, msg = _advance_round(t)
    if not success:
        return err('ROUND_BLOCKED', msg, 409)
    return ok(tournament_detail(t, _standings_rows(t)))


@api_bp.route('/tournaments/<int:tid>/complete', methods=['POST'])
@jwt_required()
def complete_tournament(tid):
    user = current_api_user()
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    if not _owner_or_admin(t, user):
        return err('FORBIDDEN', 'Hanya pembuat/admin', 403)
    # Idempotency guard: completing again would re-run the cascade and award
    # chips twice. Block repeat completion.
    if t.status == 'completed':
        return err('ALREADY_COMPLETED', 'Turnamen sudah selesai', 409)
    t.status = 'completed'
    events = master_tournament_cascade(t)  # chips, milestones, tier upgrades, notifs
    db.session.commit()
    return ok({'tournament': tournament_summary(t),
               'standings': _standings_rows(t),
               'events': events})


# ── settings ───────────────────────────────────────────────────────────────

@api_bp.route('/tournaments/<int:tid>/settings', methods=['GET', 'PATCH'])
@jwt_required()
def tournament_settings(tid):
    user = current_api_user()
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    if request.method == 'GET':
        return ok(tournament_detail(t)['settings'])

    if not _owner_or_admin(t, user):
        return err('FORBIDDEN', 'Hanya pembuat/admin', 403)
    data = request.get_json(silent=True) or {}
    if 'name' in data:
        t.name = (data['name'] or t.name).strip()
    if 'points_per_game' in data:
        new_ppg = int(data['points_per_game'])
        old_ppg = t.points_per_game
        t.points_per_game = new_ppg
        if new_ppg < old_ppg:  # cap existing scores over the new max
            for m in TournamentMatch.query.filter_by(tournament_id=tid, status='completed').all():
                capped = [[min(s[0], new_ppg), min(s[1], new_ppg)] for s in m.sets if len(s) == 2]
                if capped != m.sets:
                    m.sets = capped
    for f in ('win_points', 'draw_points', 'loss_points', 'court_bonus_round'):
        if f in data:
            setattr(t, f, int(data[f]))
    for f in ('sort_by_wins', 'h2h_tiebreaker'):
        if f in data:
            setattr(t, f, bool(data[f]))
    db.session.commit()
    return ok(tournament_detail(t)['settings'])


# ── playoff ────────────────────────────────────────────────────────────────

@api_bp.route('/tournaments/<int:tid>/playoff', methods=['GET'])
@jwt_required()
def get_playoff(tid):
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    rows = t.playoffs.order_by(TournamentPlayoff.bracket_round,
                               TournamentPlayoff.match_index).all()
    return ok([playoff_public(p) for p in rows])


@api_bp.route('/tournaments/<int:tid>/generate_playoff', methods=['POST'])
@jwt_required()
def generate_playoff(tid):
    user = current_api_user()
    t = Tournament.query.get(tid)
    if t is None:
        return err('NOT_FOUND', 'Turnamen tidak ditemukan', 404)
    if not _owner_or_admin(t, user):
        return err('FORBIDDEN', 'Hanya pembuat/admin', 403)

    data = request.get_json(silent=True) or {}
    size = int(data.get('bracket_size') or 4)
    if size not in (4, 8, 16):
        return err('VALIDATION', 'bracket_size harus 4, 8, atau 16', 422)

    lb = calculate_leaderboard(t)
    if len(lb) < size:
        return err('NOT_ENOUGH', f'Minimal {size} peserta', 422)

    TournamentPlayoff.query.filter_by(tournament_id=tid).delete()
    top = lb[:size]

    if size >= 8:
        half = size // 2
        for i in range(half):
            db.session.add(TournamentPlayoff(
                tournament_id=tid, bracket_round=1, match_index=i,
                team1_p1_id=top[i]['participant'].id,
                team2_p1_id=top[size - 1 - i]['participant'].id,
                status='pending'))
        # placeholder rounds up to the final
        rounds = {8: [2, 1], 16: [4, 2, 1]}[size]
        for r_idx, count in enumerate(rounds, start=2):
            for i in range(count):
                db.session.add(TournamentPlayoff(
                    tournament_id=tid, bracket_round=r_idx, match_index=i, status='pending'))
    else:
        db.session.add(TournamentPlayoff(
            tournament_id=tid, bracket_round=1, match_index=0,
            team1_p1_id=top[0]['participant'].id,
            team2_p1_id=top[3]['participant'].id, status='pending'))
        db.session.add(TournamentPlayoff(
            tournament_id=tid, bracket_round=1, match_index=1,
            team1_p1_id=top[1]['participant'].id,
            team2_p1_id=top[2]['participant'].id, status='pending'))
        db.session.add(TournamentPlayoff(
            tournament_id=tid, bracket_round=2, match_index=0, status='pending'))

    db.session.commit()
    rows = (TournamentPlayoff.query.filter_by(tournament_id=tid)
            .order_by(TournamentPlayoff.bracket_round, TournamentPlayoff.match_index).all())
    return ok([playoff_public(p) for p in rows], 201)


@api_bp.route('/tournaments/<int:tid>/playoff/<int:playoff_id>/score', methods=['POST'])
@jwt_required()
def score_playoff(tid, playoff_id):
    user = current_api_user()
    t = Tournament.query.get(tid)
    p = TournamentPlayoff.query.get(playoff_id)
    if t is None or p is None or p.tournament_id != tid:
        return err('NOT_FOUND', 'Playoff tidak ditemukan', 404)
    if not _owner_or_admin(t, user):
        return err('FORBIDDEN', 'Hanya pembuat/admin', 403)

    data = request.get_json(silent=True) or {}
    sets = []
    for s in (data.get('sets') or []):
        try:
            a, b = int(s[0]), int(s[1])
            if a > 0 or b > 0:
                sets.append([a, b])
        except (ValueError, TypeError, IndexError):
            return err('VALIDATION', 'sets harus [[a,b],...]', 422)
    if not sets:
        return err('VALIDATION', 'Minimal satu set', 422)

    p.sets_json = json.dumps(sets)
    p.status = 'completed'

    # Auto-advance winner to the next bracket round (mirrors web).
    winner_side = p.winner
    if winner_side:
        w_p1 = p.team1_p1_id if winner_side == 'team1' else p.team2_p1_id
        w_p2 = p.team1_p2_id if winner_side == 'team1' else p.team2_p2_id
        nxt = TournamentPlayoff.query.filter_by(
            tournament_id=tid, bracket_round=p.bracket_round + 1,
            match_index=p.match_index // 2).first()
        if nxt:
            if p.match_index % 2 == 0:
                nxt.team1_p1_id, nxt.team1_p2_id = w_p1, w_p2
            else:
                nxt.team2_p1_id, nxt.team2_p2_id = w_p1, w_p2
    db.session.commit()
    return ok(playoff_public(p))
