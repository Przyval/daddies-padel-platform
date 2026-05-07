from app import create_app, db
from app import create_app, db
from app.models import User, Tournament, TournamentParticipant, TournamentRound, TournamentMatch
from app.services.tournament_service import TournamentService
import random

def test_americano_logic():
    app = create_app()
    with app.app_context():
        # Clean up
        db.session.query(TournamentMatch).delete()
        db.session.query(TournamentRound).delete()
        db.session.query(TournamentParticipant).delete()
        db.session.query(Tournament).delete()
        db.session.commit()

        print("--- Setting up Tournament ---")
        t = Tournament(name="Test Americano", format="americano")
        db.session.add(t)
        db.session.commit()
        
        # Add 4 dummy players
        players = ["Alice", "Bob", "Charlie", "David"]
        for p_name in players:
            tp = TournamentParticipant(tournament_id=t.id, name=p_name)
            db.session.add(tp)
        db.session.commit()
        
        print("--- Generating Schedule ---")
        TournamentService.generate_schedule(t.id)
        
        rounds = t.rounds.all()
        print(f"Generated {len(rounds)} rounds.")
        for r in rounds:
            matches = r.matches.all()
            print(f"Round {r.round_number}: {len(matches)} matches")
            for m in matches:
                print(f"  Match: {m.team1_p1.name}/{m.team1_p2.name} vs {m.team2_p1.name}/{m.team2_p2.name}")
        
        print("\n--- Simulating Gameplay (Event Sourcing) ---")
        # Round 1
        r1 = rounds[0]
        m1 = r1.matches.first()
        m1.score_team1 = 14
        m1.score_team2 = 10
        db.session.commit()
        print(f"Match 1 Played: {m1.score_team1}-{m1.score_team2}")
        
        print("\n--- Calculating Standings (Derived State) ---")
        standings = TournamentService.calculate_standings(t.id)
        for rank, s in enumerate(standings, 1):
            print(f"{rank}. {s['name']} - Points: {s['points']} (Avg: {s['avg_points']})")
        
        # Verify logic dynamically based on who played match 1
        t1_p1 = m1.team1_p1.name
        t1_p2 = m1.team1_p2.name
        t2_p1 = m1.team2_p1.name
        t2_p2 = m1.team2_p2.name
        
        print(f"DEBUG: Team 1 ({t1_p1}, {t1_p2}) scored 14. Team 2 ({t2_p1}, {t2_p2}) scored 10.")

        p1_stats = next(p for p in standings if p['name'] == t1_p1)
        assert p1_stats['points'] == 14, f"Expected {t1_p1} to have 14 points, got {p1_stats['points']}"
        
        p3_stats = next(p for p in standings if p['name'] == t2_p1)
        assert p3_stats['points'] == 10, f"Expected {t2_p1} to have 10 points, got {p3_stats['points']}"
        
        print("\n✅ Americano Logic Verified Successfully!")

if __name__ == "__main__":
    test_americano_logic()
