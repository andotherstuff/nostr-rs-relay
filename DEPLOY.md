# Deploying nostr-rs-relay with Docker Compose and Caddy

This guide explains how to deploy the nostr-rs-relay application on an Ubuntu server using Docker Compose and Caddy as a reverse proxy.

## Prerequisites

- Ubuntu server (20.04 LTS or newer recommended)
- Docker and Docker Compose installed
- Caddy installed
- A domain name pointing to your server (for TLS)

## Installation Steps

### 1. Install Docker and Docker Compose

```bash
# Update the system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker (which includes Docker Compose as a plugin)
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to the docker group (to run Docker without sudo)
sudo usermod -aG docker $USER

# Apply the group changes to current session
newgrp docker
```

### 2. Install Caddy

```bash
# Install Caddy using their official package
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

### 3. Create Application Directory

```bash
# Create a directory for the application
mkdir -p ~/nostr-relay
cd ~/nostr-relay

# Create data directory for database persistence
mkdir -p data

# Set proper permissions
sudo chown -R 1000:1000 data
```

### 4. Setup Application Configuration

Copy both the docker-compose.yml and config.toml files to your server:

```bash
# Use this command if you have the files locally, or create them on the server
# scp docker-compose.yml config.toml user@your-server:~/nostr-relay/
```

Edit the config.toml file to set your relay's information:

```bash
nano config.toml
```

Update at least these settings:

```toml
[info]
relay_url = "wss://your-relay-domain.com"
name = "Your Nostr Relay Name"
description = "Your relay description here"

[network]
address = "0.0.0.0"
port = 8080
```

### 5. Configure Caddy as Reverse Proxy

Create or edit the Caddyfile:

```bash
sudo nano /etc/caddy/Caddyfile
```

Add the following configuration, replacing `your-relay-domain.com` with your actual domain:

```
your-relay-domain.com {
    # Enable logging
    log {
        output file /var/log/caddy/nostr-relay.log {
            roll_size 10MB
            roll_keep 10
        }
    }
    
    # Reverse proxy to nostr-rs-relay
    reverse_proxy localhost:8080 {
        # WebSocket support
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        
        # Timeouts appropriate for WebSockets
        transport http {
            keepalive 1h
            response_header_timeout 30s
            read_timeout 5s
            write_timeout 10s
            dial_timeout 5s
        }
    }
    
    # Security headers
    header {
        # Enable HTTP Strict Transport Security (HSTS)
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent MIME sniffing
        X-Content-Type-Options "nosniff"
        # Frame options
        X-Frame-Options "SAMEORIGIN"
        # XSS Protection
        X-XSS-Protection "1; mode=block"
        # Referrer Policy
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
```

Reload Caddy to apply the changes:

```bash
sudo systemctl reload caddy
```

### 6. Start the Application

```bash
# Navigate to application directory
cd ~/nostr-relay

# Start the application in the background
docker compose up -d
```

### 7. Verify the Application is Running

```bash
# Check the logs
docker compose logs -f

# Verify the container is running
docker ps
```

## Maintenance

### Updating the Application

```bash
# Pull the latest changes from your Git repository or update your files
cd ~/nostr-relay
git pull  # If you're using git

# Rebuild and restart the container
docker compose down
docker compose up -d --build
```

### Viewing Logs

```bash
# View application logs
docker compose logs -f nostr-relay

# View Caddy logs
sudo tail -f /var/log/caddy/nostr-relay.log
```

### Backup

Backup database and configuration:

```bash
# Stop the container first
docker-compose down

# Backup the data directory
tar -czvf nostr-relay-backup-$(date +%Y%m%d).tar.gz data/ config.toml docker-compose.yml

# Restart the container
docker-compose up -d
```

## Troubleshooting

1. **Container doesn't start**: Check for errors in the logs with `docker-compose logs nostr-relay`
2. **Unable to connect to the relay**: Make sure ports are correctly configured and not blocked by a firewall
3. **WebSocket connection issues**: Ensure proper Caddy configuration for WebSocket forwarding
4. **Permission issues**: Check that the data directory has the correct ownership (1000:1000 or matching your user)

## Security Recommendations

1. **Firewall**: Configure UFW to only allow necessary ports (80, 443 for Caddy)
2. **Regular updates**: Keep your system, Docker, and application updated
3. **Backups**: Regularly backup your database and configuration files
4. **Monitoring**: Set up monitoring for your server and application
5. **Consider rate limiting**: Configure appropriate rate limits in the relay config.toml file