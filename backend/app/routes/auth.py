from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify
from flask_login import login_user, logout_user, current_user
from app.models import User
from app.extensions import db
from app.utils.referral import use_code, membership_price_for, ensure_code, validate_code

bp = Blueprint('auth', __name__)

@bp.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('member.dashboard'))
    
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        user = User.query.filter_by(email=email).first()
        
        if user is None or not user.check_password(password):
            flash('Invalid email or password', 'error')
            return redirect(url_for('auth.login'))
        
        login_user(user)
        flash('Logged in successfully.', 'success')
        
        next_page = request.args.get('next')
        if not next_page or not next_page.startswith('/'):
            if user.role == 'admin':
                next_page = url_for('ops.dashboard')
            elif user.role == 'treasurer':
                next_page = url_for('finance.dashboard')
            else:
                next_page = url_for('member.dashboard')
        return redirect(next_page)
        
    return render_template('auth/login.html')

@bp.route('/register', methods=['GET', 'POST'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('member.dashboard'))

    if request.method == 'POST':
        username = request.form['username']
        email = request.form['email']
        phone = request.form['phone']
        password = request.form['password']
        referral = request.form.get('referral_code', '').strip().upper()

        if User.query.filter_by(email=email).first():
            flash('Email sudah terdaftar', 'error')
            return redirect(url_for('auth.register'))

        if User.query.filter_by(phone=phone).first():
            flash('Nomor HP sudah terdaftar', 'error')
            return redirect(url_for('auth.register'))

        user = User(username=username, email=email, phone=phone, role='member')
        user.set_password(password)
        db.session.add(user)
        db.session.flush()  # get user.id before referral logic

        # Ensure this new user gets their own referral code
        ensure_code(user)

        # Apply referral code if provided
        if referral:
            ok, msg = use_code(referral, user)
            if ok:
                flash(f'Referral valid! {msg}', 'success')
            else:
                flash(f'Kode referral tidak valid: {msg}', 'warning')

        db.session.commit()
        flash('Registrasi berhasil! Silakan login.', 'success')
        return redirect(url_for('auth.login'))

    # Pass referral code from URL param so invite links auto-fill
    prefill_code = request.args.get('ref', '')
    return render_template('auth/register.html', prefill_code=prefill_code)


@bp.route('/validate-referral', methods=['GET'])
def validate_referral():
    """AJAX: check if a referral code is valid. Returns price info."""
    code = request.args.get('code', '').strip().upper()
    owner = validate_code(code)
    if owner:
        return jsonify({
            'valid': True,
            'price': 200000,
            'price_display': 'Rp 200.000',
            'message': f'Kode valid! Diundang oleh {owner.first_name}'
        })
    return jsonify({
        'valid': False,
        'price': 400000,
        'price_display': 'Rp 400.000',
        'message': 'Kode tidak valid atau sudah penuh'
    })

@bp.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('member.dashboard'))
