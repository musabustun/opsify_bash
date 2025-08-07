#!/bin/bash

# Change to the project directory
cd "$HOME/go-whatsapp-web-multidevice"

# Ask for domain
echo "Please enter your domain (e.g., musabustun.xyz or https://musabustun.xyz):"
read domain

# Add https:// if not present
if [[ ! $domain =~ ^https?:// ]]; then
    domain="https://$domain"
fi

# Format webhook URLs
webhook_urls="${domain}/webhook/opsify,${domain}/webhook-test/opsify"

# Copy .env.example to .env if it exists
if [ -f "src/.env.example" ]; then
    cp src/.env.example src/.env
    echo ".env.example copied to .env"
else
    echo "Error: src/.env.example not found"
    exit 1
fi

# Comment out line 13 in .env
sed -i.bak '13s/^/#/' src/.env

# Update line 5 with opsify:opsify
sed -i.bak '5s/.*$/BASIC_AUTH_CREDENTIALS=opsify:opsify/' src/.env

# Update line 15 with webhook URLs
sed -i.bak "15s|.*|WEBHOOK_URLS=$webhook_urls|" src/.env

# Update AppOs in settings.go
sed -i.bak 's/AppOs\s*=\s*"[^"]*"/AppOs                  = "OpsifyServer"/' src/config/settings.go

# Remove backup files
rm -f src/.env.bak src/config/settings.go.bak

echo "Setup completed successfully!"
