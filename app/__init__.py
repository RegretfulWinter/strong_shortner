from dotenv import load_dotenv
from flask import Flask, jsonify

from app.database import init_db
from app.routes import register_routes


def create_app():
    load_dotenv()

    app = Flask(__name__)

    init_db(app)

    from app import models  # noqa: F401 - registers models with Peewee

    register_routes(app)

    # Register short URL redirect at app level
    from app.routes.urls import redirect_short_url
    app.add_url_rule('/<string:short_code>', 'redirect_short', redirect_short_url)

    @app.route("/health")
    def health():
        return jsonify(status="ok")

    # Initialize seed data if tables are empty
    with app.app_context():
        _init_seed_data()

    return app


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
