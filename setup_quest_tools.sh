#!/bin/bash

# ============================================
# Meta PE Hackathon - Quest Tools Setup Script
# Installs all tools needed for Reliability, Scalability & Incident Response quests
# ============================================

# Check if user wants to use mirror (for users in China)
USE_MIRROR=${USE_MIRROR:-false}

# Disable Homebrew auto-update to speed up installation
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Use Tsinghua mirror if enabled (for users with slow connection to default servers)
if [[ "$USE_MIRROR" == "true" ]]; then
    echo "🪞 Using Homebrew mirror (Tsinghua University)..."
    export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
    export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
    export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
    export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
fi

set -e  # Exit on any error

echo "🚀 Starting Quest Tools Installation..."
echo "========================================"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo "📱 Detected: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo "🐧 Detected: Linux"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

# ============================================
# 1. Install Homebrew (macOS) or update package list (Linux)
# ============================================
echo ""
echo "📦 Step 1: Setting up package manager..."

if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew already installed ✓"
        # Skip brew update due to HOMEBREW_NO_AUTO_UPDATE=1
    fi
elif [[ "$OS" == "linux" ]]; then
    echo "Updating package list..."
    sudo apt-get update
fi

# ============================================
# 2. Install Python Dependencies (using uv)
# ============================================
echo ""
echo "🐍 Step 2: Installing Python packages..."

if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Check if we're in the project directory
if [ ! -f "pyproject.toml" ]; then
    echo "⚠️  Warning: pyproject.toml not found. Make sure you're in the project root."
fi

echo "Installing Python packages with uv..."

# Core testing packages for Reliability Quest
uv add --dev pytest pytest-cov pytest-flask

# Caching for Scalability Quest
uv add redis

# Load testing
uv add --dev locust

# Prometheus client for metrics
uv add prometheus-client

# Additional utilities
uv add --dev factory-boy  # For generating test data

echo "Python packages installed ✓"

# ============================================
# 3. Install System Tools
# ============================================
echo ""
echo "🔧 Step 3: Installing system tools..."

if [[ "$OS" == "macos" ]]; then
    # k6 for load testing
    if ! command -v k6 &> /dev/null; then
        echo "Installing k6..."
        brew install k6
    else
        echo "k6 already installed ✓"
    fi
    
    # Redis
    if ! command -v redis-server &> /dev/null; then
        echo "Installing Redis..."
        brew install redis
        echo "Starting Redis service..."
        brew services start redis
    else
        echo "Redis already installed ✓"
    fi
    
    # Nginx
    if ! command -v nginx &> /dev/null; then
        echo "Installing Nginx..."
        brew install nginx
    else
        echo "Nginx already installed ✓"
    fi
    
    # Docker & Docker Compose
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
    else
        echo "Docker already installed ✓"
    fi
    
    # Prometheus
    if ! command -v prometheus &> /dev/null; then
        echo "Installing Prometheus..."
        brew install prometheus
    else
        echo "Prometheus already installed ✓"
    fi
    
    # Grafana
    if ! command -v grafana-server &> /dev/null; then
        echo "Installing Grafana..."
        brew install grafana
    else
        echo "Grafana already installed ✓"
    fi
    
    # Alertmanager - will be run via Docker (no Homebrew formula available)
    echo "Note: Alertmanager will be started via Docker (make monitor-up)"

elif [[ "$OS" == "linux" ]]; then
    # k6
    if ! command -v k6 &> /dev/null; then
        echo "Installing k6..."
        sudo gpg -k
        sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
        echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
        sudo apt-get update
        sudo apt-get install -y k6
    else
        echo "k6 already installed ✓"
    fi
    
    # Redis
    if ! command -v redis-server &> /dev/null; then
        echo "Installing Redis..."
        sudo apt-get install -y redis-server
        sudo systemctl enable redis-server
        sudo systemctl start redis-server
    else
        echo "Redis already installed ✓"
    fi
    
    # Nginx
    if ! command -v nginx &> /dev/null; then
        echo "Installing Nginx..."
        sudo apt-get install -y nginx
    else
        echo "Nginx already installed ✓"
    fi
    
    # Docker
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker $USER
        echo "⚠️  Please log out and log back in for Docker group changes to take effect"
    else
        echo "Docker already installed ✓"
    fi
    
    # Prometheus, Grafana, Alertmanager (using Docker is easier on Linux)
    echo ""
    echo "Note: Prometheus, Grafana, and Alertmanager will be set up via Docker Compose"
fi

# ============================================
# 4. Verify Installations
# ============================================
echo ""
echo "✅ Step 4: Verifying installations..."
echo "========================================"

echo ""
echo "Python Packages:"
echo "----------------"
uv run pytest --version 2>/dev/null && echo "✓ pytest" || echo "✗ pytest"
uv run python -c "import pytest_cov; print('✓ pytest-cov')" 2>/dev/null || echo "✗ pytest-cov"
uv run python -c "import redis; print('✓ redis')" 2>/dev/null || echo "✗ redis"
uv run python -c "import locust; print(f'✓ locust {locust.__version__}')" 2>/dev/null || echo "✗ locust"

echo ""
echo "System Tools:"
echo "-------------"
command -v k6 &> /dev/null && echo "✓ k6" || echo "✗ k6"
command -v redis-server &> /dev/null && echo "✓ redis-server" || echo "✗ redis-server"
command -v nginx &> /dev/null && echo "✓ nginx" || echo "✗ nginx"
command -v docker &> /dev/null && echo "✓ docker" || echo "✗ docker"
command -v docker-compose &> /dev/null && echo "✓ docker-compose" || echo "✗ docker-compose"

if [[ "$OS" == "macos" ]]; then
    command -v prometheus &> /dev/null && echo "✓ prometheus" || echo "✗ prometheus"
    command -v grafana-server &> /dev/null && echo "✓ grafana" || echo "✗ grafana"
    echo "✓ alertmanager (via Docker)"
fi

# ============================================
# 5. Create Sample Configs
# ============================================
echo ""
echo "📝 Step 5: Creating sample configuration files..."

# Create docker-compose.yml for monitoring stack
mkdir -p monitoring

cat > monitoring/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml

volumes:
  grafana-storage:
EOF

# Create prometheus.yml
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'url-shortener'
    static_configs:
      - targets: ['host.docker.internal:5000']
    metrics_path: '/metrics'
EOF

# Create alertmanager.yml
cat > monitoring/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alert@example.com'

route:
  receiver: 'default'

receivers:
  - name: 'default'
    # Configure Discord webhook here for Incident Response quest
    # webhook_configs:
    #   - url: 'YOUR_DISCORD_WEBHOOK_URL'
EOF

echo "✓ Created monitoring/ directory with Docker Compose configs"

# ============================================
# 6. Create Test Examples
# ============================================
echo ""
echo "🧪 Step 6: Creating test examples..."

mkdir -p tests

cat > tests/test_health.py << 'EOF'
"""Reliability Quest - Basic Health Check Test"""
import pytest

def test_health_endpoint(client):
    """Test that /health returns 200 OK"""
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'ok'
EOF

cat > tests/test_users.py << 'EOF'
"""Reliability Quest - User API Tests"""
import pytest

def test_create_user(client):
    """Test user creation"""
    response = client.post('/users', json={
        'username': 'testuser',
        'email': 'test@example.com'
    })
    assert response.status_code == 201
    assert response.json['username'] == 'testuser'

def test_invalid_user_data(client):
    """Test that invalid data returns 400"""
    response = client.post('/users', json={
        'username': 123,  # Invalid: should be string
        'email': 'test@example.com'
    })
    assert response.status_code in [400, 422]
EOF

cat > tests/conftest.py << 'EOF'
"""Pytest configuration and fixtures"""
import pytest
from app import create_app

@pytest.fixture
def app():
    """Create application for testing"""
    app = create_app()
    app.config['TESTING'] = True
    return app

@pytest.fixture
def client(app):
    """Create test client"""
    return app.test_client()
EOF

echo "✓ Created tests/ directory with example tests"

# Create k6 load test script
cat > tests/load_test.js << 'EOF'
/*
 * Scalability Quest - Load Test Script
 * Run with: k6 run tests/load_test.js
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

// Bronze: 50 concurrent users
// Silver: 200 concurrent users
// Gold: 500+ concurrent users
export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Bronze tier
    { duration: '1m', target: 50 },    // Stay at 50
    { duration: '30s', target: 200 },  // Ramp to Silver
    { duration: '1m', target: 200 },   // Stay at 200
    { duration: '30s', target: 500 },  // Ramp to Gold
    { duration: '1m', target: 500 },   // Stay at 500
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'], // 95% of requests under 3s (Silver requirement)
    http_req_failed: ['rate<0.05'],     // Less than 5% errors (Gold requirement)
  },
};

const BASE_URL = 'http://localhost:5000';

export default function () {
  // Test health endpoint
  let res = http.get(`${BASE_URL}/health`);
  check(res, {
    'health status is 200': (r) => r.status === 200,
    'health response is ok': (r) => r.json('status') === 'ok',
  });

  // Test list users
  res = http.get(`${BASE_URL}/users`);
  check(res, {
    'users status is 200': (r) => r.status === 200,
  });

  // Test list URLs
  res = http.get(`${BASE_URL}/urls`);
  check(res, {
    'urls status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
EOF

echo "✓ Created k6 load test script (tests/load_test.js)"

# ============================================
# 7. Create Makefile for convenience
# ============================================
echo ""
echo "🛠️  Step 7: Creating Makefile..."

cat > Makefile << 'EOF'
.PHONY: help install test test-cov load-test monitor-start monitor-stop

help:
	@echo "Available commands:"
	@echo "  make test         - Run pytest"
	@echo "  make test-cov     - Run pytest with coverage"
	@echo "  make load-test    - Run k6 load tests"
	@echo "  make monitor-up   - Start monitoring stack (Prometheus + Grafana)"
	@echo "  make monitor-down - Stop monitoring stack"
	@echo "  make run          - Start Flask dev server"
	@echo "  make run-prod     - Start with gunicorn (multiple workers)"

test:
	uv run pytest tests/ -v

test-cov:
	uv run pytest tests/ --cov=app --cov-report=html --cov-report=term

load-test:
	k6 run tests/load_test.js

monitor-up:
	cd monitoring && docker-compose up -d
	@echo "Grafana: http://localhost:3000 (admin/admin)"
	@echo "Prometheus: http://localhost:9090"
	@echo "Alertmanager: http://localhost:9093"

monitor-down:
	cd monitoring && docker-compose down

run:
	uv run run.py

run-prod:
	uv run gunicorn -w 4 -b 0.0.0.0:5000 run:app
EOF

echo "✓ Created Makefile"

# ============================================
# 8. Summary
# ============================================
echo ""
echo "🎉 Installation Complete!"
echo "========================="
echo ""
echo "Next Steps:"
echo "-----------"
echo "1. Run tests:           make test"
echo "2. Run with coverage:   make test-cov"
echo "3. Run load test:       make load-test"
echo "4. Start monitoring:    make monitor-up"
echo "5. Start dev server:    make run"
echo ""
echo "Quest Progress Checklist:"
echo "------------------------"
echo "□ Reliability (Bronze): Write tests → make test"
echo "□ Reliability (Silver): 50% coverage → make test-cov"
echo "□ Reliability (Gold):   70% coverage + error handling"
echo "□ Scalability (Bronze): 50 users → k6 run tests/load_test.js"
echo "□ Scalability (Silver): 200 users + Docker + Nginx"
echo "□ Scalability (Gold):   500 users + Redis caching"
echo "□ Incident (Bronze):    JSON logs + /metrics endpoint"
echo "□ Incident (Silver):    Alerts → Discord"
echo "□ Incident (Gold):      Grafana dashboard + Runbook"
echo ""
echo "Good luck on your quests! 🚀"
