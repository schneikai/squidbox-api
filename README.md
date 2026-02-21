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

## Large File Uploads (>4GB)

Files ≥4GB are currently skipped during sync with a "Skipped large file upload" error. This is a known limitation — see the proxy upload section below for the planned fix.

### Background

- **S3 limit**: Single-PUT uploads are limited to 5GB (hard S3 limit), and reliable uploads require chunked/multipart for large files
- **Expo bug**: Expo's chunked file reading crashes on files >2GB due to a C++ integer overflow (long-standing unresolved bug)
- **Proxy upload**: The API has a proxy upload endpoint (`upload_proxy`) where the app pushes the file to Rails, which then does S3 multipart upload in a background thread. This works but requires a deployment that allows long-running HTTP connections (see Droplet deployment below)

Upload progress tracking requires `Rails.cache`:
- **Production**: Uses `:memory_store` by default (progress tracking works)
- **Development**: Uses `:null_store` by default (no progress tracking, shows "Validating upload..." instead)

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

# Run the container
docker run -d \
  --name squidbox-api \
  --restart unless-stopped \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY=YOUR_RAILS_MASTER_KEY \
  -e DATABASE_URL="YOUR_VPC_DATABASE_URL" \
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
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY=YOUR_RAILS_MASTER_KEY \
  -e DATABASE_URL="YOUR_VPC_DATABASE_URL" \
  squidbox-api
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
