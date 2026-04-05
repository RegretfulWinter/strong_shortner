import random
import string
from flask import Blueprint, request, jsonify, redirect
from playhouse.shortcuts import model_to_dict
from datetime import datetime
from app.models.url import URL
from app.models.user import User

urls_bp = Blueprint("urls", __name__)


def generate_short_code(length=6):
    chars = string.ascii_letters + string.digits
    return ''.join(random.choices(chars, k=length))


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
    data = request.get_json()
    if not data or 'original_url' not in data:
        return jsonify({"error": "Original URL is required"}), 400
    
    user_id = data.get('user_id')
    if user_id:
        try:
            User.get_by_id(user_id)
        except User.DoesNotExist:
            return jsonify({"error": "User not found"}), 404
    
    short_code = generate_short_code()
    while URL.select().where(URL.short_code == short_code).exists():
        short_code = generate_short_code()
    
    url = URL.create(
        user=user_id,
        short_code=short_code,
        original_url=data['original_url'],
        title=data.get('title', '')
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
    for field in ['title', 'is_active']:
        if field in data:
            setattr(url, field, data[field])
    
    url.updated_at = datetime.now()
    url.save()
    
    d = model_to_dict(url, recurse=False)
    if 'user' in d:
        d['user_id'] = d.pop('user')
    return jsonify(d)


@urls_bp.route("/urls/<int:url_id>", methods=["DELETE"])
def delete_url(url_id):
    try:
        url = URL.get_by_id(url_id)
        url.delete_instance()
        return jsonify({"message": "URL deleted"}), 200
    except URL.DoesNotExist:
        return jsonify({"error": "URL not found"}), 404


# Short URL redirect - this must be registered at app level, not in blueprint
@urls_bp.route("/<string:short_code>", methods=["GET"])
def redirect_short_url(short_code):
    """Redirect short code to original URL"""
    try:
        url = URL.get(URL.short_code == short_code, URL.is_active == True)
        # Record event
        from app.models.event import Event
        Event.create(
            url=url.id,
            user=url.user,
            event_type='click',
            details=f'{{"short_code": "{short_code}"}}'
        )
        return redirect(url.original_url, code=302)
    except URL.DoesNotExist:
        return jsonify({"error": "Short URL not found or inactive"}), 404
