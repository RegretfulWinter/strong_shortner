"""
Migration: Add user profile fields
Created: 2024-01-01T00:00:00

This is an example migration showing how to:
1. Add a new column to existing table
2. Create a new table
3. Modify existing data
"""

from peewee import *
from playhouse.migrate import PostgresqlMigrator, migrate
from app.database import db

# Initialize migrator
migrator = PostgresqlMigrator(db)


def upgrade():
    """Apply migration"""
    # Example 1: Add a new column to existing table
    # migrate(
    #     migrator.add_column('user', 'bio', TextField(null=True)),
    #     migrator.add_column('user', 'avatar_url', CharField(max_length=500, null=True)),
    # )
    
    # Example 2: Add a column with default value
    # migrate(
    #     migrator.add_column('user', 'is_active', BooleanField(default=True)),
    # )
    
    # Example 3: Create new table
    # from app.database import BaseModel
    # class UserProfile(BaseModel):
    #     user_id = IntegerField()
    #     bio = TextField(null=True)
    #     website = CharField(max_length=255, null=True)
    # 
    # db.create_tables([UserProfile])
    
    # Example 4: Run raw SQL
    # db.execute_sql("CREATE INDEX idx_user_email ON user(email)")
    
    print("Example migration - nothing actually changed")


def downgrade():
    """Revert migration"""
    # Example: Remove added columns
    # migrate(
    #     migrator.drop_column('user', 'bio'),
    #     migrator.drop_column('user', 'avatar_url'),
    # )
    
    # Example: Drop table
    # db.execute_sql("DROP TABLE IF EXISTS userprofile")
    
    print("Example rollback - nothing actually changed")
