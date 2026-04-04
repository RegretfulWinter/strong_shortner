from peewee import CharField, DateTimeField, ForeignKeyField, IntegerField, TextField
from datetime import datetime
from app.database import BaseModel
from app.models.user import User
from app.models.url import URL


class Event(BaseModel):
    id = IntegerField(primary_key=True)  # 对应 CSV 的 id
    url = ForeignKeyField(URL, backref='events', null=True)
    user = ForeignKeyField(User, backref='events', null=True)
    event_type = CharField()  # e.g., "created"
    timestamp = DateTimeField(default=datetime.now)
    details = TextField(null=True)  # JSON string
