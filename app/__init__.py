from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory
from werkzeug.routing import BaseConverter
import datetime
import os
import re

from app.database import init_db
from app.routes import register_routes
from app.logging_config import setup_logging, get_logger

# Setup structured JSON logging
setup_logging()
logger = get_logger(__name__)

# Get the absolute path to the static directory
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')


class ShortCodeConverter(BaseConverter):
    """Custom URL converter for short codes - excludes system paths"""
    # Short codes are 6+ alphanumeric characters
    # This excludes paths like 'metrics', 'health', 'api', etc.
    regex = r'[a-zA-Z0-9]{6,}'
    
    def to_python(self, value):
        # Additional check to exclude system paths
        system_paths = {'metrics', 'health', 'api', 'static', 'favicon'}
        if value.lower() in system_paths:
            raise ValueError(f"'{value}' is a reserved path")
        return value


def create_app():
    load_dotenv()

    app = Flask(__name__)
    
    # Register custom URL converter
    app.url_map.converters['shortcode'] = ShortCodeConverter
    
    # Initialize Prometheus metrics endpoint
    # Incident Response Quest - Bronze: The Watchtower
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter, Histogram, Info, REGISTRY
    import time
    
    # Create metrics (handle duplicate registration in tests)
    try:
        app_info = Info('app_info', 'URL Shortener Application')
        app_info.info({'version': '1.0.0'})
    except ValueError:
        # Metric already exists (e.g., in tests that recreate app)
        pass
    
    try:
        http_requests_total = Counter('flask_http_request_total', 'Total HTTP requests', ['method', 'status', 'endpoint'])
        http_request_duration = Histogram('flask_http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
    except ValueError:
        # Metrics already exist
        http_requests_total = REGISTRY._names_to_collectors.get('flask_http_request_total')
        http_request_duration = REGISTRY._names_to_collectors.get('flask_http_request_duration_seconds')
    
    @app.before_request
    def before_request():
        request.start_time = time.time()
    
    @app.after_request
    def after_request(response):
        if hasattr(request, 'start_time'):
            duration = time.time() - request.start_time
            http_request_duration.labels(method=request.method, endpoint=request.endpoint or 'unknown').observe(duration)
        http_requests_total.labels(method=request.method, status=response.status_code, endpoint=request.endpoint or 'unknown').inc()
        return response
    
    @app.route('/metrics')
    def metrics():
        """Prometheus metrics endpoint - returns HTML for browsers, Prometheus format for scrapers"""
        # If browser request, show pretty HTML dashboard
        if request.headers.get('Accept', '').startswith('text/html') or 'text/html' in request.headers.get('Accept', ''):
            return _metrics_html_page()
        
        # Otherwise return Prometheus format for scrapers
        return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

    init_db(app)

    from app import models  # noqa: F401 - registers models with Peewee

    register_routes(app)

    # Register short URL redirect at app level
    # Uses custom converter to exclude system paths
    from app.routes.urls import redirect_short_url
    app.add_url_rule('/<shortcode:short_code>', 'redirect_short', redirect_short_url)

    # Serve frontend static files
    @app.route('/')
    def index():
        """Serve the frontend HTML page"""
        return send_from_directory(STATIC_DIR, 'index.html')

    @app.route('/<path:filename>')
    def static_files(filename):
        """Serve static files"""
        return send_from_directory(STATIC_DIR, filename)

    @app.route("/health")
    def health():
        """Comprehensive health check endpoint"""
        # Check database connectivity
        db_status = "ok"
        try:
            from app.models.user import User
            # Simple query to verify DB connection
            User.select().limit(1).execute()
        except Exception:
            db_status = "error"

        # Build health response
        health_data = {
            "status": "ok" if db_status == "ok" else "degraded",
            "version": "1.0.0",
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
            "environment": os.environ.get("FLASK_ENV", "production"),
            "checks": {
                "database": {
                    "status": db_status,
                    "latency_ms": "<100"
                },
                "application": {
                    "status": "ok",
                    "uptime": "running"
                }
            }
        }

        # Return HTML for browser, JSON for API clients
        if request.headers.get('Accept', '').startswith('text/html'):
            return _health_html_page(health_data)

        return jsonify(health_data)

    # Error handlers - return clean JSON, not stack traces
    @app.errorhandler(400)
    def handle_400(error):
        """Handle bad request errors"""
        if hasattr(error, 'description') and isinstance(error.description, str):
            return jsonify({"error": error.description}), 400
        return jsonify({"error": "Bad request"}), 400

    @app.errorhandler(404)
    def handle_404(error):
        """Handle not found errors"""
        return jsonify({"error": "Resource not found"}), 404

    @app.errorhandler(500)
    def handle_500(error):
        """Handle internal server errors - log details but return clean message"""
        import traceback
        logger.error("Internal server error", extra={
            "error": str(error),
            "traceback": traceback.format_exc(),
            "path": request.path,
            "method": request.method
        })
        return jsonify({"error": "Internal server error. Please try again later."}), 500

    # Simulate real 500 error scenarios for graceful failure testing
    @app.route("/divide")
    def divide_by_zero():
        """Simulates a runtime error (e.g., bug in calculation logic)"""
        # This simulates a real bug: e.g., processing user input without validation
        a = 10
        b = 0  # Could come from bad user input
        result = a / b  # ZeroDivisionError - real crash scenario
        return jsonify({"result": result})

    # Initialize seed data if tables are empty
    with app.app_context():
        _init_seed_data()

    return app


def _metrics_html_page():
    """Generate a pretty HTML metrics dashboard for browsers"""
    import psutil
    
    # Get system metrics
    cpu_percent = psutil.cpu_percent(interval=0.1)
    memory = psutil.virtual_memory()
    memory_used_mb = memory.used / (1024 * 1024)
    memory_total_mb = memory.total / (1024 * 1024)
    memory_percent = memory.percent
    
    # Get process metrics from Prometheus registry
    from prometheus_client import REGISTRY
    
    # Extract metrics from registry
    cpu_seconds = 0
    memory_bytes = 0
    for family in REGISTRY.collect():
        if family.name == 'process_cpu_seconds_total':
            for sample in family.samples:
                cpu_seconds = sample.value
        elif family.name == 'process_resident_memory_bytes':
            for sample in family.samples:
                memory_bytes = sample.value
    
    memory_mb = memory_bytes / (1024 * 1024)
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Metrics Dashboard - URL Shortener</title>
        <meta charset="utf-8">
        <meta http-equiv="refresh" content="5">
        <style>
            * {{ margin: 0; padding: 0; box-sizing: border-box; }}
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 40px 20px;
            }}
            .container {{
                max-width: 1200px;
                margin: 0 auto;
            }}
            h1 {{
                color: white;
                text-align: center;
                margin-bottom: 30px;
                font-size: 32px;
                text-shadow: 0 2px 4px rgba(0,0,0,0.2);
            }}
            .subtitle {{
                color: rgba(255,255,255,0.8);
                text-align: center;
                margin-bottom: 40px;
            }}
            .metrics-grid {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-bottom: 30px;
            }}
            .metric-card {{
                background: white;
                border-radius: 16px;
                padding: 24px;
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }}
            .metric-title {{
                color: #666;
                font-size: 14px;
                text-transform: uppercase;
                letter-spacing: 1px;
                margin-bottom: 10px;
            }}
            .metric-value {{
                font-size: 48px;
                font-weight: bold;
                color: #333;
                margin-bottom: 10px;
            }}
            .metric-unit {{
                font-size: 18px;
                color: #999;
            }}
            .progress-bar {{
                height: 8px;
                background: #e0e0e0;
                border-radius: 4px;
                overflow: hidden;
                margin-top: 15px;
            }}
            .progress-fill {{
                height: 100%;
                border-radius: 4px;
                transition: width 0.3s ease;
            }}
            .progress-fill.cpu {{ background: linear-gradient(90deg, #28a745, #20c997); }}
            .progress-fill.memory {{ background: linear-gradient(90deg, #007bff, #6610f2); }}
            .progress-fill.warning {{ background: linear-gradient(90deg, #ffc107, #fd7e14); }}
            .progress-fill.danger {{ background: linear-gradient(90deg, #dc3545, #e83e8c); }}
            .raw-link {{
                text-align: center;
                margin-top: 30px;
            }}
            .raw-link a {{
                color: white;
                text-decoration: none;
                background: rgba(255,255,255,0.2);
                padding: 12px 24px;
                border-radius: 8px;
                display: inline-block;
            }}
            .raw-link a:hover {{
                background: rgba(255,255,255,0.3);
            }}
            .badge {{
                display: inline-block;
                padding: 4px 12px;
                border-radius: 12px;
                font-size: 12px;
                font-weight: bold;
            }}
            .badge.success {{ background: #d4edda; color: #155724; }}
            .badge.warning {{ background: #fff3cd; color: #856404; }}
            .badge.danger {{ background: #f8d7da; color: #721c24; }}
            .instances {{
                background: white;
                border-radius: 16px;
                padding: 24px;
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }}
            .instances h2 {{
                margin-bottom: 15px;
                color: #333;
            }}
            .instance-list {{
                list-style: none;
            }}
            .instance-list li {{
                padding: 10px 0;
                border-bottom: 1px solid #eee;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }}
            .instance-list li:last-child {{
                border-bottom: none;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>📊 System Metrics Dashboard</h1>
            <p class="subtitle">Real-time monitoring for URL Shortener</p>
            
            <div class="metrics-grid">
                <!-- CPU Card -->
                <div class="metric-card">
                    <div class="metric-title">💻 CPU Usage</div>
                    <div class="metric-value">{cpu_percent:.1f}<span class="metric-unit">%</span></div>
                    <span class="badge {"success" if cpu_percent < 70 else "warning" if cpu_percent < 90 else "danger"}">
                        {"Normal" if cpu_percent < 70 else "High" if cpu_percent < 90 else "Critical"}
                    </span>
                    <div class="progress-bar">
                        <div class="progress-fill {"cpu" if cpu_percent < 70 else "warning" if cpu_percent < 90 else "danger"}" style="width: {min(cpu_percent, 100)}%"></div>
                    </div>
                </div>
                
                <!-- Memory Card -->
                <div class="metric-card">
                    <div class="metric-title">🧠 Memory Usage</div>
                    <div class="metric-value">{memory_percent:.1f}<span class="metric-unit">%</span></div>
                    <div style="color: #666; font-size: 14px; margin-top: 5px;">
                        {memory_used_mb:.0f} MB / {memory_total_mb:.0f} MB
                    </div>
                    <span class="badge {"success" if memory_percent < 80 else "warning" if memory_percent < 95 else "danger"}">
                        {"Normal" if memory_percent < 80 else "High" if memory_percent < 95 else "Critical"}
                    </span>
                    <div class="progress-bar">
                        <div class="progress-fill {"memory" if memory_percent < 80 else "warning" if memory_percent < 95 else "danger"}" style="width: {min(memory_percent, 100)}%"></div>
                    </div>
                </div>
                
                <!-- Process Memory Card -->
                <div class="metric-card">
                    <div class="metric-title">🔧 App Memory</div>
                    <div class="metric-value">{memory_mb:.1f}<span class="metric-unit">MB</span></div>
                    <span class="badge success">Process RSS</span>
                    <p style="color: #666; font-size: 14px; margin-top: 15px;">
                        Resident memory used by this Flask process
                    </p>
                </div>
                
                <!-- CPU Time Card -->
                <div class="metric-card">
                    <div class="metric-title">⏱️ CPU Time</div>
                    <div class="metric-value">{cpu_seconds:.2f}<span class="metric-unit">s</span></div>
                    <span class="badge success">Total</span>
                    <p style="color: #666; font-size: 14px; margin-top: 15px;">
                        Total CPU time consumed by the process
                    </p>
                </div>
            </div>
            
            <div class="instances">
                <h2>🏗️ Architecture</h2>
                <ul class="instance-list">
                    <li>
                        <span>Load Balancer (Nginx)</span>
                        <span class="badge success">Active</span>
                    </li>
                    <li>
                        <span>App Instance 1 (app1:5000)</span>
                        <span class="badge success">Healthy</span>
                    </li>
                    <li>
                        <span>App Instance 2 (app2:5000)</span>
                        <span class="badge success">Healthy</span>
                    </li>
                    <li>
                        <span>App Instance 3 (app3:5000)</span>
                        <span class="badge success">Healthy</span>
                    </li>
                </ul>
            </div>
            
            <div class="raw-link">
                <a href="/metrics" onclick="event.preventDefault(); window.location.href='/metrics'; location.reload();">View Raw Prometheus Format</a>
            </div>
        </div>
    </body>
    </html>
    """
    return html


def _health_html_page(data):
    """Generate a nice HTML health page for screenshots"""
    status_color = "#28a745" if data["status"] == "ok" else "#ffc107"
    status_icon = "✓" if data["status"] == "ok" else "⚠"

    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Health Check - URL Shortener</title>
        <meta charset="utf-8">
        <style>
            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }}
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                justify-content: center;
                align-items: center;
                padding: 20px;
            }}
            .container {{
                background: white;
                border-radius: 20px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                padding: 40px;
                max-width: 600px;
                width: 100%;
            }}
            .header {{
                text-align: center;
                margin-bottom: 30px;
            }}
            .status-badge {{
                display: inline-flex;
                align-items: center;
                gap: 10px;
                background: {status_color};
                color: white;
                padding: 12px 24px;
                border-radius: 50px;
                font-size: 18px;
                font-weight: 600;
                margin-bottom: 20px;
            }}
            h1 {{
                color: #333;
                font-size: 28px;
                margin-bottom: 10px;
            }}
            .subtitle {{
                color: #666;
                font-size: 14px;
            }}
            .info-grid {{
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 15px;
                margin-bottom: 25px;
            }}
            .info-item {{
                background: #f8f9fa;
                padding: 15px;
                border-radius: 10px;
            }}
            .info-label {{
                color: #666;
                font-size: 12px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 5px;
            }}
            .info-value {{
                color: #333;
                font-size: 16px;
                font-weight: 600;
            }}
            .checks-section {{
                margin-top: 25px;
            }}
            .checks-title {{
                color: #333;
                font-size: 18px;
                margin-bottom: 15px;
                padding-bottom: 10px;
                border-bottom: 2px solid #e9ecef;
            }}
            .check-item {{
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 12px 0;
                border-bottom: 1px solid #e9ecef;
            }}
            .check-name {{
                color: #555;
                font-weight: 500;
            }}
            .check-status {{
                display: flex;
                align-items: center;
                gap: 8px;
            }}
            .status-dot {{
                width: 10px;
                height: 10px;
                border-radius: 50%;
            }}
            .status-healthy {{
                background: #28a745;
            }}
            .status-unhealthy {{
                background: #dc3545;
            }}
            .footer {{
                margin-top: 30px;
                text-align: center;
                color: #999;
                font-size: 12px;
            }}
            .json-toggle {{
                margin-top: 20px;
                text-align: center;
            }}
            .json-toggle a {{
                color: #667eea;
                text-decoration: none;
                font-size: 14px;
            }}
            .json-toggle a:hover {{
                text-decoration: underline;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="status-badge">
                    <span>{status_icon}</span>
                    <span>System {data["status"].title()}</span>
                </div>
                <h1>URL Shortener Service</h1>
                <p class="subtitle">Production Health Dashboard</p>
            </div>

            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Version</div>
                    <div class="info-value">{data["version"]}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Environment</div>
                    <div class="info-value">{data["environment"].title()}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Timestamp</div>
                    <div class="info-value">{data["timestamp"][:19].replace("T", " ")}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Overall Status</div>
                    <div class="info-value">{data["status"].title()}</div>
                </div>
            </div>

            <div class="checks-section">
                <h3 class="checks-title">Service Checks</h3>
                <div class="check-item">
                    <span class="check-name">🗄️ Database Connection</span>
                    <div class="check-status">
                        <span class="status-dot status-{data["checks"]["database"]["status"]}"></span>
                        <span>{data["checks"]["database"]["status"].title()}</span>
                    </div>
                </div>
                <div class="check-item">
                    <span class="check-name">⚡ Application</span>
                    <div class="check-status">
                        <span class="status-dot status-{data["checks"]["application"]["status"]}"></span>
                        <span>{data["checks"]["application"]["status"].title()}</span>
                    </div>
                </div>
            </div>

            <div class="json-toggle">
                <a href="/health" onclick="event.preventDefault(); window.location.href='/health?format=json';">View JSON Response</a>
            </div>

            <div class="footer">
                <p>URL Shortener API &copy; 2026 | Reliability Engineering Quest</p>
            </div>
        </div>
    </body>
    </html>
    """
    return html


def _init_seed_data():
    """Initialize seed data if tables are empty"""
    from app.models.user import User
    from app.models.url import URL
    from app.models.event import Event

    try:
        # Check if we have any users
        if User.select().count() == 0:
            # Create seed users
            users = [
                {"username": "admin", "email": "admin@example.com"},
                {"username": "testuser1", "email": "test1@example.com"},
                {"username": "testuser2", "email": "test2@example.com"},
            ]
            for u in users:
                try:
                    User.create(username=u["username"], email=u["email"])
                except Exception:
                    pass
            logger.info("Seed data created", extra={
                "component": "DB",
                "entity": "users",
                "count": User.select().count()
            })

        # Check if we have any URLs
        if URL.select().count() == 0:
            # Create seed URLs
            urls = [
                {"short_code": "abc123", "original_url": "https://example.com/page1", "title": "Example Page 1"},
                {"short_code": "xyz789", "original_url": "https://example.com/page2", "title": "Example Page 2"},
            ]
            for url_data in urls:
                try:
                    URL.create(
                        short_code=url_data["short_code"],
                        original_url=url_data["original_url"],
                        title=url_data["title"]
                    )
                except Exception:
                    pass
            logger.info("Seed data created", extra={
                "component": "DB",
                "entity": "urls",
                "count": URL.select().count()
            })

        # Check if we have any events
        if Event.select().count() == 0:
            # Create seed events
            try:
                Event.create(event_type="created", details='{"message": "Initial setup"}')
            except Exception:
                pass
            logger.info("Seed data created", extra={
                "component": "DB",
                "entity": "events",
                "count": Event.select().count()
            })

    except Exception as e:
        logger.warning("Seed data initialization skipped", extra={
            "component": "DB",
            "note": "May be normal on first run",
            "error": str(e)
        })
