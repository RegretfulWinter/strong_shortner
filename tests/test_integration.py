"""
Integration Tests for Reliability Quest - Silver Tier
Test API endpoints with real database operations
"""


class TestUserIntegration:
    """Integration tests for User API"""
    
    def test_create_and_get_user(self, client):
        """Test creating a user and retrieving it"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        # Create user
        response = client.post('/users', json={
            'username': f'testuser_integration_{unique_id}',
            'email': f'test_integration_{unique_id}@example.com'
        })
        assert response.status_code == 201
        user_id = response.json['id']
        
        # Get user
        response = client.get(f'/users/{user_id}')
        assert response.status_code == 200
        assert response.json['username'] == f'testuser_integration_{unique_id}'
    
    def test_create_user_duplicate_username(self, client):
        """Test creating user with duplicate username fails"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        username = f'duplicate_test_{unique_id}'
        
        # Create first user
        response = client.post('/users', json={
            'username': username,
            'email': f'first_{unique_id}@example.com'
        })
        assert response.status_code == 201
        
        # Try to create duplicate
        response = client.post('/users', json={
            'username': username,
            'email': f'second_{unique_id}@example.com'
        })
        assert response.status_code == 409
    
    def test_update_user(self, client):
        """Test updating a user"""
        import time
        # Create user with unique username
        unique_id = str(int(time.time() * 1000))[-6:]
        response = client.post('/users', json={
            'username': f'update_test_{unique_id}',
            'email': f'update_{unique_id}@example.com'
        })
        assert response.status_code == 201
        user_id = response.json['id']
        
        # Update user
        response = client.put(f'/users/{user_id}', json={
            'username': f'updated_name_{unique_id}'
        })
        assert response.status_code == 200
        assert response.json['username'] == f'updated_name_{unique_id}'
    
    def test_delete_user(self, client):
        """Test deleting a user"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        
        # Create user
        response = client.post('/users', json={
            'username': f'delete_test_{unique_id}',
            'email': f'delete_{unique_id}@example.com'
        })
        assert response.status_code == 201
        user_id = response.json['id']
        
        # Delete user
        response = client.delete(f'/users/{user_id}')
        assert response.status_code == 200
        
        # Verify deleted
        response = client.get(f'/users/{user_id}')
        assert response.status_code == 404


class TestURLIntegration:
    """Integration tests for URL API"""
    
    def test_create_short_url(self, client):
        """Test creating a short URL"""
        response = client.post('/urls', json={
            'original_url': 'https://example.com/integration-test',
            'title': 'Integration Test URL'
        })
        assert response.status_code == 201
        assert 'short_code' in response.json
        assert response.json['original_url'] == 'https://example.com/integration-test'
    
    def test_create_url_with_user(self, client):
        """Test creating URL associated with a user"""
        import time
        unique_id = str(int(time.time() * 1000))[-6:]
        
        # Create user first
        user_response = client.post('/users', json={
            'username': f'url_owner_{unique_id}',
            'email': f'owner_{unique_id}@example.com'
        })
        assert user_response.status_code == 201
        user_id = user_response.json['id']
        
        # Create URL with user
        response = client.post('/urls', json={
            'original_url': f'https://example.com/user-url-{unique_id}',
            'user_id': user_id,
            'title': 'User URL'
        })
        assert response.status_code == 201
        assert response.json['user_id'] == user_id
    
    def test_deactivate_url(self, client):
        """Test deactivating a URL"""
        # Create URL
        response = client.post('/urls', json={
            'original_url': 'https://example.com/deactivate-test',
            'title': 'To be deactivated'
        })
        url_id = response.json['id']
        
        # Deactivate
        response = client.put(f'/urls/{url_id}', json={
            'is_active': False
        })
        assert response.status_code == 200
        assert not response.json['is_active']


class TestErrorHandling:
    """Test error handling - Gold Tier"""
    
    def test_404_not_found(self, client):
        """Test 404 response for non-existent resource"""
        response = client.get('/users/999999')
        assert response.status_code == 404
        assert 'error' in response.json
    
    def test_invalid_json(self, client):
        """Test handling invalid JSON"""
        response = client.post('/users', 
                               data='not valid json',
                               content_type='application/json')
        assert response.status_code in [400, 415, 500]
    
    def test_missing_required_fields(self, client):
        """Test validation of required fields"""
        response = client.post('/users', json={
            'email': 'missing_username@example.com'
            # missing username
        })
        assert response.status_code == 400
    
    def test_invalid_email_format(self, client):
        """Test email validation"""
        response = client.post('/users', json={
            'username': 'bad_email_test',
            'email': 'not-an-email'
        })
        assert response.status_code == 400
    
    def test_invalid_username_format(self, client):
        """Test username validation"""
        response = client.post('/users', json={
            'username': 'ab',  # too short
            'email': 'valid@example.com'
        })
        assert response.status_code == 400


class TestHealthEndpoint:
    """Health check tests"""
    
    def test_health_status_code(self, client):
        """Test health endpoint returns 200"""
        response = client.get('/health')
        assert response.status_code == 200
    
    def test_health_response_format(self, client):
        """Test health endpoint returns correct format"""
        response = client.get('/health')
        assert response.json == {'status': 'ok'}
