# Docker Compose Deployment for nostr-rs-relay

This repository includes Docker Compose configuration files to make it easy to deploy nostr-rs-relay on an Ubuntu server with Caddy as a reverse proxy.

## Quick Setup

For a quick automated setup on a fresh Ubuntu server, you can use the included deployment script:

```bash
sudo ./deploy.sh
```

This script will:
1. Install Docker, Docker Compose, and Caddy
2. Create a dedicated user for running the application
3. Set up the necessary directories and configuration files
4. Configure Caddy as a reverse proxy with automatic HTTPS
5. Build and start the nostr-rs-relay container

## Manual Setup

For manual setup, follow the instructions in [DEPLOY.md](DEPLOY.md).

## Files Included

- `docker-compose.yml` - Docker Compose configuration for running nostr-rs-relay
- `Caddyfile.example` - Example Caddy configuration for reverse proxy
- `DEPLOY.md` - Detailed deployment instructions
- `deploy.sh` - Automated deployment script

## Key Features

- **Automatic Restarts**: The application is configured to restart automatically if it crashes or if the server reboots.
- **Reverse Proxy**: Works seamlessly with Caddy for SSL termination and reverse proxying.
- **Websocket Support**: Properly configured for Nostr's WebSocket connections.
- **Security**: Includes recommended security headers and configurations.
- **Persistence**: Database files are stored in a volume for data persistence.

## Configuration

The main configuration file for nostr-rs-relay is `config.toml`. You should edit this file to customize your relay:

1. Update `relay_url` to your domain (e.g., `wss://your-relay.example.com`)
2. Set your relay `name` and `description`
3. Configure any other settings as needed (rate limits, etc.)

Refer to the comments in the `config.toml` file for detailed information on each setting.

## Maintenance

### Logs

View application logs:
```bash
docker-compose logs -f nostr-relay
```

View Caddy logs:
```bash
sudo tail -f /var/log/caddy/nostr-relay.log
```

### Updates

To update the application:

```bash
# Pull the latest changes
git pull

# Rebuild and restart the container
docker-compose down
docker-compose up -d --build
```

### Backups

It's recommended to regularly backup the database:

```bash
# Stop the container
docker-compose down

# Backup the data directory
tar -czvf nostr-backup-$(date +%Y%m%d).tar.gz data/ config.toml

# Restart the container
docker-compose up -d
```

## Additional Resources

- [nostr-rs-relay GitHub Repository](https://github.com/andotherstuff/nostr-rs-relay)
- [Nostr Protocol Specification](https://github.com/nostr-protocol/nips)
