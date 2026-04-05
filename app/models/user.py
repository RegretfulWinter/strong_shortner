from peewee import CharField, DateTimeField, AutoField
from datetime import datetime
from app.database import BaseModel


class User(BaseModel):
    id = AutoField()  # Auto increment primary key
    username = CharField(unique=True)
    email = CharField()
    created_at = DateTimeField(default=datetime.now)
    
    class Meta:
        table_name = 'users'  # Avoid 'user' reserved keyword
