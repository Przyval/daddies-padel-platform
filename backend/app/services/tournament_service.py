from app import db
from app.models import Tournament, TournamentRound, TournamentMatch, TournamentParticipant
import random

class TournamentService:
    @staticmethod
    def generate_schedule(tournament_id):
        tournament = Tournament.query.get(tournament_id)
        if not tournament:
            raise ValueError("Tournament not found")
        
        participants = tournament.participants.all()
        count = len(participants)
        
        if count % 4 != 0:
            raise ValueError(f"Player count {count} is not a multiple of 4. Americano requires multiples of 4 for this implementation.")
            
        # Clear existing rounds
        for round in tournament.rounds:
            db.session.delete(round)
        db.session.commit()
        
        if tournament.format == 'americano':
            TournamentService._generate_americano(tournament, participants)
        
        tournament.status = 'active'
        db.session.commit()

    @staticmethod
    def _generate_americano(tournament, participants):
        """
        Generates a simplified Americano schedule.
        """
        player_ids = [p.id for p in participants]
        random.shuffle(player_ids)
        
        # Determine number of rounds.
        num_rounds = len(player_ids) - 1 if len(player_ids) <= 8 else 8
        
        # Simple Logic for 4 players (Exact Round Robin)
        if len(player_ids) == 4:
            # Round 1: (0,1) vs (2,3)
            # Round 2: (0,2) vs (1,3)
            # Round 3: (0,3) vs (1,2)
            rounds_template = [
                [(0, 1, 2, 3)],
                [(0, 2, 1, 3)],
                [(0, 3, 1, 2)]
            ]
            
            for r_idx, match_groups in enumerate(rounds_template):
                tm_round = TournamentRound(tournament_id=tournament.id, round_number=r_idx + 1)
                db.session.add(tm_round)
                db.session.flush() # Get ID
                
                for group in match_groups:
                    p1 = player_ids[group[0]]
                    p2 = player_ids[group[1]]
                    p3 = player_ids[group[2]]
                    p4 = player_ids[group[3]]
                    
                    match = TournamentMatch(
                        round_id=tm_round.id,
                        team1_p1_id=p1, team1_p2_id=p2,
                        team2_p1_id=p3, team2_p2_id=p4
                    )
                    db.session.add(match)
            return

        # General approach for 8+ (Randomized Pairing)
        # Just create simple rounds for now.
        for i in range(num_rounds):
            tm_round = TournamentRound(tournament_id=tournament.id, round_number=i + 1)
            db.session.add(tm_round)
            db.session.flush()
            
            # Shuffle for this round
            current_round_players = player_ids[:]
            random.shuffle(current_round_players)
            
            # Create matches
            for j in range(0, len(current_round_players), 4):
                if j + 3 < len(current_round_players):
                    match = TournamentMatch(
                        round_id=tm_round.id,
                        team1_p1_id=current_round_players[j],
                        team1_p2_id=current_round_players[j+1],
                        team2_p1_id=current_round_players[j+2],
                        team2_p2_id=current_round_players[j+3]
                    )
                    db.session.add(match)

    @staticmethod
    def calculate_standings(tournament_id):
        """
        DERIVED STATE ENGINE
        Calculates the live leaderboard by re-playing the event log (matches).
        """
        tournament = Tournament.query.get(tournament_id)
        if not tournament:
            return []
            
        leaderboard = {} # pid -> {name, points, matches_played, points_diff}
        
        # Initialize
        for p in tournament.participants:
            leaderboard[p.id] = {
                'id': p.id,
                'name': p.name,
                'points': 0,
                'matches_played': 0,
                'avg_points': 0
            }
            
        # Replay History
        rounds = tournament.rounds.all()
        for tm_round in rounds:
            matches = tm_round.matches.all()
            for match in matches:
                # If match is played (has scores)
                s1 = match.score_team1
                s2 = match.score_team2
                
                # Team 1
                for pid in [match.team1_p1_id, match.team1_p2_id]:
                    if pid:
                        leaderboard[pid]['points'] += s1
                        leaderboard[pid]['matches_played'] += 1
                
                # Team 2
                for pid in [match.team2_p1_id, match.team2_p2_id]:
                    if pid:
                        leaderboard[pid]['points'] += s2
                        leaderboard[pid]['matches_played'] += 1

        # Check for unplayed players (if any) and calculate averages
        results = []
        for pid, stats in leaderboard.items():
            if stats['matches_played'] > 0:
                stats['avg_points'] = round(stats['points'] / stats['matches_played'], 1)
            results.append(stats)
            
        # Sort by Points DESC, then Avg Points DESC
        results.sort(key=lambda x: (x['points'], x['avg_points']), reverse=True)
        
        return results
