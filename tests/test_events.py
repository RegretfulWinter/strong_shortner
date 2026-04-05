"""Tests for Event routes - to improve coverage"""
import pytest


class TestEventCreation:
    """Test creating events"""
    
    def test_create_event_with_url_and_user(self, client, app):
        """Test creating event linked to URL and User"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        
        # Create user
        user_resp = client.post('/users', json={
            'username': f'eventuser_{unique_id}',
            'email': f'event_{unique_id}@example.com'
        })
        user_id = user_resp.json['data']['id']
        
        # Create URL
        url_resp = client.post('/urls', json={
            'original_url': f'https://example.com/event-{unique_id}',
            'user_id': user_id
        })
        url_id = url_resp.json['id']
        
        # Create event
        event_resp = client.post('/events', json={
            'event_type': 'click',
            'url_id': url_id,
            'user_id': user_id,
            'details': {'source': 'test'}
        })
        assert event_resp.status_code == 201
        assert event_resp.json['event_type'] == 'click'
    
    def test_create_event_minimal(self, client):
        """Test creating event with minimal data"""
        resp = client.post('/events', json={
            'event_type': 'page_view'
        })
        assert resp.status_code == 201
        assert resp.json['event_type'] == 'page_view'


class TestEventFiltering:
    """Test filtering events"""
    
    def test_filter_events_by_type(self, client):
        """Test filtering events by event_type"""
        resp = client.get('/events?event_type=click')
        assert resp.status_code == 200
        assert isinstance(resp.json, list)
    
    def test_filter_events_by_user(self, client):
        """Test filtering events by user_id"""
        resp = client.get('/events?user_id=1')
        assert resp.status_code == 200
    
    def test_filter_events_by_url(self, client):
        """Test filtering events by url_id"""
        resp = client.get('/events?url_id=1')
        assert resp.status_code == 200
    
    def test_filter_events_pagination(self, client):
        """Test event pagination"""
        resp = client.get('/events?page=1&per_page=5')
        assert resp.status_code == 200
        assert 'items' in resp.json


class TestEventErrorHandling:
    """Test event error handling"""
    
    def test_create_event_invalid_url(self, client):
        """Test creating event with non-existent URL"""
        resp = client.post('/events', json={
            'event_type': 'click',
            'url_id': 999999
        })
        assert resp.status_code == 404
    
    def test_create_event_invalid_user(self, client):
        """Test creating event with non-existent user"""
        resp = client.post('/events', json={
            'event_type': 'click',
            'user_id': 999999
        })
        assert resp.status_code == 404
    
    def test_create_event_missing_type(self, client):
        """Test creating event without event_type"""
        resp = client.post('/events', json={
            'details': 'some details'
        })
        assert resp.status_code == 400


class TestBulkUserCreation:
    """Test bulk user creation endpoints"""
    
    def test_bulk_create_json(self, client):
        """Test bulk create via JSON"""
        resp = client.post('/users/bulk', json={
            'row_count': 10
        })
        assert resp.status_code == 201
        assert 'imported' in resp.json or 'status' in resp.json
    
    def test_bulk_create_empty(self, client):
        """Test bulk create with 0 rows"""
        resp = client.post('/users/bulk', json={
            'row_count': 0
        })
        assert resp.status_code in [200, 201]


class TestURLFiltering:
    """Test URL filtering - improve coverage"""
    
    def test_filter_urls_by_user(self, client):
        """Test GET /urls?user_id=1"""
        resp = client.get('/urls?user_id=1')
        assert resp.status_code == 200
    
    def test_filter_urls_by_active(self, client):
        """Test GET /urls?is_active=true"""
        resp = client.get('/urls?is_active=true')
        assert resp.status_code == 200
    
    def test_filter_urls_by_inactive(self, client):
        """Test GET /urls?is_active=false"""
        resp = client.get('/urls?is_active=false')
        assert resp.status_code == 200
    
    def test_filter_urls_pagination(self, client):
        """Test GET /urls?page=1&per_page=5"""
        resp = client.get('/urls?page=1&per_page=5')
        assert resp.status_code == 200
        assert 'items' in resp.json


class TestAdvancedUserOperations:
    """Test advanced user operations"""
    
    def test_update_user_duplicate_email(self, client):
        """Test updating user with existing email"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        
        # Create two users
        client.post('/users', json={
            'username': f'user1_{unique_id}',
            'email': f'email1_{unique_id}@example.com'
        })
        
        resp2 = client.post('/users', json={
            'username': f'user2_{unique_id}',
            'email': f'email2_{unique_id}@example.com'
        })
        user2_id = resp2.json['data']['id']
        
        # Try to update user2 with user1's email
        resp = client.put(f'/users/{user2_id}', json={
            'email': f'email1_{unique_id}@example.com'
        })
        assert resp.status_code == 409
    
    def test_update_user_invalid_email(self, client):
        """Test updating user with invalid email"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        
        resp = client.post('/users', json={
            'username': f'update_test_{unique_id}',
            'email': f'valid_{unique_id}@example.com'
        })
        user_id = resp.json['data']['id']
        
        update_resp = client.put(f'/users/{user_id}', json={
            'email': 'not-an-email'
        })
        assert update_resp.status_code == 400
    
    def test_update_user_invalid_username(self, client):
        """Test updating user with invalid username"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        
        resp = client.post('/users', json={
            'username': f'valid_{unique_id}',
            'email': f'valid_{unique_id}@example.com'
        })
        user_id = resp.json['data']['id']
        
        update_resp = client.put(f'/users/{user_id}', json={
            'username': 'ab'  # Too short
        })
        assert update_resp.status_code == 400
