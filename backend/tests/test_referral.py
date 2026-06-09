"""Tests for Phase 2: Referral code system."""
import pytest
from app import create_app
from app.config import TestingConfig
from app.extensions import db as _db
from app.models import User
from app.utils.referral import (
    generate_code, validate_code, use_code, membership_price_for,
    referral_stats, ensure_code, MAX_USES_PER_MONTH,
    MEMBERSHIP_PRICE_WITH_CODE, MEMBERSHIP_PRICE_WITHOUT_CODE
)


@pytest.fixture
def app():
    # TestingConfig binds in-memory DB at init_app time — dev DB untouched.
    app = create_app(TestingConfig)
    with app.app_context():
        _db.create_all()
        yield app
        _db.session.remove()
        _db.drop_all()


@pytest.fixture
def member(app):
    with app.app_context():
        u = User(username='Yanto', email='yanto@t.com', phone='001',
                 membership='member', membership_paid=True, role='member')
        u.set_password('pw')
        _db.session.add(u)
        _db.session.commit()
        return u.id


class TestCodeGeneration:
    def test_generate_code_is_6_chars(self, app, member):
        with app.app_context():
            u = User.query.get(member)
            code = ensure_code(u)
            assert len(code) == 6
            assert code.isupper() or code.isdigit() or code.isalnum()

    def test_ensure_code_idempotent(self, app, member):
        """Calling ensure_code twice returns same code."""
        with app.app_context():
            u = User.query.get(member)
            c1 = ensure_code(u)
            c2 = ensure_code(u)
            assert c1 == c2

    def test_codes_are_unique(self, app):
        """Two users get different codes."""
        with app.app_context():
            u1 = User(username='A', email='a@t.com', phone='11',
                      membership='member', membership_paid=True, role='member')
            u2 = User(username='B', email='b@t.com', phone='22',
                      membership='member', membership_paid=True, role='member')
            _db.session.add_all([u1, u2])
            _db.session.flush()
            c1 = ensure_code(u1)
            c2 = ensure_code(u2)
            _db.session.commit()
            assert c1 != c2


class TestValidateCode:
    def test_valid_code_returns_owner(self, app, member):
        with app.app_context():
            u = User.query.get(member)
            code = ensure_code(u)
            _db.session.commit()
            owner = validate_code(code)
            assert owner is not None
            assert owner.id == member

    def test_invalid_code_returns_none(self, app):
        with app.app_context():
            assert validate_code('XXXXXX') is None
            assert validate_code('') is None
            assert validate_code(None) is None

    def test_non_member_code_invalid(self, app):
        """Guest user's code should not work."""
        with app.app_context():
            guest = User(username='G', email='g@t.com', phone='33',
                         membership='guest', membership_paid=False, role='member')
            guest.set_password('pw')
            guest.referral_code = 'GUEST1'
            _db.session.add(guest)
            _db.session.commit()
            assert validate_code('GUEST1') is None

    def test_exhausted_code_returns_none(self, app, member):
        """Code with 3 uses already this month is invalid."""
        from datetime import date
        with app.app_context():
            u = User.query.get(member)
            code = ensure_code(u)
            # Set reset_date to current month so _reset_if_new_month doesn't clear it
            u.referral_uses_this_month = MAX_USES_PER_MONTH
            u.referral_reset_date = date.today()
            _db.session.commit()
            assert validate_code(code) is None


class TestUseCode:
    def test_use_code_sets_referred_by(self, app, member):
        with app.app_context():
            owner = User.query.get(member)
            code = ensure_code(owner)
            _db.session.commit()

            new_user = User(username='New', email='new@t.com', phone='44',
                            membership='guest', membership_paid=False, role='member')
            _db.session.add(new_user)
            _db.session.flush()

            ok, msg = use_code(code, new_user)
            _db.session.commit()

            assert ok is True
            assert new_user.referred_by == member
            assert new_user.membership_amount_paid == MEMBERSHIP_PRICE_WITH_CODE

    def test_use_code_increments_owner_count(self, app, member):
        with app.app_context():
            owner = User.query.get(member)
            code = ensure_code(owner)
            before = owner.referral_uses_this_month
            _db.session.commit()

            new_user = User(username='N2', email='n2@t.com', phone='55',
                            membership='guest', membership_paid=False, role='member')
            _db.session.add(new_user)
            _db.session.flush()
            use_code(code, new_user)
            _db.session.commit()

            owner = User.query.get(member)
            assert owner.referral_uses_this_month == before + 1

    def test_use_invalid_code_fails(self, app, member):
        with app.app_context():
            new_user = User(username='N3', email='n3@t.com', phone='66',
                            membership='guest', membership_paid=False, role='member')
            _db.session.add(new_user)
            _db.session.flush()
            ok, msg = use_code('INVALID', new_user)
            assert ok is False
            assert new_user.referred_by is None


class TestPricing:
    def test_price_with_valid_code(self, app, member):
        with app.app_context():
            owner = User.query.get(member)
            code = ensure_code(owner)
            _db.session.commit()
            price = membership_price_for(code)
            assert price == MEMBERSHIP_PRICE_WITH_CODE

    def test_price_without_code(self, app):
        with app.app_context():
            price = membership_price_for('')
            assert price == MEMBERSHIP_PRICE_WITHOUT_CODE

    def test_price_with_invalid_code(self, app):
        with app.app_context():
            price = membership_price_for('BADXXX')
            assert price == MEMBERSHIP_PRICE_WITHOUT_CODE


class TestReferralStats:
    def test_stats_shows_correct_counts(self, app, member):
        with app.app_context():
            owner = User.query.get(member)
            code = ensure_code(owner)
            _db.session.commit()

            # Create 2 referred users
            for i, (name, paid) in enumerate([('R1', True), ('R2', False)]):
                u = User(username=name, email=f'{name}@t.com', phone=f'7{i}',
                         membership='guest', membership_paid=paid,
                         referred_by=member, role='member')
                _db.session.add(u)
            _db.session.commit()

            stats = referral_stats(owner)
            assert stats['code'] == code
            assert stats['total_referred'] == 2
            assert stats['paid_referred'] == 1
            assert stats['remaining_this_month'] == MAX_USES_PER_MONTH


class TestSignupWithReferral:
    def test_register_with_valid_code(self, app, member):
        with app.app_context():
            owner = User.query.get(member)
            code = ensure_code(owner)
            _db.session.commit()

        client = app.test_client()
        resp = client.post('/auth/register', data={
            'username': 'NewMember',
            'email': 'new@member.com',
            'phone': '0812345',
            'password': 'pw123',
            'referral_code': code
        }, follow_redirects=True)
        assert resp.status_code == 200

        with app.app_context():
            new = User.query.filter_by(email='new@member.com').first()
            assert new is not None
            assert new.referred_by == member
            assert new.membership_amount_paid == MEMBERSHIP_PRICE_WITH_CODE

    def test_validate_referral_endpoint(self, app, member):
        with app.app_context():
            owner = User.query.get(member)
            code = ensure_code(owner)
            _db.session.commit()

        client = app.test_client()
        resp = client.get(f'/auth/validate-referral?code={code}')
        import json
        data = json.loads(resp.data)
        assert data['valid'] is True
        assert data['price'] == MEMBERSHIP_PRICE_WITH_CODE

    def test_validate_invalid_code_endpoint(self, app):
        client = app.test_client()
        import json
        resp = client.get('/auth/validate-referral?code=BADXXX')
        data = json.loads(resp.data)
        assert data['valid'] is False
        assert data['price'] == MEMBERSHIP_PRICE_WITHOUT_CODE
