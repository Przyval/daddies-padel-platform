from flask import Blueprint, render_template, request, redirect, url_for, flash
from flask_login import login_required, current_user
from app.models import Match
from app.extensions import db
from datetime import datetime

bp = Blueprint('ops', __name__)

@bp.route('/dashboard')
@login_required
def dashboard():
    if current_user.role != 'admin':
        return "Access Denied", 403
    
    matches = Match.query.order_by(Match.date_time).all()
    return render_template('ops/dashboard.html', matches=matches)

@bp.route('/create_session', methods=['GET', 'POST'])
@login_required
def create_session():
    if current_user.role != 'admin':
        return "Access Denied", 403
        
    if request.method == 'POST':
        title = request.form['title']
        date_str = request.form['date']
        time_str = request.form['time']
        location = request.form['location']
        price = request.form['price']
        max_players = request.form['max_players']
        
        # Combine date and time
        dt_obj = datetime.strptime(f"{date_str} {time_str}", "%Y-%m-%d %H:%M")
        
        match = Match(
            title=title,
            date_time=dt_obj,
            location=location,
            price=int(price),
            max_players=int(max_players),
            status='open'
        )
        db.session.add(match)
        db.session.commit()
        
        flash('Session created successfully!', 'success')
        return redirect(url_for('ops.dashboard'))
        
    
    return render_template('ops/create_session.html')

@bp.route('/manage_session/<int:match_id>')
@login_required
def manage_session(match_id):
    if current_user.role != 'admin':
        return "Access Denied", 403
    
    match = Match.query.get_or_404(match_id)
    bookings = match.bookings.all()
    return render_template('ops/manage_session.html', match=match, bookings=bookings)

@bp.route('/update_booking/<int:booking_id>/<string:new_status>')
@login_required
def update_booking_status(booking_id, new_status):
    if current_user.role != 'admin':
        return "Access Denied", 403
        
    booking = Booking.query.get_or_404(booking_id)
    booking.status = new_status
    db.session.commit()
    
    flash(f'User {booking.player.username} status updated to {new_status}.', 'success')
    return redirect(url_for('ops.manage_session', match_id=booking.match_id))
