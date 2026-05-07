from flask import Blueprint, render_template
from flask_login import login_required, current_user
from app.models import Match, Booking
from app.extensions import db

bp = Blueprint('finance', __name__)

@bp.route('/dashboard')
@login_required
def dashboard():
    if current_user.role not in ['admin', 'treasurer']:
        return "Access Denied", 403
        
    matches = Match.query.order_by(Match.date_time.desc()).all()
    
    total_revenue = 0
    pending_revenue = 0
    
    for match in matches:
        # Confirmed or Paid bookings count towards "Collected/Safe"
        confirmed_bookings = match.bookings.filter(Booking.status.in_(['confirmed', 'paid'])).count()
        total_revenue += confirmed_bookings * match.price
        
        # Approved (Awaiting Payment)
        pending_bookings = match.bookings.filter_by(status='approved').count()
        pending_revenue += pending_bookings * match.price

    # Pre-compute paid counts for template
    paid_counts = {}
    for match in matches:
        paid_counts[match.id] = match.bookings.filter(
            Booking.status.in_(['confirmed', 'paid'])).count()

    return render_template('finance/dashboard.html',
                         matches=matches,
                         total_revenue=total_revenue,
                         pending_revenue=pending_revenue,
                         paid_counts=paid_counts)
