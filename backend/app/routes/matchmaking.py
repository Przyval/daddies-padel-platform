from flask import Blueprint, request, jsonify
from app.models import Match, Booking, db
from sqlalchemy import or_, and_
from datetime import datetime

bp = Blueprint('matchmaking', __name__)

@bp.route('/search', methods=['POST'])
def search_matches():
    """
    Parametric Search Engine for Matches.
    Mimics Playtomic's MatchFetchOptions.
    
    Payload:
    {
        "date_range": {"start": "ISO", "end": "ISO"},
        "level_range": {"min": 1.0, "max": 5.0}, # Placeholder for future implementation
        "location": "Daddies Court", # Optional
        "status": ["open", "waitlist"],
        "available_spots": true # Only matches with spots
    }
    """
    data = request.get_json() or {}
    
    query = Match.query
    
    # 1. Date Range
    if 'date_range' in data:
        start = data['date_range'].get('start')
        end = data['date_range'].get('end')
        if start:
            query = query.filter(Match.date_time >= datetime.fromisoformat(start))
        if end:
            query = query.filter(Match.date_time <= datetime.fromisoformat(end))
            
    # 2. Status
    if 'status' in data:
        statuses = data['status']
        if isinstance(statuses, list):
            query = query.filter(Match.status.in_(statuses))
    else:
        # Default to open matches if not specified? Or all?
        # Let's default to open if naive search
        pass
        
    # 3. Location
    if 'location' in data:
        query = query.filter(Match.location == data['location'])
        
    # Execute base query
    matches = query.all()
    
    # 4. In-Memory Filters (complex logic)
    results = []
    for m in matches:
        # Availability Filter
        if data.get('available_spots'):
            if m.confirmed_count >= m.max_players:
                continue
                
        results.append({
            'id': m.id,
            'title': m.title,
            'date_time': m.date_time.isoformat(),
            'location': m.location,
            'price': m.price,
            'status': m.status,
            'spots_total': m.max_players,
            'spots_taken': m.confirmed_count,
            'spots_waitlist': m.waitlist_count
        })
        
    return jsonify({
        'count': len(results),
        'results': results
    })
