#!/usr/bin/env python3
"""
Import seed data from CSV files
Usage: python import_csv.py [users.csv] [urls.csv] [events.csv]

NOTE: This script is for LOCAL DEVELOPMENT ONLY.
For hackathon evaluation, seed data is automatically loaded by judges.
Do not include CSV import in your Docker startup or CI/CD pipeline.
"""

import sys
import csv
from datetime import datetime
from app import create_app
from app.database import db
from app.models import User, URL, Event


def parse_datetime(dt_str):
    """Parse datetime from CSV format"""
    if not dt_str:
        return datetime.now()
    try:
        return datetime.strptime(dt_str, "%Y-%m-%d %H:%M:%S")
    except:
        return datetime.now()


def import_users(filepath):
    """Import users from CSV"""
    with open(filepath, 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        count = 0
        skipped = 0
        for row in reader:
            try:
                User.create(
                    id=int(row['id']),
                    username=row['username'],
                    email=row['email'],
                    created_at=parse_datetime(row.get('created_at'))
                )
                count += 1
            except Exception as e:
                skipped += 1
        print(f"✅ Imported {count} users, skipped {skipped}")
        return count


def import_urls(filepath):
    """Import URLs from CSV"""
    with open(filepath, 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        count = 0
        skipped = 0
        for row in reader:
            try:
                # Skip if user doesn't exist
                user_id = int(row['user_id']) if row.get('user_id') else None
                if user_id and not User.select().where(User.id == user_id).exists():
                    skipped += 1
                    continue
                
                URL.create(
                    id=int(row['id']),
                    user=user_id,
                    short_code=row['short_code'],
                    original_url=row['original_url'],
                    title=row.get('title'),
                    is_active=row.get('is_active', 'True').lower() == 'true',
                    created_at=parse_datetime(row.get('created_at')),
                    updated_at=parse_datetime(row.get('updated_at'))
                )
                count += 1
            except Exception as e:
                skipped += 1
        print(f"✅ Imported {count} URLs, skipped {skipped}")
        return count


def import_events(filepath):
    """Import events from CSV"""
    with open(filepath, 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        count = 0
        skipped = 0
        for row in reader:
            try:
                # Skip if foreign keys don't exist
                url_id = int(row['url_id']) if row.get('url_id') else None
                user_id = int(row['user_id']) if row.get('user_id') else None
                
                if url_id and not URL.select().where(URL.id == url_id).exists():
                    skipped += 1
                    continue
                if user_id and not User.select().where(User.id == user_id).exists():
                    skipped += 1
                    continue
                
                Event.create(
                    id=int(row['id']),
                    url=url_id,
                    user=user_id,
                    event_type=row['event_type'],
                    timestamp=parse_datetime(row.get('timestamp')),
                    details=row.get('details')
                )
                count += 1
            except Exception as e:
                skipped += 1
        print(f"✅ Imported {count} events, skipped {skipped}")
        return count


def main():
    app = create_app()
    
    with app.app_context():
        if len(sys.argv) < 2:
            print("Usage: python import_csv.py [users.csv] [urls.csv] [events.csv]")
            sys.exit(1)
        
        total = 0
        
        for filepath in sys.argv[1:]:
            if 'user' in filepath.lower():
                total += import_users(filepath)
            elif 'url' in filepath.lower():
                total += import_urls(filepath)
            elif 'event' in filepath.lower():
                total += import_events(filepath)
        
        print(f"\n🎉 Total imported: {total} records")
        print(f"\nFinal counts:")
        print(f"  Users: {User.select().count()}")
        print(f"  URLs: {URL.select().count()}")
        print(f"  Events: {Event.select().count()}")


if __name__ == "__main__":
    main()
