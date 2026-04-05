#!/bin/bash
# 彻底重置并部署

cd /var/www/url-shortener

# 停止所有服务
docker compose down -v

# 删除所有相关卷
docker volume prune -f

# 拉取最新代码
git pull origin main

# 重新构建并启动
docker compose up -d --build

# 等待服务启动
sleep 10

# 查看日志
docker compose logs -f app
