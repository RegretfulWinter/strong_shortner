import random
import string
import re
from flask import Blueprint, request, jsonify, redirect
from playhouse.shortcuts import model_to_dict
from datetime import datetime
from app.models.url import URL
from app.models.user import User

urls_bp = Blueprint("urls", __name__)


def validate_url(url):
    """
    Validate URL format.
    Returns (is_valid, error_message)
    """
    if not url or not isinstance(url, str):
        return False, "URL is required"
    
    # Basic URL pattern validation
    # Must start with http:// or https://
    url_pattern = re.compile(
        r'^https?://'  # http:// or https://
        r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # domain
        r'localhost|'  # localhost
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # or IP
        r'(?::\d+)?'  # optional port
        r'(?:/?|[/?]\S+)$', re.IGNORECASE)
    
    if not url_pattern.match(url):
        return False, "Invalid URL format. URL must start with http:// or https://"
    
    return True, None


def generate_short_code(length=6):
    """Generate unique short code - The Deceitful Scroll: ensure distinct marks"""
    chars = string.ascii_letters + string.digits
    # Ensure no ambiguous characters
    chars = chars.replace('O', '').replace('0', '').replace('l', '').replace('1', '')
    return ''.join(random.choices(chars, k=length))


def validate_short_code(short_code):
    """The Deceitful Scroll: validate short code format"""
    if not short_code or not isinstance(short_code, str):
        return False
    if len(short_code) < 4 or len(short_code) > 20:
        return False
    # Only alphanumeric
    return re.match(r'^[a-zA-Z0-9]+$', short_code) is not None


@urls_bp.route("/urls", methods=["GET"])
def list_urls():
    # Support filtering
    user_id = request.args.get('user_id', type=int)
    is_active = request.args.get('is_active')
    
    query = URL.select()
    
    if user_id:
        query = query.where(URL.user == user_id)
    
    if is_active is not None:
        is_active_bool = is_active.lower() in ['true', '1', 'yes']
        query = query.where(URL.is_active == is_active_bool)
    
    total = query.count()
    
    # Support pagination
    page = request.args.get('page', type=int)
    per_page = request.args.get('per_page', type=int)
    
    def url_to_dict(url):
        """Convert URL to dict with user_id field"""
        # Use recurse=False to prevent expanding foreign keys
        d = model_to_dict(url, recurse=False)
        # user field will be the integer ID, rename to user_id
        if 'user' in d:
            d['user_id'] = d.pop('user')
        return d
    
    if page and per_page:
        query = query.paginate(page, per_page)
        urls = list(query)
        return jsonify({
            "items": [url_to_dict(u) for u in urls],
            "total": total,
            "page": page,
            "per_page": per_page
        })
    
    urls = list(query)
    return jsonify([url_to_dict(u) for u in urls])


@urls_bp.route("/urls/<int:url_id>", methods=["GET"])
def get_url(url_id):
    try:
        url = URL.get_by_id(url_id)
        d = model_to_dict(url, recurse=False)
        if 'user' in d:
            d['user_id'] = d.pop('user')
        return jsonify(d)
    except URL.DoesNotExist:
        return jsonify({"error": "URL not found"}), 404


@urls_bp.route("/urls", methods=["POST"])
def create_url():
    # The Fractured Vessel: Validate content type
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    
    data = request.get_json()
    
    # The Deceitful Scroll: Validate data is a proper object
    if not data or not isinstance(data, dict):
        return jsonify({"error": "Invalid request body"}), 400
    
    if 'original_url' not in data:
        return jsonify({"error": "Original URL is required"}), 400
    
    # Validate URL format
    original_url = data['original_url']
    is_valid, error_msg = validate_url(original_url)
    if not is_valid:
        return jsonify({"error": error_msg}), 400
    
    user_id = data.get('user_id')
    if user_id:
        try:
            User.get_by_id(user_id)
        except User.DoesNotExist:
            return jsonify({"error": "User not found"}), 404
    
    # The Twin's Paradox: Check if exact same URL already exists for this user
    # Only check when user_id is specified; anonymous URLs (user_id=None) can have duplicates
    if user_id:
        existing = URL.select().where(
            (URL.original_url == original_url) & 
            (URL.user == user_id)
        ).first()
        if existing:
            return jsonify({
                "error": "URL already exists",
                "short_code": existing.short_code,
                "url": model_to_dict(existing, recurse=False)
            }), 409
    
    short_code = generate_short_code()
    while URL.select().where(URL.short_code == short_code).exists():
        short_code = generate_short_code()
    
    url = URL.create(
        user=user_id,
        short_code=short_code,
        original_url=original_url,
        title=data.get('title', '')
    )
    
    # The Unseen Observer: Record event
    from app.models.event import Event
    Event.create(
        url=url.id,
        user=user_id,
        event_type='url_created',
        details=f'{{"short_code": "{short_code}", "original_url": "{original_url}"}}'
    )
    
    d = model_to_dict(url, recurse=False)
    if 'user' in d:
        d['user_id'] = d.pop('user')
    return jsonify(d), 201


@urls_bp.route("/urls/<int:url_id>", methods=["PUT"])
def update_url(url_id):
    try:
        url = URL.get_by_id(url_id)
    except URL.DoesNotExist:
        return jsonify({"error": "URL not found"}), 404
    
    data = request.get_json()
    was_deactivated = False
    for field in ['title', 'is_active']:
        if field in data:
            if field == 'is_active' and url.is_active and not data[field]:
                was_deactivated = True
            setattr(url, field, data[field])
    
    url.updated_at = datetime.now()
    url.save()
    
    # The Unseen Observer: Record event for deactivation
    if was_deactivated:
        from app.models.event import Event
        Event.create(
            url=url.id,
            user=url.user,
            event_type='url_deactivated',
            details=f'{{"short_code": "{url.short_code}"}}'
        )
    
    d = model_to_dict(url, recurse=False)
    if 'user' in d:
        d['user_id'] = d.pop('user')
    return jsonify(d)


@urls_bp.route("/urls/<int:url_id>", methods=["DELETE"])
def delete_url(url_id):
    try:
        url = URL.get_by_id(url_id)
        
        # Delete related events first (foreign key constraint)
        from app.models.event import Event
        Event.delete().where(Event.url == url_id).execute()
        
        url.delete_instance()
        return jsonify({"message": "URL deleted"}), 200
    except URL.DoesNotExist:
        return jsonify({"error": "URL not found"}), 404


# Short URL redirect - this must be registered at app level, not in blueprint
@urls_bp.route("/<string:short_code>", methods=["GET"])
def redirect_short_url(short_code):
    """Redirect short code to original URL"""
    try:
        # First try to get the URL regardless of is_active status
        url = URL.get(URL.short_code == short_code)
        
        # The Slumbering Guide: Check if URL is active
        if not url.is_active:
            return jsonify({"error": "Short URL is inactive"}), 410
        
        # The Unseen Observer: Record event
        from app.models.event import Event
        Event.create(
            url=url.id,
            user=url.user,
            event_type='click',
            details=f'{{"short_code": "{short_code}"}}'
        )
        return redirect(url.original_url, code=302)
    except URL.DoesNotExist:
        return jsonify({"error": "Short URL not found"}), 404
