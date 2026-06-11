"""Unified Share API — one endpoint for all card types.

POST /api/share/generate → returns {image_url, wa_text, wa_link}
GET  /api/share/download/<filename> → download PNG
"""
from flask import Blueprint, request, jsonify, render_template, url_for, send_from_directory
from flask_login import current_user, login_required
from app.services.card_renderer import render_card
from app.models import User, Tournament
from app.extensions import db
from urllib.parse import quote

bp = Blueprint('share', __name__)

BASE_URL = "https://padeldaddies.site"


@bp.route('/api/share/generate', methods=['POST'])
@login_required
def generate():
    """Universal share endpoint. All card types go through here.

    POST body: { "card_type": "streak"|"tournament"|"leaderboard"|"profile"|"milestone" }
    Returns: { image_url, image_path, wa_text, wa_link }
    """
    body = request.json or {}
    card_type = body.get('card_type', '')
    user = current_user

    # Generate HTML based on card type
    html = ""
    wa_text = ""

    if card_type == 'streak':
        streak = user.streak_data
        html = render_template('streak/share_card_raw.html', user=user, streak=streak)
        wa_text = (
            f"Aku udah {streak['current']} minggu berturut-turut main padel! "
            f"Main bareng di Daddies Padel? {BASE_URL}"
        )

    elif card_type == 'tournament':
        tid = body.get('tournament_id')
        tournament = Tournament.query.get(tid) if tid else None
        if tournament:
            from app.services.tournament_scoring.dispatcher import calculate_tournament_standings
            lb = calculate_tournament_standings(tournament)
            html = render_template('tournament/share_card.html', tournament=tournament, leaderboard=lb)
            lines = [f"🎾 DADDIES PADEL — {tournament.name}",
                     f"📍 {tournament.venue} · {tournament.date.strftime('%d %b %Y')}"]
            for i, s in enumerate(lb[:5]):
                medal = ['🥇','🥈','🥉'][i] if i < 3 else f'{i+1}.'
                lines.append(f"{medal} {s['participant'].first_name} — {s['points']} pts")
            lines.append(f"\n🎾 {BASE_URL}/tournament/{tid}/share")
            wa_text = '\n'.join(lines)

    elif card_type == 'leaderboard':
        users = User.query.all()
        ranked = sorted(users, key=lambda u: u.chips_balance, reverse=True)
        my_rank = next((i+1 for i, u in enumerate(ranked) if u.id == user.id), 0)
        html = render_template('leaderboard_card_raw.html',
                               ranked=ranked[:5], my_rank=my_rank, user=user,
                               total_players=len(ranked))
        lines = ['🏆 Daddies Padel — Leaderboard']
        for i, u in enumerate(ranked[:5]):
            medal = ['🥇','🥈','🥉'][i] if i < 3 else f'{i+1}.'
            lines.append(f"{medal} {u.first_name} — {u.chips_balance:,} chips")
        lines.append(f"\n🎾 {BASE_URL}/leaderboard")
        wa_text = '\n'.join(lines)

    elif card_type == 'profile':
        streak = user.streak_data
        all_users = User.query.all()
        ranked = sorted(all_users, key=lambda u: u.chips_balance, reverse=True)
        rank = next((i+1 for i, u in enumerate(ranked) if u.id == user.id), 0)
        wins = user.bookings.filter_by(status='confirmed').count()
        total = user.total_games
        win_rate = int((wins / total * 100) if total > 0 else 0)
        html = render_template('profile/card.html', user=user, rank=rank,
                               total_ranked=len(ranked), streak=streak, win_rate=win_rate)
        wa_text = (
            f"🎾 {user.display_name} — Daddies Padel\n"
            f"💰 {user.chips_balance:,} chips | 🔥 {streak['current']} minggu streak\n\n"
            f"Main bareng di Daddies Padel? {BASE_URL}"
        )

    elif card_type == 'milestone':
        from app.models import CHIPS_MILESTONES
        threshold = body.get('threshold', 10000)
        milestone = next((m for m in CHIPS_MILESTONES if m['threshold'] == threshold), None)
        if milestone:
            html = render_template('chips_milestone.html', user=user, milestone=milestone)
            wa_text = f"{milestone['emoji']} {milestone['share']}\n\n🎾 {BASE_URL}"

    if not html:
        return jsonify({"error": f"Unknown card type: {card_type}"}), 400

    # Render HTML → PNG
    image_path = render_card(card_type, html)
    if not image_path:
        return jsonify({"error": "PNG render failed"}), 500

    image_url = url_for('static', filename=image_path, _external=True)

    return jsonify({
        "image_url": image_url,
        "image_path": f"/static/{image_path}",
        "wa_text": wa_text,
        "wa_link": f"https://wa.me/?text={quote(wa_text)}",
    })


@bp.route('/api/share/download/<filename>')
def download(filename):
    """Direct download of share image."""
    return send_from_directory('static/shares', filename, as_attachment=True)
