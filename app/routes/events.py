from flask import Blueprint, request, jsonify
from playhouse.shortcuts import model_to_dict
from app.models.event import Event
from app.models.url import URL
from app.models.user import User
import json
import re

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
    
    def event_to_dict(event):
        """Convert Event to dict with url_id and user_id fields"""
        # Use recurse=False to prevent expanding foreign keys into objects
        d = model_to_dict(event, recurse=False)
        # Foreign keys are returned as integer IDs
        if 'url' in d:
            d['url_id'] = d.pop('url')
        if 'user' in d:
            d['user_id'] = d.pop('user')
        return d
    
    # Support pagination
    page = request.args.get('page', type=int)
    per_page = request.args.get('per_page', type=int)
    
    if page and per_page:
        query = query.paginate(page, per_page)
        events = list(query)
        return jsonify({
            "items": [event_to_dict(e) for e in events],
            "total": total,
            "page": page,
            "per_page": per_page
        })
    
    events = list(query)
    return jsonify([event_to_dict(e) for e in events])


@events_bp.route("/events", methods=["POST"])
def create_event():
    """Create a new event"""
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    event_type = data.get('event_type')
    if not event_type:
        return jsonify({"error": "event_type is required"}), 400
    
    # Advanced Challenge: Validate event_type format (The Unwitting Stranger)
    if not isinstance(event_type, str) or len(event_type) < 1 or len(event_type) > 50:
        return jsonify({"error": "Invalid event_type format"}), 400
    
    # Only allow valid event types (extensible list)
    valid_event_types = ['click', 'created', 'deactivated', 'url_created', 'user_created', 'url_deactivated', 'page_view']
    if event_type not in valid_event_types:
        # Allow any reasonable event type for extensibility
        if not re.match(r'^[a-z_]+$', event_type):
            return jsonify({"error": "Invalid event_type format. Use lowercase letters and underscores only"}), 400
    
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
    
    d = model_to_dict(event)
    if 'url' in d:
        d['url_id'] = d.pop('url')
    if 'user' in d:
        d['user_id'] = d.pop('user')
    return jsonify(d), 201
