# Deploy to Vultr - Complete Guide

## Prerequisites

- Vultr account (已注册且有 credit)
- Domain name (optional but recommended)
- GitHub repository: `https://github.com/RegretfulWinter/strong_shortner`

---

## Step 1: Create VPS Instance

### 1.1 Login to Vultr

Go to https://my.vultr.com

### 1.2 Deploy New Server

点击 "Deploy Server" 按钮

**Choose Server:**
- 选择 **Cloud Compute** (Shared CPU)

**Choose Location:**
- 选择离你用户最近的区域（如：Singapore, Tokyo, Los Angeles 等）

**Choose Image:**
- 点击 **Marketplace Apps** 标签
- 搜索并选择 **Docker** (通常是最新的 Ubuntu + Docker 预装)

**Choose Plan:**
- **Regular Cloud Compute**
- 推荐配置：
  - **$12/month** (2 GB RAM / 1 CPU / 55 GB SSD) - 最低配置
  - **$24/month** (4 GB RAM / 2 CPU / 80 GB SSD) - 生产环境推荐

**Additional Features:**
- 勾选 **Enable IPv6** (可选)
- 勾选 **Enable Auto Backups** (推荐，用于数据安全)

**Server Hostname & Label:**
- Hostname: `url-shortener-prod`
- Label: `url-shortener-prod`

**SSH Keys:**
- 添加你的 SSH Key（如果没有，点击 "Add New" 并按照说明生成）

点击 **Deploy Now**

### 1.3 Note the IP Address

等待服务器部署完成（约 1-2 分钟），你会看到：
```
IP Address: 123.45.67.89  (示例)
```

**保存这个 IP！** 后续配置需要用到。

---

## Step 2: Initial Server Setup

### 2.1 SSH into Server

```bash
ssh root@YOUR_VULTR_IP
```

### 2.2 Update System

```bash
apt-get update && apt-get upgrade -y
```

### 2.3 Create App Directory

```bash
mkdir -p /var/www/url-shortener
cd /var/www/url-shortener
```

### 2.4 Clone Repository

```bash
git clone https://github.com/RegretfulWinter/strong_shortner.git .
```

### 2.5 Create Environment File

```bash
cat > .env << 'EOF'
# Database Configuration
DATABASE_NAME=hackathon_db
DATABASE_USER=postgres
DATABASE_PASSWORD=YOUR_SECURE_PASSWORD_HERE
DATABASE_HOST=postgres
DATABASE_PORT=5432

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Flask Configuration
FLASK_ENV=production
SECRET_KEY=YOUR_RANDOM_SECRET_KEY_HERE

# Grafana Admin Password
GRAFANA_PASSWORD=YOUR_GRAFANA_PASSWORD_HERE
EOF
```

**Generate secure passwords:**
```bash
# Generate random password
openssl rand -base64 32
```

---

## Step 3: Start Services

### 3.1 Start with Docker Compose

```bash
cd /var/www/url-shortener

# Pull latest images
docker compose -f docker-compose.prod.yml pull

# Start all services
docker compose -f docker-compose.prod.yml up -d
```

### 3.2 Initialize Database

```bash
# Wait for postgres to be ready
sleep 10

# Initialize tables
docker compose -f docker-compose.prod.yml exec app python init_db.py

# Import seed data (optional)
docker compose -f docker-compose.prod.yml exec app python import_csv.py seed_data/users.csv seed_data/urls.csv seed_data/events.csv
```

### 3.3 Verify Services

```bash
# Check all containers are running
docker compose -f docker-compose.prod.yml ps

# Check health endpoint
curl http://localhost:80/health

# Expected output: {"status":"ok"}
```

---

## Step 4: Configure Firewall

### 4.1 Setup UFW

```bash
# Install UFW (通常已预装)
apt-get install -y ufw

# Default deny incoming
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow monitoring (optional, restrict to your IP)
# ufw allow from YOUR_OFFICE_IP to any port 3000
# ufw allow from YOUR_OFFICE_IP to any port 9090

# Enable firewall
ufw enable
```

---

## Step 5: Setup SSL (HTTPS)

### 5.1 Install Certbot

```bash
apt-get install -y certbot
```

### 5.2 Get SSL Certificate

```bash
# Stop nginx temporarily
docker compose -f docker-compose.prod.yml stop nginx

# Get certificate (replace with your domain)
certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# Certificates will be saved to:
# /etc/letsencrypt/live/yourdomain.com/
```

### 5.3 Update Docker Compose with SSL

Mount certificates in docker-compose.prod.yml:
```yaml
nginx:
  volumes:
    - ./nginx.prod.conf:/etc/nginx/nginx.conf:ro
    - /etc/letsencrypt:/etc/letsencrypt:ro
```

### 5.4 Setup Auto-Renewal

```bash
# Add to crontab
echo "0 12 * * * certbot renew --quiet && docker compose -f /var/www/url-shortener/docker-compose.prod.yml restart nginx" | crontab -
```

---

## Step 6: Configure GitHub Actions Secrets

### 6.1 Go to GitHub Repository Settings

Navigate to:
```
https://github.com/RegretfulWinter/strong_shortner/settings/secrets/actions
```

### 6.2 Add Repository Secrets

点击 "New repository secret" 添加以下 secrets：

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `VULTR_HOST` | `123.45.67.89` | 你的 Vultr VPS IP |
| `VULTR_USER` | `root` | SSH 用户名 |
| `VULTR_SSH_KEY` | (粘贴私钥内容) | SSH 私钥 |

**获取 SSH Private Key：**
```bash
# 在你的本地机器上
cat ~/.ssh/id_rsa
```

粘贴完整内容，包括：
```
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

---

## Step 7: Test Automatic Deployment

### 7.1 Make a Test Change Locally

```bash
# 在本地机器上
cd PE-Hackathon-Template-2026

# 做一些小改动
echo "# Deployed to Vultr" >> README.md

git add README.md
git commit -m "docs: add deployment note"
git push origin main
```

### 7.2 Watch GitHub Actions

访问：
```
https://github.com/RegretfulWinter/strong_shortner/actions
```

你应该看到：
1. ✅ Test job 运行
2. ✅ Docker Build job 运行
3. ✅ Deploy job 运行
4. ✅ Deployed to Vultr

### 7.3 Verify on Server

```bash
# SSH 到服务器
ssh root@YOUR_VULTR_IP

# 检查日志
cd /var/www/url-shortener
docker compose -f docker-compose.prod.yml logs -f app

# 测试接口
curl http://localhost:80/health
```

---

## Step 8: Domain Configuration (Optional)

### 8.1 Point Domain to Vultr VPS

在你的域名注册商（GoDaddy, Namecheap, Cloudflare 等）处：

**Create A Record:**
```
Type: A
Name: @
Value: YOUR_VULTR_IP
TTL: 3600
```

**Create www CNAME:**
```
Type: CNAME
Name: www
Value: yourdomain.com
TTL: 3600
```

### 8.2 Update Nginx Config

在 `docker-compose.prod.yml` 中使用你的域名：
```yaml
environment:
  - SERVER_NAME=yourdomain.com www.yourdomain.com
```

### 8.3 Restart Services

```bash
docker compose -f docker-compose.prod.yml restart nginx
```

---

## Step 9: Monitoring Setup

### 9.1 Access Grafana

```
http://YOUR_VULTR_IP:3000
```

Login:
- Username: `admin`
- Password: (来自 .env 中的 GRAFANA_PASSWORD)

### 9.2 Access Prometheus

```
http://YOUR_VULTR_IP:9090
```

### 9.3 Configure Alerts

编辑 `monitoring/alertmanager.yml`，添加你的 Discord webhook：
```yaml
receivers:
  - name: 'discord'
    discord_configs:
      - webhook_url: 'YOUR_DISCORD_WEBHOOK_URL'
```

---

## Troubleshooting

### Container fails to start
```bash
# Check logs
docker compose -f docker-compose.prod.yml logs app

# Restart
docker compose -f docker-compose.prod.yml restart
```

### Database connection error
```bash
# Check postgres is running
docker compose -f docker-compose.prod.yml ps postgres

# Check logs
docker compose -f docker-compose.prod.yml logs postgres
```

### Out of memory
```bash
# Check memory usage
free -h

# Add swap (Vultr 小实例可能需要)
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

### Permission denied
```bash
# Fix permissions
chown -R root:root /var/www/url-shortener
chmod -R 755 /var/www/url-shortener
```

---

## Security Checklist

- [ ] Changed default database password
- [ ] Changed Grafana admin password
- [ ] Set strong SECRET_KEY
- [ ] Configured UFW firewall
- [ ] Disabled root login (optional: create deploy user)
- [ ] Enabled SSL/HTTPS
- [ ] Restricted monitoring ports to specific IPs

---

## Next Steps

1. ⭐ Setup domain and SSL
2. ⭐ Configure Discord alerts
3. ⭐ Create Grafana dashboards
4. ⭐ Write Runbook for Incident Response Gold
5. ⭐ Setup log aggregation (optional)

---

**Your URL Shortener is now live on Vultr! 🚀**
