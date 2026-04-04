#!/usr/bin/env python3
"""
Database Migration Manager for URL Shortener
Supports: create, migrate, reset, status

Usage:
    python migrations.py create  "Add user bio field"
    python migrations.py upgrade
    python migrations.py reset   # ⚠️ Drops all data!
    python migrations.py status
"""

import os
import sys
import json
import importlib
from datetime import datetime
from pathlib import Path

# Migration tracking file
MIGRATIONS_DIR = Path("migrations")
MIGRATIONS_FILE = MIGRATIONS_DIR / "_migrations.json"


def init_migration_system():
    """Initialize migration tracking"""
    MIGRATIONS_DIR.mkdir(exist_ok=True)
    if not MIGRATIONS_FILE.exists():
        save_migrations_state({"applied": [], "current": None})


def load_migrations_state():
    """Load applied migrations"""
    if MIGRATIONS_FILE.exists():
        with open(MIGRATIONS_FILE) as f:
            return json.load(f)
    return {"applied": [], "current": None}


def save_migrations_state(state):
    """Save migrations state"""
    with open(MIGRATIONS_FILE, 'w') as f:
        json.dump(state, f, indent=2)


def create_migration(name):
    """Create a new migration file"""
    init_migration_system()
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{timestamp}_{name.replace(' ', '_').lower()}.py"
    filepath = MIGRATIONS_DIR / filename
    
    template = f'''"""
Migration: {name}
Created: {datetime.now().isoformat()}
"""

from peewee import *
from app.database import db

# Define your schema changes here
def upgrade():
    """Apply migration"""
    # Example: Add a new column
    # migrator.add_column('user', 'bio', TextField(null=True))
    
    # Example: Create new table
    # db.create_tables([NewModel])
    
    # Example: Alter column
    # migrator.alter_column_type('user', 'email', CharField(max_length=255))
    
    pass


def downgrade():
    """Revert migration"""
    # Example: Remove column
    # migrator.drop_column('user', 'bio')
    
    # Example: Drop table
    # db.drop_tables([NewModel])
    
    pass
'''
    
    with open(filepath, 'w') as f:
        f.write(template)
    
    print(f"✅ Created migration: {filepath}")
    print(f"   Edit the file and implement upgrade() and downgrade()")


def run_migrations():
    """Run pending migrations"""
    init_migration_system()
    
    from app import create_app
    app = create_app()
    
    with app.app_context():
        state = load_migrations_state()
        applied = set(state["applied"])
        
        # Get all migration files
        migration_files = sorted([
            f for f in MIGRATIONS_DIR.glob("*.py")
            if not f.name.startswith("_") and f.name != "__init__.py"
        ])
        
        pending = [f for f in migration_files if f.stem not in applied]
        
        if not pending:
            print("✅ No pending migrations")
            return
        
        print(f"Found {len(pending)} pending migration(s):")
        
        for migration_file in pending:
            print(f"\n  Applying: {migration_file.name}")
            
            try:
                # Import and run migration
                spec = importlib.util.spec_from_file_location(
                    migration_file.stem, migration_file
                )
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                
                if hasattr(module, 'upgrade'):
                    module.upgrade()
                    print(f"  ✅ Applied")
                else:
                    print(f"  ⚠️  No upgrade() function found")
                
                # Mark as applied
                state["applied"].append(migration_file.stem)
                state["current"] = migration_file.stem
                save_migrations_state(state)
                
            except Exception as e:
                print(f"  ❌ Failed: {e}")
                raise
        
        print(f"\n✅ All migrations applied successfully!")


def reset_database():
    """⚠️ Drop all tables and recreate (DELETES ALL DATA!)"""
    confirm = input("⚠️  This will DELETE ALL DATA! Type 'yes' to confirm: ")
    if confirm != 'yes':
        print("Cancelled.")
        return
    
    from app import create_app
    from app.database import db
    from app.models import User, URL, Event
    
    app = create_app()
    
    with app.app_context():
        print("Dropping all tables...")
        db.drop_tables([User, URL, Event], safe=True)
        
        print("Recreating tables...")
        db.create_tables([User, URL, Event])
        
        # Clear migration state
        save_migrations_state({"applied": [], "current": None})
        
        print("✅ Database reset complete!")


def show_status():
    """Show migration status"""
    init_migration_system()
    state = load_migrations_state()
    
    print("Migration Status:")
    print(f"  Current: {state.get('current') or 'None'}")
    print(f"  Applied: {len(state['applied'])}")
    
    if state['applied']:
        print("\n  Applied migrations:")
        for m in state['applied']:
            print(f"    ✓ {m}")


def quick_add_column(table_name, column_name, field_type):
    """Quick helper to add a column without writing migration file"""
    from app import create_app
    from app.database import db
    
    app = create_app()
    
    with app.app_context():
        # Execute raw SQL for quick schema changes
        field_sql = {
            'char': f'ALTER TABLE {table_name} ADD COLUMN {column_name} VARCHAR(255)',
            'text': f'ALTER TABLE {table_name} ADD COLUMN {column_name} TEXT',
            'int': f'ALTER TABLE {table_name} ADD COLUMN {column_name} INTEGER',
            'bool': f'ALTER TABLE {table_name} ADD COLUMN {column_name} BOOLEAN',
            'datetime': f'ALTER TABLE {table_name} ADD COLUMN {column_name} TIMESTAMP',
        }
        
        sql = field_sql.get(field_type)
        if not sql:
            print(f"Unknown field type: {field_type}")
            return
        
        try:
            db.execute_sql(sql)
            print(f"✅ Added column: {table_name}.{column_name} ({field_type})")
        except Exception as e:
            print(f"❌ Error: {e}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "create" and len(sys.argv) >= 3:
        create_migration(" ".join(sys.argv[2:]))
    elif command == "upgrade":
        run_migrations()
    elif command == "reset":
        reset_database()
    elif command == "status":
        show_status()
    elif command == "add_column" and len(sys.argv) >= 5:
        # Usage: python migrations.py add_column users bio text
        quick_add_column(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print(__doc__)
        sys.exit(1)
