"""DB models -> canonical engine contracts. Fail-closed on corrupt data.

Field sources (single source of truth for the mapping):
  players                  TournamentParticipant.id, ordered by (seed, id)
  game round_number        TournamentRound.round_number
  game court               TournamentMatch.court  (extra_points: see note)
  game teams               TournamentMatch.team{1,2}_p{1,2}_id (all 4 required)
  completed?               TournamentMatch.status == 'completed'  (ONLY this —
                           presence of a score does NOT mean completed)
  points/sets              TournamentMatch.sets_json (parsed strictly here; the
                           model's .sets property swallows JSON errors, so we
                           do NOT use it)
  scoring_mode             Tournament.scoring_mode ('points'|'sets')
  court_count              Tournament.num_courts
  extra_points_from_round  Tournament.court_bonus_round
  points_for_won_game      Tournament.win_points
  points_for_even_game     Tournament.draw_points
  sort_by_wins             Tournament.sort_by_wins
  sort_head2head           Tournament.h2h_tiebreaker

NOTE per-court bonus VALUES: the reference engine supports a different bonus
per court, but the Flask schema has no per-court extra_points column — only the
boundary round (court_bonus_round). Until such a column exists, every court maps
to extra_points=0 (bonus mechanism wired, values empty). Documented gap.
"""
from __future__ import annotations

import json
from dataclasses import dataclass

from ..types import Court, EngineConfig, GameResult, Player, Team
from ..exceptions import InvalidTournamentScoringData


@dataclass(frozen=True)
class CanonicalTournamentInput:
    players: tuple[Player, ...]
    games: tuple[GameResult, ...]
    config: EngineConfig


def _parse_sets_strict(match_id, sets_json):
    """Strict sets_json parser. Returns tuple[(a, b), ...]. Raises on corruption."""
    raw = sets_json if sets_json is not None else '[]'
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError) as e:
        raise InvalidTournamentScoringData(match_id, f'invalid sets_json: {e}')
    if not isinstance(data, list):
        raise InvalidTournamentScoringData(match_id, 'sets_json is not a list')
    out = []
    for item in data:
        if not isinstance(item, (list, tuple)) or len(item) != 2:
            raise InvalidTournamentScoringData(match_id, f'set entry not a pair: {item!r}')
        a, b = item
        if not isinstance(a, int) or not isinstance(b, int) or isinstance(a, bool) or isinstance(b, bool):
            raise InvalidTournamentScoringData(match_id, f'set scores not ints: {item!r}')
        if a < 0 or b < 0:
            raise InvalidTournamentScoringData(match_id, f'negative set score: {item!r}')
        out.append((a, b))
    return tuple(out)


def adapt_tournament_to_engine_input(tournament) -> CanonicalTournamentInput:
    """Build pure engine input from a Tournament DB object. Read-only."""
    # Local import: adapters are the only layer that touches models.
    from app.models import TournamentParticipant

    participants = (tournament.participants
                    .order_by(TournamentParticipant.seed, TournamentParticipant.id)
                    .all())
    players = tuple(
        Player(id=p.id, source_order=i) for i, p in enumerate(participants)
    )
    known_ids = {p.id for p in players}

    is_points = tournament.scoring_mode == 'points'
    games: list[GameResult] = []

    for rnd in tournament.rounds.all():
        for match in rnd.matches.all():
            if match.status != 'completed':
                # pending / playing / canceled / future placeholders: never scored
                continue

            ids = (match.team1_p1_id, match.team1_p2_id,
                   match.team2_p1_id, match.team2_p2_id)
            if any(i is None for i in ids):
                raise InvalidTournamentScoringData(
                    match.id, 'completed match is missing players')
            unknown = [i for i in ids if i not in known_ids]
            if unknown:
                raise InvalidTournamentScoringData(
                    match.id, f'completed match references unknown participants {unknown}')

            sets = _parse_sets_strict(match.id, match.sets_json)
            if not sets:
                raise InvalidTournamentScoringData(
                    match.id, 'completed match has no recorded result')

            court = Court(number=match.court or 1, extra_points=0)  # see NOTE above
            if is_points:
                games.append(GameResult(
                    round_number=rnd.round_number,
                    court=court,
                    team_1=Team((ids[0], ids[1])),
                    team_2=Team((ids[2], ids[3])),
                    points_team_1=sum(a for a, _ in sets),
                    points_team_2=sum(b for _, b in sets),
                ))
            else:
                games.append(GameResult(
                    round_number=rnd.round_number,
                    court=court,
                    team_1=Team((ids[0], ids[1])),
                    team_2=Team((ids[2], ids[3])),
                    sets=sets,
                ))

    config = EngineConfig(
        scoring_mode='points' if is_points else 'sets',
        court_count=tournament.num_courts or 1,
        extra_points_from_round=tournament.court_bonus_round or 0,
        points_for_won_game=tournament.win_points if tournament.win_points is not None else 3,
        points_for_even_game=tournament.draw_points if tournament.draw_points is not None else 1,
        sort_by_wins=bool(tournament.sort_by_wins),
        sort_head2head=bool(tournament.h2h_tiebreaker),
    )
    return CanonicalTournamentInput(players=players, games=tuple(games), config=config)
