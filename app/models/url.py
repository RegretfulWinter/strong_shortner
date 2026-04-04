from peewee import CharField, IntegerField, BooleanField, DateTimeField, ForeignKeyField
from datetime import datetime
from app.database import BaseModel
from app.models.user import User


class URL(BaseModel):
    id = IntegerField(primary_key=True)  # 对应 CSV 的 id
    user = ForeignKeyField(User, backref='urls', null=True)
    short_code = CharField(unique=True)
    original_url = CharField()
    title = CharField(null=True)
    is_active = BooleanField(default=True)
    created_at = DateTimeField(default=datetime.now)
    updated_at = DateTimeField(default=datetime.now)
