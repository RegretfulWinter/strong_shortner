from flask import Blueprint, request, jsonify
from playhouse.shortcuts import model_to_dict
from app.models.event import Event
from app.models.url import URL
from app.models.user import User
import json

events_bp = Blueprint("events", __name__)


@events_bp.route("/events", methods=["GET"])
def list_events():
    # Support filtering
    url_id = request.args.get('url_id', type=int)
    user_id = request.args.get('user_id', type=int)
    event_type = request.args.get('event_type')
    
    query = Event.select().order_by(Event.timestamp.desc())
    
    if url_id:
        query = query.where(Event.url == url_id)
    
    if user_id:
        query = query.where(Event.user == user_id)
    
    if event_type:
        query = query.where(Event.event_type == event_type)
    
    total = query.count()
    
    # Support pagination
    page = request.args.get('page', type=int)
    per_page = request.args.get('per_page', type=int)
    
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


@events_bp.route("/events", methods=["POST"])
def create_event():
    """Create a new event"""
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    event_type = data.get('event_type')
    if not event_type:
        return jsonify({"error": "event_type is required"}), 400
    
    url_id = data.get('url_id')
    user_id = data.get('user_id')
    
    # Validate foreign keys if provided
    if url_id:
        try:
            URL.get_by_id(url_id)
        except URL.DoesNotExist:
            return jsonify({"error": "URL not found"}), 404
    
    if user_id:
        try:
            User.get_by_id(user_id)
        except User.DoesNotExist:
            return jsonify({"error": "User not found"}), 404
    
    # Handle details - can be dict or string
    details = data.get('details', '')
    if isinstance(details, dict):
        details = json.dumps(details)
    
    event = Event.create(
        url=url_id,
        user=user_id,
        event_type=event_type,
        details=details
    )
    
    return jsonify(model_to_dict(event)), 201
