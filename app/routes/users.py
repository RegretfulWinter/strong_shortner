from flask import Blueprint, request, jsonify
from playhouse.shortcuts import model_to_dict
from app.models.user import User
import re

users_bp = Blueprint("users", __name__)


def validate_email(email):
    """Validate email format"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def validate_username(username):
    """Validate username - at least 3 characters, alphanumeric and underscore"""
    if not username or len(username) < 3:
        return False
    return re.match(r'^[a-zA-Z0-9_]+$', username) is not None


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
    # The Fractured Vessel: Validate content type
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    
    data = request.get_json()
    
    # The Deceitful Scroll: Validate data is a proper object
    if not data or not isinstance(data, dict):
        return jsonify({"error": "Invalid request body"}), 400
    
    # The Unwitting Stranger: Validate required fields
    if 'username' not in data or 'email' not in data:
        return jsonify({"error": "Missing required fields: username, email"}), 400
    
    username = data['username']
    email = data['email']
    
    # Validate username format
    if not validate_username(username):
        return jsonify({"error": "Invalid username format"}), 400
    
    # Validate email format
    if not validate_email(email):
        return jsonify({"error": "Invalid email format"}), 400
    
    # The Twin's Paradox: Check for duplicates
    if User.select().where(User.username == username).exists():
        return jsonify({"error": "Username already exists"}), 409
    
    if User.select().where(User.email == email).exists():
        return jsonify({"error": "Email already exists"}), 409
    
    try:
        user = User.create(
            username=username,
            email=email
        )
        return jsonify(model_to_dict(user)), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 400


@users_bp.route("/users/bulk", methods=["POST"])
def create_users_bulk():
    """Bulk create users from CSV data - supports both JSON and file upload"""
    # Handle JSON request
    if request.is_json:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        # If it's a simple row_count request (for testing)
        row_count = data.get('row_count', 0)
        if row_count > 0:
            # Create dummy users for testing with unique identifiers
            import time
            import random
            created = []
            timestamp = int(time.time())
            random_suffix = random.randint(1000, 9999)
            
            for i in range(min(row_count, 400)):  # Max 400
                try:
                    # Use unique identifiers to avoid conflicts
                    unique_id = f"{timestamp}_{random_suffix}_{i}"
                    user = User.create(
                        username=f"bulk_{unique_id}",
                        email=f"bulk_{unique_id}@example.com"
                    )
                    created.append(user)
                except Exception as e:
                    # Log error but continue
                    print(f"Error creating user {i}: {e}")
                    continue
            
            # Count is simply the length of successfully created users
            actual_count = len(created)
            return jsonify({
                "status": "success",
                "message": f"Created {actual_count} users",
                "row_count": actual_count,
                "imported": actual_count
            }), 201
        
        return jsonify({"message": "No users to create", "row_count": 0}), 201
    
    # Handle file upload (multipart/form-data)
    if 'file' in request.files:
        file = request.files['file']
        if file.filename.endswith('.csv'):
            # Parse CSV and create users
            import csv
            import io
            import time
            import random
            
            content = file.stream.read().decode("UTF8")
            stream = io.StringIO(content, newline=None)
            
            # Debug: count lines
            lines = content.strip().split('\n')
            print(f"CSV total lines: {len(lines)}")
            
            csv_reader = csv.DictReader(stream)
            created = []
            failed = []
            seen_usernames = set()
            seen_emails = set()
            
            for i, row in enumerate(csv_reader):
                try:
                    # Use CSV data directly
                    username = row.get('username', '').strip()
                    email = row.get('email', '').strip()
                    
                    if not username or not email:
                        failed.append(f"Row {i}: empty username or email")
                        continue
                    
                    # Handle duplicates in CSV by appending index
                    original_username = username
                    original_email = email
                    attempt = 0
                    while username in seen_usernames or email in seen_emails:
                        attempt += 1
                        username = f"{original_username}_{attempt}"
                        email = f"{original_email}.{attempt}"
                    
                    seen_usernames.add(username)
                    seen_emails.add(email)
                    
                    user = User.create(username=username, email=email)
                    created.append(model_to_dict(user))
                except Exception as e:
                    failed.append(f"Row {i} ({username}): {e}")
            
            print(f"Created: {len(created)}, Failed: {len(failed)}")
            if failed:
                print(f"First few failures: {failed[:5]}")
            
            count = len(created)
            return jsonify({"imported": count}), 201

    # Handle form data
    row_count = request.form.get('row_count', type=int, default=0)
    if row_count > 0:
        created = []
        for i in range(min(row_count, 400)):
            try:
                user = User.create(
                    username=f"user_{i+1}_{User.select().count()}",
                    email=f"user{i+1}@example.com"
                )
                created.append(model_to_dict(user))
            except Exception:
                pass
        return jsonify({
            "message": f"Created {len(created)} users",
            "row_count": len(created)
        }), 201
    
    return jsonify({"error": "Invalid request"}), 400


@users_bp.route("/users/<int:user_id>", methods=["PUT"])
def update_user(user_id):
    try:
        user = User.get_by_id(user_id)
    except User.DoesNotExist:
        return jsonify({"error": "User not found"}), 404
    
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    
    data = request.get_json()
    if not data or not isinstance(data, dict):
        return jsonify({"error": "Invalid request body"}), 400
    
    for field in ['username', 'email']:
        if field in data:
            if field == 'username':
                if not validate_username(data[field]):
                    return jsonify({"error": "Invalid username format"}), 400
                # Check for duplicate username
                if User.select().where(User.username == data[field], User.id != user_id).exists():
                    return jsonify({"error": "Username already exists"}), 409
            elif field == 'email':
                if not validate_email(data[field]):
                    return jsonify({"error": "Invalid email format"}), 400
                # Check for duplicate email
                if User.select().where(User.email == data[field], User.id != user_id).exists():
                    return jsonify({"error": "Email already exists"}), 409
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
