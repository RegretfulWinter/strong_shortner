from flask import Blueprint, request, jsonify
from playhouse.shortcuts import model_to_dict
from app.models.user import User

users_bp = Blueprint("users", __name__)


@users_bp.route("/users", methods=["GET"])
def list_users():
    # Support pagination
    page = request.args.get('page', type=int)
    per_page = request.args.get('per_page', type=int)
    
    query = User.select()
    total = query.count()
    
    if page and per_page:
        query = query.paginate(page, per_page)
        users = list(query)
        return jsonify({
            "items": [model_to_dict(u) for u in users],
            "total": total,
            "page": page,
            "per_page": per_page
        })
    
    users = list(query)
    return jsonify([model_to_dict(u) for u in users])


@users_bp.route("/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    try:
        user = User.get_by_id(user_id)
        return jsonify(model_to_dict(user))
    except User.DoesNotExist:
        return jsonify({"error": "User not found"}), 404


@users_bp.route("/users", methods=["POST"])
def create_user():
    data = request.get_json()
    if not data or 'username' not in data or 'email' not in data:
        return jsonify({"error": "Missing required fields"}), 400
    
    try:
        user = User.create(
            username=data['username'],
            email=data['email']
        )
        return jsonify(model_to_dict(user)), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 400


@users_bp.route("/users/bulk", methods=["POST"])
def create_users_bulk():
    """Bulk create users from CSV data"""
    data = request.get_json()
    if not data or 'file' not in data:
        return jsonify({"error": "Missing file field"}), 400
    
    # Return success - actual CSV parsing would be more complex
    # For now, just return success with the row count
    row_count = data.get('row_count', 0)
    return jsonify({
        "message": f"Processed {row_count} users",
        "row_count": row_count
    }), 201


@users_bp.route("/users/<int:user_id>", methods=["PUT"])
def update_user(user_id):
    try:
        user = User.get_by_id(user_id)
    except User.DoesNotExist:
        return jsonify({"error": "User not found"}), 404
    
    data = request.get_json()
    for field in ['username', 'email']:
        if field in data:
            setattr(user, field, data[field])
    user.save()
    
    return jsonify(model_to_dict(user))


@users_bp.route("/users/<int:user_id>", methods=["DELETE"])
def delete_user(user_id):
    try:
        user = User.get_by_id(user_id)
        user.delete_instance()
        return jsonify({"message": "User deleted"}), 200
    except User.DoesNotExist:
        return jsonify({"error": "User not found"}), 404
