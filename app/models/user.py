from peewee import CharField, DateTimeField, IntegerField
from datetime import datetime
from app.database import BaseModel


class User(BaseModel):
    id = IntegerField(primary_key=True)  # 对应 CSV 的 id
    username = CharField(unique=True)
    email = CharField()
    created_at = DateTimeField(default=datetime.now)
