# Deploy to Digital Ocean

## Prerequisites

- Digital Ocean account
- Domain name (optional but recommended)
- GitHub repository with this code

## Step 1: Create Droplet

1. Login to Digital Ocean
2. Create Droplet:
   - Image: Docker 20+ on Ubuntu 22.04
   - Plan: Basic, 2GB RAM / 1 CPU (minimum)
   - Datacenter: Choose closest to your users
   - Authentication: SSH Key
   - Hostname: url-shortener

3. Note the IP address

## Step 2: Configure GitHub Secrets

In your GitHub repository:

Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret | Value |
|--------|-------|
| `DO_HOST` | Your droplet IP |
| `DO_USER` | root (or your user) |
| `DO_SSH_KEY` | Your private SSH key |

## Step 3: Initial Server Setup

SSH into your droplet:

```bash
ssh root@YOUR_DROPLET_IP

# Create app directory
mkdir -p /var/www/url-shortener
cd /var/www/url-shortener

# Clone repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git .

# Create environment file
cat > .env << 'EOF'
DB_NAME=hackathon_db
DB_USER=postgres
DB_PASSWORD=YOUR_SECURE_PASSWORD
SECRET_KEY=YOUR_SECRET_KEY
GRAFANA_PASSWORD=YOUR_GRAFANA_PASSWORD
EOF

# Start services
docker-compose -f docker-compose.prod.yml up -d

# Initialize database
docker-compose -f docker-compose.prod.yml exec app python init_db.py
```

## Step 4: Setup SSL (HTTPS)

```bash
# Install certbot
docker run -it --rm \
  -v /var/www/url-shortener/certbot/conf:/etc/letsencrypt \
  -v /var/www/url-shortener/certbot/www:/var/www/certbot \
  -p 80:80 \
  certbot/certbot certonly --standalone \
  -d yourdomain.com
```

## Step 5: Configure GitHub Actions

Push to main branch will automatically deploy:

```bash
git add .
git commit -m "Add deployment config"
git push origin main
```

## Verification

```bash
# Check services
docker-compose -f docker-compose.prod.yml ps

# Check logs
docker-compose -f docker-compose.prod.yml logs -f app

# Test API
curl http://YOUR_DROPLET_IP/health
```

## Troubleshooting

### Port already in use
```bash
# Check what's using port 80
sudo netstat -tlnp | grep :80

# Stop conflicting service
sudo systemctl stop nginx  # or apache2
```

### Database connection failed
```bash
# Check postgres is running
docker-compose -f docker-compose.prod.yml ps postgres

# Check logs
docker-compose -f docker-compose.prod.yml logs postgres
```

### Out of memory
Upgrade droplet to 4GB RAM for better performance.
