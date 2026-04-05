#!/bin/bash
# 重置数据库脚本

cd /var/www/url-shortener

# 拉取最新代码
git pull origin main

# 停止并删除容器（保留数据卷）
docker compose down

# 删除数据库数据卷（清理旧表结构）
docker volume rm url-shortener_postgres_data 2>/dev/null || true

# 重新构建并启动
docker compose up -d

# 等待数据库启动
sleep 10

# 初始化数据库（新表结构会自动创建，种子数据会自动插入）
docker compose exec app python -c "
from app import create_app
app = create_app()
print('Database initialized with seed data!')
"

# 查看日志
docker compose logs -f app
