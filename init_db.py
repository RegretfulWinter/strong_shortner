#!/usr/bin/env python3
"""
Initialize database tables for URL Shortener
Usage: python init_db.py
"""

from app import create_app
from app.database import db
from app.models import User, URL, Event


def init_database():
    """Create all database tables"""
    app = create_app()
    
    with app.app_context():
        # Create tables
        db.create_tables([User, URL, Event])
        print("✅ Database tables created successfully!")
        print("   - users")
        print("   - urls")
        print("   - events")


if __name__ == "__main__":
    init_database()
