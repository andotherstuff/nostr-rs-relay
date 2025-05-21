#!/bin/bash
# nostr-rs-relay deployment script for Ubuntu
# This script automates the deployment process for nostr-rs-relay with Docker Compose and Caddy

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
  echo -e "${GREEN}[+] $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}[!] $1${NC}"
}

print_error() {
  echo -e "${RED}[-] $1${NC}"
}

# Welcome message
echo "======================================================================"
echo "     nostr-rs-relay Deployment Script for Ubuntu with Docker & Caddy  "
echo "======================================================================"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  print_error "Please run this script as root or with sudo"
  exit 1
fi

# Ask for domain name
read -p "Enter your domain name (e.g., relay.example.com): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
  print_error "Domain name cannot be empty"
  exit 1
fi

# Create a normal user for running the application
print_status "Setting up application user..."
APP_USER="nostr"
APP_USER_HOME="/home/$APP_USER"
APP_DIR="$APP_USER_HOME/nostr-relay"

# Check if user exists
if id "$APP_USER" &>/dev/null; then
  print_warning "User $APP_USER already exists"
else
  useradd -m -s /bin/bash $APP_USER
  print_status "Created user $APP_USER"
fi

# Install dependencies
print_status "Installing dependencies..."
apt update
apt upgrade -y
apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release git

# Install Docker
print_status "Installing Docker..."
if command -v docker &>/dev/null; then
  print_warning "Docker already installed"
else
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io
  systemctl enable --now docker

  # Add app user to docker group
  usermod -aG docker $APP_USER
  print_status "Docker installed successfully"
fi

# Docker Compose is now included with Docker
print_status "Checking Docker Compose..."
if docker compose version &>/dev/null; then
  print_status "Docker Compose plugin is available"
else
  print_warning "Docker Compose plugin might not be installed properly. Using 'docker-compose' command instead."
  # Create a simple wrapper script for compatibility
  echo '#!/bin/bash
docker compose "$@"' > /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# Install Caddy
print_status "Installing Caddy..."
if command -v caddy &>/dev/null; then
  print_warning "Caddy already installed"
else
  apt install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  apt update
  apt install -y caddy
  print_status "Caddy installed successfully"
fi

# Setup application directory structure
print_status "Setting up application directory..."
mkdir -p $APP_DIR/data
chown -R $APP_USER:$APP_USER $APP_DIR

# Create or download required files
print_status "Creating configuration files..."

# Create docker-compose.yml
cat > $APP_DIR/docker-compose.yml << EOL
version: '3'

services:
  nostr-relay:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nostr-relay
    restart: always
    volumes:
      - ./data:/usr/src/app/db
      - ./config.toml:/usr/src/app/config.toml:ro
    ports:
      # Only expose to localhost - Caddy will proxy to this
      - "127.0.0.1:8080:8080"
    environment:
      - TZ=UTC
      - RUST_LOG=warn,nostr_rs_relay=info
    user: "$APP_USER:$APP_USER" # Use the app user
    networks:
      - nostr-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  nostr-network:
    driver: bridge
EOL

# Create config.toml with basic settings
cat > $APP_DIR/config.toml << EOL
# Nostr-rs-relay configuration

[info]
relay_url = "wss://$DOMAIN_NAME/"
name = "nostr-rs-relay"
description = "A nostr relay running on nostr-rs-relay.\n\nCustomize this with your own info."
pubkey = ""
contact = ""

[database]
data_directory = "."

[network]
address = "0.0.0.0"
port = 8080
remote_ip_header = "x-forwarded-for"

[options]
reject_future_seconds = 1800

[limits]
messages_per_sec = 20
subscriptions_per_min = 10
broadcast_buffer = 16384
event_persist_buffer = 4096
max_event_bytes = 131072
EOL

# Clone the application repository
print_status "Cloning nostr-rs-relay repository..."
cd $APP_DIR
if [ ! -f "$APP_DIR/Dockerfile" ]; then
  git clone https://github.com/andotherstuff/nostr-rs-relay.git temp
  cp temp/Dockerfile $APP_DIR/
  cp temp/LICENSE $APP_DIR/
  cp -r temp/src $APP_DIR/
  cp -r temp/proto $APP_DIR/
  cp temp/build.rs $APP_DIR/
  cp temp/Cargo.toml $APP_DIR/
  cp temp/Cargo.lock $APP_DIR/
  cp temp/rustfmt.toml $APP_DIR/
  rm -rf temp
  print_status "Repository cloned and files copied"
fi

# Create Caddy configuration
print_status "Configuring Caddy..."
cat > /etc/caddy/Caddyfile << EOL
$DOMAIN_NAME {
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
EOL

# Set correct permissions
print_status "Setting permissions..."
chown -R $APP_USER:$APP_USER $APP_DIR
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

# Restart Caddy to apply configuration
print_status "Restarting Caddy..."
systemctl restart caddy

# Start the application
print_status "Starting the application..."
cd $APP_DIR
su - $APP_USER -c "cd $APP_DIR && docker compose up -d --build"

# Final instructions
echo ""
echo "======================================================================"
print_status "Installation completed successfully!"
echo ""
print_status "Your nostr-rs-relay should be accessible at: wss://$DOMAIN_NAME"
echo ""
print_status "Make sure your domain's DNS is pointing to this server's IP address."
print_status "Caddy will automatically obtain and renew SSL certificates for you."
echo ""
print_status "To check the application logs:"
echo "  sudo su - $APP_USER -c 'cd $APP_DIR && docker compose logs -f'"
echo ""
print_status "To check Caddy logs:"
echo "  sudo tail -f /var/log/caddy/nostr-relay.log"
echo "======================================================================"
