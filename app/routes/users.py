from flask import Blueprint, request, jsonify
from playhouse.shortcuts import model_to_dict
from app.models.user import User

users_bp = Blueprint("users", __name__)


@users_bp.route("/users", methods=["GET"])
def list_users():
    users = User.select()
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
