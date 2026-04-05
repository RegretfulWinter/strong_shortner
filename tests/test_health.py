"""Basic health check tests for Reliability Quest"""


def test_health_endpoint(client):
    """Test that /health returns 200 with healthy status"""
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'
    assert 'checks' in response.json
    assert response.json['checks']['database']['status'] == 'healthy'


def test_users_list_empty(client):
    """Test users list endpoint"""
    response = client.get('/users')
    assert response.status_code == 200
    assert isinstance(response.json, list)


def test_urls_list_empty(client):
    """Test URLs list endpoint"""
    response = client.get('/urls')
    assert response.status_code == 200
    assert isinstance(response.json, list)
