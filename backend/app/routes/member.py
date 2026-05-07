from flask import Blueprint, render_template, redirect, url_for, flash, request, current_app
from flask_login import current_user, login_required
from app.models import Match, Booking
from app.extensions import db
import os
from datetime import datetime

bp = Blueprint('member', __name__)

@bp.route('/')
def index():
    matches = Match.query.filter(Match.date_time > db.func.now()).order_by(Match.date_time).all()
    user_bookings = {}
    if current_user.is_authenticated:
        # Get all match_ids that user has booked
        bookings = Booking.query.filter_by(user_id=current_user.id).all()
        user_bookings = {b.match_id: b.status for b in bookings}
        
    return render_template('member/dashboard.html', matches=matches, user_bookings=user_bookings, active_tab='home')

@bp.route('/dashboard')
@login_required 
def dashboard():
    return redirect(url_for('member.index'))

@bp.route('/join/<int:match_id>', methods=['POST'])
@login_required
def join_match(match_id):
    match = Match.query.get_or_404(match_id)
    
    # Check if already booked
    existing = Booking.query.filter_by(user_id=current_user.id, match_id=match_id).first()
    if existing:
        flash('You have already joined this session.', 'info')
        return redirect(url_for('member.index'))
        
    # Create booking (Default to Waitlist)
    booking = Booking(
        user_id=current_user.id,
        match_id=match_id,
        status='waitlist'
    )
    db.session.add(booking)
    db.session.commit()
    
    flash('Joined waitlist successfully! Admin will confirm shortly.', 'success')
    return redirect(url_for('member.index'))

@bp.route('/upload_payment/<int:match_id>', methods=['GET', 'POST'])
@login_required
def upload_payment(match_id):
    booking = Booking.query.filter_by(user_id=current_user.id, match_id=match_id).first_or_404()
    
    if booking.status != 'approved':
        flash('You can only upload payment for approved sessions.', 'error')
        return redirect(url_for('member.index'))
        
    if request.method == 'POST':
        if 'payment_proof' not in request.files:
            flash('No file part', 'error')
            return redirect(request.url)
            
        file = request.files['payment_proof']
        if file.filename == '':
            flash('No selected file', 'error')
            return redirect(request.url)
            
        if file:
            filename = f"payment_{booking.id}_{int(datetime.now().timestamp())}.jpg"
            filepath = os.path.join(current_app.root_path, 'static/uploads', filename)
            file.save(filepath)
            
            booking.payment_proof = f'uploads/{filename}'
            booking.status = 'paid'
            db.session.commit()
            
            flash('Payment proof uploaded! Waiting for verification.', 'success')
            return redirect(url_for('member.index'))
            
    return render_template('member/upload_payment.html', match=booking.match)
