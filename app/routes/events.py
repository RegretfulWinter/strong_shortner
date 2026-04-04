from flask import Blueprint, jsonify
from playhouse.shortcuts import model_to_dict
from app.models.event import Event

events_bp = Blueprint("events", __name__)


@events_bp.route("/events", methods=["GET"])
def list_events():
    events = Event.select().order_by(Event.timestamp.desc())
    return jsonify([model_to_dict(e) for e in events])
