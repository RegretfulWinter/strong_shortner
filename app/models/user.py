from peewee import CharField, DateTimeField, AutoField
from datetime import datetime
from app.database import BaseModel
import secrets


class User(BaseModel):
    id = AutoField()  # Auto increment primary key
    username = CharField()  # Allow duplicates for bulk import
    email = CharField()
    api_token = CharField(unique=True, null=True)  # For authentication
    created_at = DateTimeField(default=datetime.now)
    
    class Meta:
        table_name = 'users'  # Avoid 'user' reserved keyword
    
    def generate_api_token(self):
        """Generate a unique API token for this user"""
        self.api_token = secrets.token_urlsafe(32)
        self.save()
        return self.api_token
