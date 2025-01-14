#!/bin/bash

# Check if domain name is passed as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

# Assign domain from argument
DOMAIN="$1"

# Renew LetsEncrypt Certs
certbot renew --quiet
sleep 120

# Variables for file paths
PRIVATE_KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
RSA_PRIVATE_KEY_PATH="/usr/local/pf/conf/ssl/server.key"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/cert.pem"
CHAIN_PATH="/etc/letsencrypt/live/$DOMAIN/chain.pem"
COMBINED_CERT_PATH="/usr/local/pf/conf/ssl/server.crt"
COMBINED_CERT_FULLCHAIN_PATH="/usr/local/pf/conf/ssl/server.pem"

# Check if the necessary files exist
if [ ! -f "$PRIVATE_KEY_PATH" ] || [ ! -f "$CERT_PATH" ] || [ ! -f "$CHAIN_PATH" ]; then
    echo "Error: One or more necessary files are missing for domain $DOMAIN."
    exit 1
fi

# Convert the private key to RSA format and save it to the new location
openssl rsa -in "$PRIVATE_KEY_PATH" -out "$RSA_PRIVATE_KEY_PATH"
if [ $? -ne 0 ]; then
    echo "Error converting private key to RSA format."
    exit 1
fi
echo "Private key converted to RSA format and saved to $RSA_PRIVATE_KEY_PATH"

# Combine cert.pem and chain.pem into server.crt with a blank line between them
cat "$CERT_PATH" > "$COMBINED_CERT_PATH"
echo "" >> "$COMBINED_CERT_PATH"
cat "$CHAIN_PATH" >> "$COMBINED_CERT_PATH"
if [ $? -ne 0 ]; then
    echo "Error combining cert.pem and chain.pem."
    exit 1
fi
echo "Certificate and chain combined into $COMBINED_CERT_PATH"

# Append the RSA private key to the combined certificate file with a blank line in between
cat "$COMBINED_CERT_PATH" > server.pem
echo "" >> "$COMBINED_CERT_FULLCHAIN_PATH"
cat "$RSA_PRIVATE_KEY_PATH" >> "$COMBINED_CERT_FULLCHAIN_PATH"
if [ $? -ne 0 ]; then
    echo "Error appending private key to the certificate file."
    exit 1
fi
echo "Private key appended to the certificate file."

# Set file permissions
chown pf:pf server.pem server.crt server.key && chmod 664 server.pem server.crt server.key

# Restart the packetfence services
/usr/local/pf/bin/pfcmd service haproxy-admin restart
/usr/local/pf/bin/pfcmd service haproxy-portal restart
if [ $? -ne 0 ]; then
    echo "Error restarting services."
    exit 1
fi
echo "Services restarted successfully."
