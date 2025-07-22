# Deployment Guide

This guide covers different deployment options for your Phoenix LiveView dashboard application.

## Quick Local Deployment with Docker

### Prerequisites
- Docker and Docker Compose installed
- Your OpenAI API key

### Steps

1. **Copy environment file:**
   ```bash
   cp .env.prod.example .env.prod
   ```

2. **Edit `.env.prod` with your configuration:**
   ```bash
   # Generate a secret key base
   mix phx.gen.secret
   
   # Add to .env.prod:
   SECRET_KEY_BASE=your_generated_secret
   OPENAI_API_KEY=your_openai_api_key
   PHX_HOST=localhost  # or your domain
   ```

3. **Deploy:**
   ```bash
   ./bin/deploy.sh
   ```

4. **Access your app at http://localhost:4000**

## Production Server Deployment Options

### Option 1: VPS/Cloud Server (DigitalOcean, Linode, AWS EC2)

#### Requirements:
- Ubuntu 22.04+ server
- Docker and Docker Compose
- PostgreSQL database (local or managed)
- Domain name (optional but recommended)

#### Setup:

1. **Install Docker on your server:**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **Install Docker Compose:**
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. **Clone your repository:**
   ```bash
   git clone <your-repo-url>
   cd dashboard_gen
   ```

4. **Configure environment:**
   ```bash
   cp .env.prod.example .env.prod
   # Edit .env.prod with your production values
   ```

5. **Deploy:**
   ```bash
   ./bin/deploy.sh
   ```

6. **Set up reverse proxy (recommended):**
   Install nginx and configure SSL with Let's Encrypt

### Option 2: Platform as a Service

#### Fly.io (Recommended)

1. **Install Fly CLI:**
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. **Login and create app:**
   ```bash
   fly auth login
   fly launch
   ```

3. **Set secrets:**
   ```bash
   fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
   fly secrets set OPENAI_API_KEY=your_api_key
   fly secrets set DATABASE_URL=your_database_url
   ```

4. **Deploy:**
   ```bash
   fly deploy
   ```

#### Gigalixir

1. **Install Gigalixir CLI:**
   ```bash
   pip3 install gigalixir
   ```

2. **Create and deploy:**
   ```bash
   gigalixir create
   gigalixir config:set SECRET_KEY_BASE="$(mix phx.gen.secret)"
   gigalixir config:set OPENAI_API_KEY="your_api_key"
   git push gigalixir main
   ```

### Option 3: Container Platforms

#### Google Cloud Run
1. Build and push to Container Registry
2. Deploy to Cloud Run
3. Configure environment variables

#### AWS ECS/Fargate
1. Push image to ECR
2. Create ECS service
3. Configure ALB and environment

## Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `DATABASE_URL` | Yes | PostgreSQL connection string | `postgres://user:pass@host:5432/db` |
| `SECRET_KEY_BASE` | Yes | Phoenix secret (64 chars) | Generate with `mix phx.gen.secret` |
| `OPENAI_API_KEY` | Yes | Your OpenAI API key | `sk-...` |
| `PHX_HOST` | Yes | Your domain/hostname | `yourdomain.com` |
| `PORT` | No | HTTP port (default: 4000) | `4000` |
| `POOL_SIZE` | No | DB pool size (default: 10) | `10` |
| `LOG_LEVEL` | No | Log level (default: info) | `info` |

## Database Setup

### Managed Database (Recommended)
- **AWS RDS PostgreSQL**
- **Google Cloud SQL**
- **DigitalOcean Managed Database**
- **Supabase**

### Self-hosted PostgreSQL
The docker-compose.yml includes PostgreSQL for development/testing.

## SSL/HTTPS Setup

### With Nginx (Recommended)
```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Let's Encrypt with Certbot
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## Monitoring and Maintenance

### Health Checks
The app includes built-in health monitoring accessible at `/health`

### Logs
```bash
# Docker logs
docker-compose logs -f app

# Container logs
docker logs dashboard-gen
```

### Backups
```bash
# Database backup
docker-compose exec db pg_dump -U postgres dashboard_gen_prod > backup.sql

# Restore
docker-compose exec -T db psql -U postgres dashboard_gen_prod < backup.sql
```

### Updates
```bash
# Pull latest code
git pull

# Rebuild and redeploy
./bin/deploy.sh
```

## Troubleshooting

### Common Issues

1. **Secret key base error:**
   - Generate new secret: `mix phx.gen.secret`
   - Ensure it's set in environment

2. **Database connection error:**
   - Check DATABASE_URL format
   - Verify database exists and is accessible
   - Check firewall rules

3. **OpenAI API errors:**
   - Verify API key is correct
   - Check API quota/billing

4. **Asset/static file issues:**
   - Run `mix assets.deploy` before building
   - Check file permissions

### Getting Help
- Check application logs
- Verify environment variables
- Test database connectivity
- Ensure all services are running

## Security Considerations

1. **Use strong SECRET_KEY_BASE**
2. **Keep dependencies updated**
3. **Use HTTPS in production**
4. **Secure database access**
5. **Regular backups**
6. **Monitor for security updates**