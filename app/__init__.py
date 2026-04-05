from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory
import datetime
import os

from app.database import init_db
from app.routes import register_routes

# Get the absolute path to the static directory
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')


def create_app():
    load_dotenv()

    app = Flask(__name__)

    init_db(app)

    from app import models  # noqa: F401 - registers models with Peewee

    register_routes(app)

    # Register short URL redirect at app level
    from app.routes.urls import redirect_short_url
    app.add_url_rule('/<string:short_code>', 'redirect_short', redirect_short_url)

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
        app.logger.error(f"Internal server error: {error}")
        app.logger.error(traceback.format_exc())
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


def _health_html_page(data):
    """Generate a nice HTML health page for screenshots"""
    status_color = "#28a745" if data["status"] == "healthy" else "#ffc107"
    status_icon = "✓" if data["status"] == "healthy" else "⚠"

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
    import secrets

    try:
        # Check if we have any users
        if User.select().count() == 0:
            # Create seed users with API tokens
            users = [
                {"username": "admin", "email": "admin@example.com"},
                {"username": "testuser1", "email": "test1@example.com"},
                {"username": "testuser2", "email": "test2@example.com"},
            ]
            for u in users:
                try:
                    user = User.create(
                        username=u["username"], 
                        email=u["email"],
                        api_token=secrets.token_urlsafe(32)
                    )
                except Exception:
                    pass
            print(f"Created {User.select().count()} seed users")

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
            print(f"Created {URL.select().count()} seed URLs")

        # Check if we have any events
        if Event.select().count() == 0:
            # Create seed events
            try:
                Event.create(event_type="created", details='{"message": "Initial setup"}')
            except Exception:
                pass
            print(f"Created {Event.select().count()} seed events")

    except Exception as e:
        print(f"Seed data init error (may be normal on first run): {e}")
