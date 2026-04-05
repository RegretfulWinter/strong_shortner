from peewee import CharField, DateTimeField, AutoField
from datetime import datetime
from app.database import BaseModel
import secrets


class User(BaseModel):
    id = AutoField()  # Auto increment primary key
    username = CharField()  # Allow duplicates with different timestamps
    email = CharField()
    api_token = CharField(unique=True, null=True)  # For authentication
    created_at = DateTimeField(default=datetime.now)
    
    class Meta:
        table_name = 'users'  # Avoid 'user' reserved keyword
        # Composite unique constraint: same username can exist with different timestamps
        indexes = (
            (('username', 'created_at'), True),  # True = unique
        )
    
    def generate_api_token(self):
        """Generate a unique API token for this user"""
        self.api_token = secrets.token_urlsafe(32)
        self.save()
        return self.api_token
