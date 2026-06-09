"""Session (Match) endpoints — list, detail, create, join, payment, history.
Mirrors the web flow in routes/main.py + ops.py + member.py, but JSON.
"""
import os
from datetime import datetime
from flask import request, current_app
from flask_jwt_extended import jwt_required
from app.extensions import db
from app.models import Match, Booking
from . import api_bp
from .helpers import ok, err, current_api_user, member_required
from .serializers import session_summary, session_detail, booking_public

ALLOWED_PROOF_EXT = {'jpg', 'jpeg', 'png', 'webp'}


@api_bp.route('/sessions', methods=['GET'])
@jwt_required()
def list_sessions():
    user = current_api_user()
    status_filter = request.args.get('status', 'all')
    q = Match.query.order_by(Match.date_time.desc())
    if status_filter == 'upcoming':
        q = q.filter(Match.date_time > datetime.utcnow(),
                     Match.status.in_(['open', 'full']))
    elif status_filter == 'completed':
        q = q.filter_by(status='completed')
    elif status_filter == 'open':
        q = q.filter_by(status='open')
    matches = q.all()

    my = {b.match_id: b.status for b in
          Booking.query.filter_by(user_id=user.id).all()} if user else {}
    return ok([session_summary(m, my_status=my.get(m.id)) for m in matches])


@api_bp.route('/sessions/<int:match_id>', methods=['GET'])
@jwt_required()
def get_session(match_id):
    user = current_api_user()
    match = Match.query.get(match_id)
    if match is None:
        return err('NOT_FOUND', 'Sesi tidak ditemukan', 404)
    my_booking = Booking.query.filter_by(user_id=user.id, match_id=match_id).first()
    return ok(session_detail(match, my_booking))


@api_bp.route('/sessions', methods=['POST'])
@jwt_required()
def create_session():
    user = current_api_user()
    if user is None or user.role != 'admin':
        return err('FORBIDDEN', 'Hanya admin yang bisa membuat sesi', 403)

    data = request.get_json(silent=True) or {}
    title = (data.get('title') or '').strip()
    date_time = data.get('date_time')  # ISO 8601 string
    if not title or not date_time:
        return err('VALIDATION', 'title dan date_time (ISO) wajib diisi', 422)
    try:
        dt = datetime.fromisoformat(date_time)
    except (ValueError, TypeError):
        return err('VALIDATION', 'date_time harus format ISO 8601', 422)

    match = Match(
        title=title,
        date_time=dt,
        location=(data.get('location') or 'Daddies Court').strip(),
        price=int(data.get('price') or 0),
        max_players=int(data.get('max_players') or 4),
        notes=(data.get('notes') or ''),
        status='open',
        created_by=user.id,
    )
    db.session.add(match)
    db.session.commit()
    return ok(session_detail(match, None), 201)


@api_bp.route('/sessions/<int:match_id>/join', methods=['POST'])
@member_required
def join_session(match_id):
    user = current_api_user()
    match = Match.query.get(match_id)
    if match is None:
        return err('NOT_FOUND', 'Sesi tidak ditemukan', 404)

    existing = Booking.query.filter_by(user_id=user.id, match_id=match_id).first()
    if existing:
        return err('ALREADY_JOINED', 'Kamu sudah join sesi ini', 409)

    # Capacity → waitlist or confirmed (mirrors web logic).
    status = 'waitlist' if match.confirmed_count >= match.max_players else 'confirmed'
    booking = Booking(user_id=user.id, match_id=match_id, status=status)
    db.session.add(booking)
    db.session.commit()
    return ok({'booking': booking_public(booking),
               'waitlisted': status == 'waitlist'}, 201)


@api_bp.route('/sessions/<int:match_id>/payment', methods=['GET'])
@jwt_required()
def session_payment(match_id):
    user = current_api_user()
    booking = Booking.query.filter_by(user_id=user.id, match_id=match_id).first()
    if booking is None:
        return err('NOT_FOUND', 'Booking tidak ditemukan, join dulu', 404)
    code = f'DPC-{match_id:03d}-{user.id:03d}'
    bank_info = f'BCA 8720567890 a/n Daddies Padel - Kode: {code}'
    qr_url = f'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data={bank_info}'
    return ok({
        'payment_code': code,
        'bank_info': bank_info,
        'qr_url': qr_url,
        'amount': booking.match.price if booking.match else 0,
        'booking_status': booking.status,
    })


@api_bp.route('/sessions/<int:match_id>/payment/proof', methods=['POST'])
@jwt_required()
def upload_payment_proof(match_id):
    user = current_api_user()
    booking = Booking.query.filter_by(user_id=user.id, match_id=match_id).first()
    if booking is None:
        return err('NOT_FOUND', 'Booking tidak ditemukan', 404)

    file = request.files.get('payment_proof')
    if file is None or file.filename == '':
        return err('VALIDATION', 'File payment_proof wajib diunggah', 422)
    ext = file.filename.rsplit('.', 1)[-1].lower() if '.' in file.filename else ''
    if ext not in ALLOWED_PROOF_EXT:
        return err('VALIDATION', 'Format harus jpg/png/webp', 422)

    upload_dir = os.path.join(current_app.root_path, 'static', 'uploads')
    os.makedirs(upload_dir, exist_ok=True)
    filename = f'payment_{booking.id}_{int(datetime.utcnow().timestamp())}.{ext}'
    file.save(os.path.join(upload_dir, filename))

    booking.payment_proof = f'uploads/{filename}'
    booking.status = 'paid'
    db.session.commit()
    return ok({'booking': booking_public(booking),
               'message': 'Bukti bayar terkirim, menunggu verifikasi'})


@api_bp.route('/sessions/history', methods=['GET'])
@jwt_required()
def session_history():
    user = current_api_user()
    bookings = (Booking.query.filter_by(user_id=user.id)
                .join(Match).order_by(Match.date_time.desc()).all())
    return ok([{
        'booking': booking_public(b),
        'session': session_summary(b.match, my_status=b.status),
    } for b in bookings])
