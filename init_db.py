#!/usr/bin/env python3
"""
Initialize database tables for URL Shortener
Usage: python init_db.py

NOTE: For hackathon evaluation, seed data is automatically loaded by the judges.
This script only creates tables if they don't exist (idempotent).
"""

from app import create_app
from app.database import db
from app.models import User, URL, Event


def init_database():
    """Create all database tables (safe=True means no error if tables exist)"""
    app = create_app()
    
    with app.app_context():
        # Create tables only if they don't exist (safe=True)
        # For evaluation, seed data is already loaded by judges
        db.create_tables([User, URL, Event], safe=True)
        print("✅ Database tables initialized (safe mode)")
        print("   Note: For hackathon evals, seed data is pre-loaded")


if __name__ == "__main__":
    init_database()
