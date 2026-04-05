#!/bin/bash
# 在服务器上执行修复

cd /var/www/url-shortener

# 修复 urls.py - 使用 recurse=False
sed -i 's/d = model_to_dict(url)/d = model_to_dict(url, recurse=False)/g' app/routes/urls.py

# 修复 users.py - 添加 imported 字段
sed -i 's/"row_count": len(created),/"imported": len(created),\n                "row_count": len(created),/' app/routes/users.py

# 提交并重启
git add -A
git commit -m "fix: use recurse=False and add imported field"
docker compose down
docker compose up -d --build

# 检查状态
sleep 10
curl -s http://localhost:80/users | head -c 200
