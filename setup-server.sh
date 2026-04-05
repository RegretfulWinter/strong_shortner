#!/bin/bash
set -e

echo "🚀 开始部署 URL Shortener..."

# 安装 Docker
echo "📦 安装 Docker..."
apt-get update -qq
apt-get install -y -qq docker.io docker-compose-plugin git curl
systemctl enable docker --now

# 创建目录
echo "📁 创建项目目录..."
mkdir -p /var/www/url-shortener
cd /var/www/url-shortener

# 克隆代码
echo "⬇️  克隆 GitHub 仓库..."
if [ ! -d ".git" ]; then
    git clone https://github.com/RegretfulWinter/strong_shortner.git .
fi

# 生成随机密码
echo "🔐 生成环境变量..."
DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
GRAFANA_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

cat > .env << EOF
DATABASE_NAME=hackathon_db
DATABASE_USER=postgres
DATABASE_PASSWORD=$DB_PASS
DATABASE_HOST=postgres
DATABASE_PORT=5432
REDIS_HOST=redis
REDIS_PORT=6379
FLASK_ENV=production
SECRET_KEY=$SECRET
GRAFANA_PASSWORD=$GRAFANA_PASS
EOF

echo ""
echo "✅ 环境变量已创建！"
echo "   数据库密码: $DB_PASS"
echo "   Grafana密码: $GRAFANA_PASS"
echo ""

# 启动服务
echo "🐳 启动 Docker 容器..."
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

# 等待数据库
echo "⏳ 等待数据库启动..."
sleep 15

# 初始化数据库
echo "🗄️  初始化数据库..."
docker compose -f docker-compose.prod.yml exec -T app python init_db.py || true

# 显示状态
echo ""
echo "📊 容器状态:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo "🎉 部署完成！"
echo ""
echo "🌐 访问地址: http://$(curl -s ifconfig.me)/health"
echo "📈 Grafana: http://$(curl -s ifconfig.me):3000 (admin/$GRAFANA_PASS)"
echo ""
echo "⚠️  请保存上面的密码！"
