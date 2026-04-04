# ============================================
# URL Shortener - Makefile
# Meta PE Hackathon Quest Commands
# ============================================

.PHONY: help install test test-cov load-test load-test-bronze load-test-silver load-test-gold
.PHONY: docker-build docker-up docker-down docker-scale docker-logs
.PHONY: monitor-up monitor-down
.PHONY: init-db run run-prod

# Default target
help:
	@echo "🚀 URL Shortener - Available Commands"
	@echo "======================================"
	@echo ""
	@echo "Development:"
	@echo "  make install      - Install Python dependencies"
	@echo "  make init-db      - Initialize database tables"
	@echo "  make run          - Run Flask dev server"
	@echo "  make run-prod     - Run with gunicorn (4 workers)"
	@echo ""
	@echo "Testing (Reliability Quest):"
	@echo "  make test         - Run pytest"
	@echo "  make test-cov     - Run pytest with coverage report"
	@echo ""
	@echo "Load Testing (Scalability Quest):"
	@echo "  make load-test         - Run k6 load test (staged)"
	@echo "  make load-test-bronze  - 50 concurrent users"
	@echo "  make load-test-silver  - 200 concurrent users"
	@echo "  make load-test-gold    - 500 concurrent users"
	@echo ""
	@echo "Docker (Scalability Quest):"
	@echo "  make docker-build    - Build Docker image"
	@echo "  make docker-up       - Start all services (1 app)"
	@echo "  make docker-up-3     - Start with 3 app instances"
	@echo "  make docker-up-5     - Start with 5 app instances"
	@echo "  make docker-down     - Stop all services"
	@echo "  make docker-scale    - Scale app to N instances (N=3)"
	@echo "  make docker-logs     - View logs"
	@echo ""
	@echo "Monitoring (Incident Response Quest):"
	@echo "  make monitor-up      - Start Prometheus + Grafana + Alertmanager"
	@echo "  make monitor-down    - Stop monitoring stack"
	@echo "  make monitor-url     - Open Grafana in browser"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make all-up          - Start everything (app + monitoring)"
	@echo "  make all-down        - Stop everything"

# ============================================
# Development
# ============================================

install:
	uv sync

init-db:
	uv run python -c "from app import create_app; from app.database import db; from app.models import User, URL, Event; app = create_app(); db.create_tables([User, URL, Event]); print('Tables created!')"

run:
	uv run run.py

run-prod:
	uv run gunicorn -w 4 -b 0.0.0.0:5000 run:app

# ============================================
# Testing - Reliability Quest
# ============================================

test:
	uv run pytest tests/ -v

test-cov:
	uv run pytest tests/ --cov=app --cov-report=html --cov-report=term
	@echo "Coverage report: htmlcov/index.html"

# ============================================
# Load Testing - Scalability Quest
# ============================================

load-test:
	k6 run tests/load_test.js

load-test-bronze:
	k6 run --vus 50 --duration 60s tests/load_test_simple.js

load-test-silver:
	k6 run --vus 200 --duration 120s tests/load_test_simple.js

load-test-gold:
	k6 run --vus 500 --duration 180s tests/load_test_simple.js

# ============================================
# Docker - Scalability Quest
# ============================================

docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker-up-3:
	docker-compose up -d --scale app=3
	@echo "✓ Started 3 app instances behind Nginx load balancer"

docker-up-5:
	docker-compose up -d --scale app=5
	@echo "✓ Started 5 app instances behind Nginx load balancer"

docker-down:
	docker-compose down

docker-scale:
	@read -p "Number of app instances: " n; \
	docker-compose up -d --scale app=$$n

docker-logs:
	docker-compose logs -f app nginx

docker-ps:
	docker-compose ps

# ============================================
# Monitoring - Incident Response Quest
# ============================================

monitor-up:
	docker-compose up -d prometheus grafana alertmanager
	@echo ""
	@echo "🎯 Monitoring Stack Started:"
	@echo "   Grafana:      http://localhost:3000 (admin/admin)"
	@echo "   Prometheus:   http://localhost:9090"
	@echo "   Alertmanager: http://localhost:9093"
	@echo ""

monitor-down:
	docker-compose stop prometheus grafana alertmanager

monitor-url:
	open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Open http://localhost:3000"

# ============================================
# Combined Commands
# ============================================

all-up: docker-up monitor-up
	@echo ""
	@echo "✅ All services started!"
	@echo "   App:          http://localhost"
	@echo "   Health Check: http://localhost/health"
	@echo "   Grafana:      http://localhost:3000"
	@echo ""

all-down: docker-down monitor-down
	@echo "All services stopped"

# ============================================
# Database Migrations - Schema Management
# ============================================

migrate-create:
	@read -p "Migration name: " name; \
	uv run python migrations.py create "$$name"

migrate-up:
	uv run python migrations.py upgrade

migrate-status:
	uv run python migrations.py status

migrate-reset:
	uv run python migrations.py reset

# Quick add column without migration file
migrate-add-column:
	@read -p "Table name: " table; \
	read -p "Column name: " col; \
	read -p "Type (char/text/int/bool/datetime): " type; \
	uv run python migrations.py add_column $$table $$col $$type

# Development: Quick reset and reinit (for rapid prototyping)
db-reset-dev:
	@echo "⚠️  Dropping and recreating all tables..."
	uv run python migrations.py reset
	@echo "✅ Database is now clean. Run 'make init-db' to recreate tables."

# Import seed data from CSV files
import-csv:
	uv run python import_csv.py all

import-csv-custom:
	@read -p "Path to users.csv: " users; \
	read -p "Path to urls.csv: " urls; \
	read -p "Path to events.csv: " events; \
	uv run python import_csv.py $$users $$urls $$events
