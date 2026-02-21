# README

## Local Development Setup

```bash
bundle install
rails db:drop db:create db:migrate db:seed
rails s
```

## Credentials and Master Key

Master Key and other secrets are in personal notes (not in this repo).

To edit credentials:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

## File Uploads

All uploads go through the API (`PUT /api/v1/asset_files/upload/:file_key`). The request body is streamed directly to S3 — no temp file is written to disk. The API responds only after S3 confirms completion.

- **Small files** (< 200MB): single `put_object` to S3
- **Large files** (≥ 200MB): S3 multipart upload in 100MB chunks

Peak memory usage is ~100MB (one chunk at a time). Disk usage is minimal — Rack/Puma may buffer the request body internally for very large uploads, but no second copy is made.

The Caddy reverse proxy is configured with a 4h timeout to support very large file uploads. No background threads or progress polling are needed.

## Deploy to DigitalOcean Droplet

The app is deployed as a Docker container on a DigitalOcean Droplet. This allows us to configure long HTTP timeouts (4h) needed for large file proxy uploads, which is not possible on App Platform.

**Credentials needed** (stored in personal notes):

- Droplet IP and SSH password
- `RAILS_MASTER_KEY` (also in `config/master.key`)
- `DATABASE_URL` (VPC connection string from DO Managed Database)

### Droplet Specs

- **OS**: Ubuntu 22.04 LTS x64
- **Size**: 4GB RAM / 2 vCPU (needed for large file buffering during proxy uploads)
- **Region**: Same as the Managed Database (e.g. Frankfurt FRA1) — allows VPC network connection to the database
- **Authentication**: Password or SSH key

### First-time Droplet Setup

```bash
# SSH into the Droplet
ssh root@YOUR_DROPLET_IP

# Enable automatic security patches (set and forget)
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Caddy (handles SSL automatically via Let's Encrypt)
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install -y caddy

# Clone the repo and build the Docker image
cd /opt
git clone https://github.com/schneikai/squidbox-api.git
cd squidbox-api
docker build -t squidbox-api .

# Store credentials in an env file (do this once — values come from personal notes)
mkdir -p /etc/squidbox
cat > /etc/squidbox/env <<EOF
RAILS_ENV=production
RAILS_MASTER_KEY=YOUR_RAILS_MASTER_KEY
DATABASE_URL=YOUR_VPC_DATABASE_URL
EOF
chmod 600 /etc/squidbox/env

# Run the container
docker run -d \
  --name squidbox-api \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file /etc/squidbox/env \
  squidbox-api

# Configure Caddy for SSL
nano /etc/caddy/Caddyfile
```

Replace the Caddyfile contents with:

```
YOUR_DOMAIN {
    reverse_proxy localhost:3000 {
        transport http {
            read_timeout 4h
            write_timeout 4h
        }
    }
}
```

```bash
systemctl restart caddy

# Verify the app is running
curl https://YOUR_DOMAIN/up
# Should return a green HTML page (200 OK)
```

### Database Access

The Droplet must be in the **Trusted Sources** list of the DO Managed Database:

- Go to DO Dashboard → Databases → your database → Network Access tab
- Add the Droplet as a trusted source

Use the **VPC network** connection string (not public) since the Droplet and database are in the same DO region.

### Deploying Updates

```bash
ssh root@YOUR_DROPLET_IP
cd /opt/squidbox-api
git pull
docker build -t squidbox-api .
docker stop squidbox-api && docker rm squidbox-api
docker run -d \
  --name squidbox-api \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file /etc/squidbox/env \
  squidbox-api
```

### Debugging

```bash
# View recent logs
docker logs squidbox-api --tail 50

# Follow logs in real time
docker logs squidbox-api -f

# Check if the container is running
docker ps -a

# Open a Rails console inside the container
docker exec -it squidbox-api ./bin/rails c

# Check the health endpoint
curl https://YOUR_DOMAIN/up
# Should return a green HTML page (200 OK)
```

### Creating an Admin User (first time only)

```bash
docker exec -it squidbox-api ./bin/rails c
```

```ruby
password = SecureRandom.hex(10)
AdminUser.create(email: 'admin@example.com', password: password, password_confirmation: password)
puts "Admin created with password: #{password}"
```

## Previous Deployment: DigitalOcean App Platform

The app was previously deployed on App Platform but was migrated to a Droplet because App Platform's load balancer has a hard HTTP timeout that cannot be configured, which killed large file proxy uploads before they could complete.
