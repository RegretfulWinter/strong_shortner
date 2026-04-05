import random
import string
from flask import Blueprint, request, jsonify
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
    # Support pagination
    page = request.args.get('page', type=int)
    per_page = request.args.get('per_page', type=int)
    
    query = URL.select()
    total = query.count()
    
    if page and per_page:
        query = query.paginate(page, per_page)
        urls = list(query)
        return jsonify({
            "items": [model_to_dict(u) for u in urls],
            "total": total,
            "page": page,
            "per_page": per_page
        })
    
    urls = list(query)
    return jsonify([model_to_dict(u) for u in urls])


@urls_bp.route("/urls/<int:url_id>", methods=["GET"])
def get_url(url_id):
    try:
        url = URL.get_by_id(url_id)
        return jsonify(model_to_dict(url))
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
    
    return jsonify(model_to_dict(url)), 201


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
    
    return jsonify(model_to_dict(url))


@urls_bp.route("/urls/<int:url_id>", methods=["DELETE"])
def delete_url(url_id):
    try:
        url = URL.get_by_id(url_id)
        url.delete_instance()
        return jsonify({"message": "URL deleted"}), 200
    except URL.DoesNotExist:
        return jsonify({"error": "URL not found"}), 404
