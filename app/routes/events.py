from flask import Blueprint, request, jsonify
from playhouse.shortcuts import model_to_dict
from app.models.event import Event

events_bp = Blueprint("events", __name__)


@events_bp.route("/events", methods=["GET"])
def list_events():
    # Support pagination
    page = request.args.get('page', type=int)
    per_page = request.args.get('per_page', type=int)
    
    query = Event.select().order_by(Event.timestamp.desc())
    total = query.count()
    
    if page and per_page:
        query = query.paginate(page, per_page)
        events = list(query)
        return jsonify({
            "items": [model_to_dict(e) for e in events],
            "total": total,
            "page": page,
            "per_page": per_page
        })
    
    events = list(query)
    return jsonify([model_to_dict(e) for e in events])
