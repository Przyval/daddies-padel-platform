"""LEGACY scoring engine — calculate_leaderboard, extracted MECHANICALLY from
app/routes/tournament.py (Step 4b). The algorithm is byte-identical to the
original; do NOT "improve" it here. legacy_flask_v1 tournaments are pinned to
this behavior. New behavior belongs to the canonical engine
(app/services/tournament_scoring), selected via scoring_engine_version.
"""
from collections import defaultdict

from sqlalchemy.orm import joinedload

from app.models import TournamentMatch


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
