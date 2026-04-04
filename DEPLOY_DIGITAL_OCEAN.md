# Deploy to Digital Ocean - Complete Guide

## Prerequisites

- Digital Ocean account
- Domain name (optional but recommended)
- GitHub repository: `https://github.com/RegretfulWinter/strong_shortner`

---

## Step 1: Create Droplet

### 1.1 Login to Digital Ocean

Go to https://cloud.digitalocean.com

### 1.2 Create New Droplet

**Choose an image:**
- Click "Marketplace" tab
- Search for "Docker"
- Select **"Docker 24.0.7 on Ubuntu 22.04"** (or latest)

**Choose a plan:**
- **Basic** (Shared CPU)
- **Regular SSD**
- **$12/month** (2 GB RAM / 1 CPU) - minimum for this project
  - For production: $24/month (4 GB RAM)

**Choose a datacenter region:**
- Select closest to your users (e.g., New York, San Francisco, London)

**Authentication:**
- Select **"SSH Key"**
- If you don't have one, click "New SSH Key" and follow instructions

**Final Settings:**
- Hostname: `url-shortener-prod`
- Click **"Create Droplet"**

### 1.3 Note the IP Address

After creation, you'll see your droplet with an IP like:
```
192.168.1.100  (example)
```

**Save this IP!** You'll need it for GitHub Secrets.

---

## Step 2: Initial Server Setup

### 2.1 SSH into Server

```bash
ssh root@YOUR_DROPLET_IP
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
# Install UFW
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

Click "New repository secret" and add:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `DO_HOST` | `192.168.1.100` | Your Droplet IP |
| `DO_USER` | `root` | SSH username |
| `DO_SSH_KEY` | (paste private key) | SSH private key |

**Get SSH Private Key:**
```bash
# On your local machine
cat ~/.ssh/id_rsa
```

Paste the entire content including:
```
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

---

## Step 7: Test Automatic Deployment

### 7.1 Make a Test Change Locally

```bash
# On your local machine
cd PE-Hackathon-Template-2026

# Make a small change
echo "# Deployed to Digital Ocean" >> README.md

git add README.md
git commit -m "docs: add deployment note"
git push origin main
```

### 7.2 Watch GitHub Actions

Go to:
```
https://github.com/RegretfulWinter/strong_shortner/actions
```

You should see:
1. ✅ Test job runs
2. ✅ Docker Build job runs
3. ✅ Deploy job runs
4. ✅ Deployed to Digital Ocean

### 7.3 Verify on Server

```bash
# SSH to server
ssh root@YOUR_DROPLET_IP

# Check logs
cd /var/www/url-shortener
docker compose -f docker-compose.prod.yml logs -f app

# Test endpoint
curl http://localhost:80/health
```

---

## Step 8: Domain Configuration (Optional)

### 8.1 Point Domain to Droplet

In your domain registrar (GoDaddy, Namecheap, etc.):

**Create A Record:**
```
Type: A
Name: @
Value: YOUR_DROPLET_IP
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

Update `docker-compose.prod.yml` to use your domain:
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
http://YOUR_DROPLET_IP:3000
```

Login:
- Username: `admin`
- Password: (from .env GRAFANA_PASSWORD)

### 9.2 Access Prometheus

```
http://YOUR_DROPLET_IP:9090
```

### 9.3 Configure Alerts

Edit `monitoring/alertmanager.yml` with your Discord webhook:
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

# Add swap
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

**Your URL Shortener is now live on Digital Ocean! 🚀**
