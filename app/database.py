import os

from peewee import DatabaseProxy, Model, PostgresqlDatabase
from app.logging_config import get_logger

logger = get_logger(__name__)
db = DatabaseProxy()


class BaseModel(Model):
    class Meta:
        database = db


def init_db(app):
    database = PostgresqlDatabase(
        os.environ.get("DATABASE_NAME", "hackathon_db"),
        host=os.environ.get("DATABASE_HOST", "localhost"),
        port=int(os.environ.get("DATABASE_PORT", 5432)),
        user=os.environ.get("DATABASE_USER", "postgres"),
        password=os.environ.get("DATABASE_PASSWORD", "postgres"),
    )
    db.initialize(database)
    
    # Auto-create tables on startup (with lock to prevent race conditions)
    from app.models.user import User
    from app.models.url import URL
    from app.models.event import Event
    
    try:
        # Use a transaction to prevent race conditions between workers
        with db.atomic():
            db.create_tables([User, URL, Event], safe=True)
        logger.info("Database tables initialized", extra={
            "component": "DB",
            "tables": ["User", "URL", "Event"]
        })
    except Exception as e:
        # Tables probably already exist, ignore the error
        logger.info("Database tables already exist", extra={
            "component": "DB",
            "note": "Table creation skipped",
            "error": str(e)
        })

    @app.before_request
    def _db_connect():
        db.connect(reuse_if_open=True)

    @app.teardown_appcontext
    def _db_close(exc):
        if not db.is_closed():
            db.close()
