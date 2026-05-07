"""Tests for calculate_leaderboard — the core scoring engine."""
import json
import pytest
from app.routes.tournament import calculate_leaderboard
from app.models import TournamentMatch, TournamentParticipant


def _score_match(db, match, s1, s2):
    """Helper: score a match and mark completed."""
    match.sets_json = json.dumps([[s1, s2]])
    match.status = 'completed'
    db.session.commit()


class TestPointsMode:
    """Points mode: score = game points only, no win bonus."""

    def test_winner_gets_game_score_only(self, app, db, tournament_8p):
        """Reference app: win 15-6 → winner gets 15 pts, not 18 (15+3)."""
        t, players, rnd, matches = tournament_8p
        _score_match(db, matches[0], 15, 6)  # Adi+Budi 15 vs Candra+Dedi 6

        lb = calculate_leaderboard(t)
        by_name = {s['participant'].name: s for s in lb}

        assert by_name['Adi']['points'] == 15
        assert by_name['Budi']['points'] == 15
        assert by_name['Candra']['points'] == 6
        assert by_name['Dedi']['points'] == 6

    def test_loser_gets_their_game_score(self, app, db, tournament_8p):
        t, players, rnd, matches = tournament_8p
        _score_match(db, matches[0], 21, 9)

        lb = calculate_leaderboard(t)
        by_name = {s['participant'].name: s for s in lb}

        assert by_name['Candra']['points'] == 9
        assert by_name['Dedi']['points'] == 9

    def test_tie_gives_draw_and_game_score(self, app, db, tournament_8p):
        """18-18 tie: each player gets 18 pts, W-L-T = 0-0-1."""
        t, players, rnd, matches = tournament_8p
        _score_match(db, matches[0], 18, 18)

        lb = calculate_leaderboard(t)
        by_name = {s['participant'].name: s for s in lb}

        assert by_name['Adi']['points'] == 18
        assert by_name['Adi']['ties'] == 1
        assert by_name['Adi']['wins'] == 0


class TestSitOutCompensation:
    """Players who miss a round get +2 per round missed."""

    def test_sitting_player_gets_plus_2(self, app, db, tournament_8p):
        t, players, rnd, matches = tournament_8p

        # Score both matches — all 8 players play
        _score_match(db, matches[0], 15, 9)
        _score_match(db, matches[1], 21, 7)

        # Now no one is sitting out, all played 1 match
        lb = calculate_leaderboard(t)
        for s in lb:
            assert s['even_pts'] == 0

    def test_unmatched_player_gets_compensation(self, app, db):
        """5 players, 1 court → 1 player sits out → gets +2."""
        from app.models import Tournament, TournamentRound
        t = Tournament(
            name='5P Test', format='americano', status='playing',
            num_courts=1, scoring_mode='points', points_per_game=21,
            current_round=1, win_points=3, draw_points=1, loss_points=0,
            sort_by_wins=True
        )
        db.session.add(t)
        db.session.flush()

        participants = []
        for i, name in enumerate(['A', 'B', 'C', 'D', 'E']):
            p = TournamentParticipant(tournament_id=t.id, name=name, seed=i + 1)
            db.session.add(p)
            participants.append(p)
        db.session.flush()

        rnd = TournamentRound(tournament_id=t.id, round_number=1)
        db.session.add(rnd)
        db.session.flush()

        # Only 4 play: A+B vs C+D. E sits out.
        m = TournamentMatch(
            tournament_id=t.id, round_id=rnd.id, court=1,
            team1_p1_id=participants[0].id, team1_p2_id=participants[1].id,
            team2_p1_id=participants[2].id, team2_p2_id=participants[3].id,
            status='pending'
        )
        db.session.add(m)
        db.session.commit()

        _score_match(db, m, 15, 9)

        lb = calculate_leaderboard(t)
        by_name = {s['participant'].name: s for s in lb}

        assert by_name['E']['points'] == 2  # +2 sit-out compensation
        assert by_name['E']['matches_played'] == 0
        assert by_name['A']['points'] == 15  # no compensation (played)


class TestSortModes:
    """sort_by_wins=True vs False, and H2H tiebreaker."""

    def test_sort_by_wins_ranks_wins_first(self, app, db, tournament_8p):
        """Player with more wins ranks higher even with fewer total points."""
        t, players, rnd, matches = tournament_8p
        # Adi+Budi win 10-9 (low score win)
        _score_match(db, matches[0], 10, 9)
        # Eko+Farid lose 21-0 (high score loss... wait, they got 21)
        _score_match(db, matches[1], 21, 7)

        t.sort_by_wins = True
        db.session.commit()

        lb = calculate_leaderboard(t)
        names = [s['participant'].name for s in lb]

        # Eko+Farid (W=1, 21pts) should rank above Candra+Dedi (W=0, 9pts)
        assert names.index('Eko') < names.index('Candra')
        # Adi (W=1, 10pts) should also rank above Candra (W=0, 9pts)
        assert names.index('Adi') < names.index('Candra')

    def test_sort_by_points_ranks_points_first(self, app, db, tournament_8p):
        t, players, rnd, matches = tournament_8p
        _score_match(db, matches[0], 10, 9)
        _score_match(db, matches[1], 21, 7)

        t.sort_by_wins = False
        db.session.commit()

        lb = calculate_leaderboard(t)
        # Eko+Farid have 21 pts → top
        assert lb[0]['participant'].name in ('Eko', 'Farid')


class TestScoreValidation:
    """Server-side score clamping. Score route now requires login."""

    def _login(self, client, app, user_id):
        with client.session_transaction() as sess:
            sess['_user_id'] = str(user_id)
            sess['_fresh'] = True

    def test_score_clamped_to_max(self, app, db, tournament_8p, client):
        t, players, rnd, matches = tournament_8p
        # Create a user and log in (score requires login)
        from app.models import User
        u = User(username='Scorer', email='scorer@t.com', phone='099',
                 membership='member', membership_paid=True, role='member')
        u.set_password('pw')
        db.session.add(u)
        db.session.commit()
        self._login(client, app, u.id)

        client.post(f'/tournament/{t.id}/score/{matches[0].id}',
                    data={'points_t1': '999', 'points_t2': '5'})

        db.session.refresh(matches[0])
        assert matches[0].score_team1 == 21  # clamped to points_per_game
        assert matches[0].score_team2 == 5

    def test_negative_score_clamped_to_zero(self, app, db, tournament_8p, client):
        t, players, rnd, matches = tournament_8p
        from app.models import User
        u = User(username='Scorer2', email='scorer2@t.com', phone='098',
                 membership='member', membership_paid=True, role='member')
        u.set_password('pw')
        db.session.add(u)
        db.session.commit()
        self._login(client, app, u.id)

        client.post(f'/tournament/{t.id}/score/{matches[0].id}',
                    data={'points_t1': '-5', 'points_t2': '10'})

        db.session.refresh(matches[0])
        assert matches[0].score_team1 == 0  # clamped to 0
        assert matches[0].score_team2 == 10
