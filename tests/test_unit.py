"""
Unit Tests for Reliability Quest - Silver/Gold Tier
Test individual functions in isolation
"""
import pytest
import time
from app.models.user import User
from app.models.url import URL
from app.models.event import Event


@pytest.fixture(autouse=True)
def clean_database(app):
    """Clean database before each test"""
    with app.app_context():
        # Delete all test data
        Event.delete().execute()
        URL.delete().execute()
        User.delete().execute()


class TestUserModel:
    """Unit tests for User model"""
    
    def test_user_creation(self, app):
        """Test creating a user"""
        with app.app_context():
            user = User.create(
                username='unittest_user',
                email='unittest@example.com'
            )
            assert user.id is not None
            assert user.username == 'unittest_user'
            assert user.email == 'unittest@example.com'
    
    def test_user_get_by_id(self, app):
        """Test retrieving user by ID"""
        with app.app_context():
            user = User.create(
                username='getbyid_test',
                email='getbyid@example.com'
            )
            fetched = User.get_by_id(user.id)
            assert fetched.username == user.username
    
    def test_user_update(self, app):
        """Test updating user fields"""
        with app.app_context():
            unique_id = str(int(time.time() * 1000))[-6:]
            user = User.create(
                username=f'update_test_{unique_id}',
                email='update@example.com'
            )
            new_username = f'updated_username_{unique_id}'
            user.username = new_username
            user.save()
            
            fetched = User.get_by_id(user.id)
            assert fetched.username == new_username
    
    def test_user_delete(self, app):
        """Test deleting a user"""
        with app.app_context():
            user = User.create(
                username='delete_test',
                email='delete@example.com'
            )
            user_id = user.id
            user.delete_instance()
            
            with pytest.raises(User.DoesNotExist):
                User.get_by_id(user_id)


class TestURLModel:
    """Unit tests for URL model"""
    
    def test_url_creation(self, app):
        """Test creating a URL"""
        with app.app_context():
            unique_id = str(int(time.time() * 1000))[-6:]
            url = URL.create(
                short_code=f'unit{unique_id}',
                original_url='https://example.com/unit-test',
                title='Unit Test URL'
            )
            assert url.id is not None
            assert url.short_code == f'unit{unique_id}'
            assert url.is_active
    
    def test_url_deactivation(self, app):
        """Test deactivating a URL"""
        with app.app_context():
            unique_id = str(int(time.time() * 1000))[-6:]
            url = URL.create(
                short_code=f'deact{unique_id}',
                original_url='https://example.com/deactivate',
                is_active=True
            )
            url.is_active = False
            url.save()

            fetched = URL.get_by_id(url.id)
            assert not fetched.is_active


class TestEventModel:
    """Unit tests for Event model"""
    
    def test_event_creation(self, app):
        """Test creating an event"""
        with app.app_context():
            event = Event.create(
                event_type='test_event',
                details='{"test": "data"}'
            )
            assert event.id is not None
            assert event.event_type == 'test_event'


class TestUserRoutesUnit:
    """Unit tests for user routes"""
    
    def test_list_users_empty(self, client):
        """Test listing users when empty"""
        response = client.get('/users')
        assert response.status_code == 200
        assert isinstance(response.json, list)
    
    def test_get_nonexistent_user(self, client):
        """Test getting user that doesn't exist"""
        response = client.get('/users/999999')
        assert response.status_code == 404
        assert 'error' in response.json


class TestURLRoutesUnit:
    """Unit tests for URL routes"""
    
    def test_list_urls_empty(self, client):
        """Test listing URLs when empty"""
        response = client.get('/urls')
        assert response.status_code == 200
        assert isinstance(response.json, list)
    
    def test_get_nonexistent_url(self, client):
        """Test getting URL that doesn't exist"""
        response = client.get('/urls/999999')
        assert response.status_code == 404


class TestEventRoutesUnit:
    """Unit tests for event routes"""
    
    def test_list_events(self, client):
        """Test listing events"""
        response = client.get('/events')
        assert response.status_code == 200
        assert isinstance(response.json, list)


class TestInputValidation:
    """Test input validation - Gold Tier"""
    
    def test_empty_username_rejected(self, client):
        """Test empty username is rejected"""
        response = client.post('/users', json={
            'username': '',
            'email': 'valid@example.com'
        })
        assert response.status_code == 400
    
    def test_empty_email_rejected(self, client):
        """Test empty email is rejected"""
        response = client.post('/users', json={
            'username': 'validuser',
            'email': ''
        })
        assert response.status_code == 400
    
    def test_special_chars_in_username_rejected(self, client):
        """Test username with special chars is rejected"""
        response = client.post('/users', json={
            'username': 'user@#$%',
            'email': 'valid@example.com'
        })
        assert response.status_code == 400
