#!/bin/bash

exec > ~/ACME-LETSENCRYPT-CLOUDFLARE_DNS.log 2>&1

# Check if domain name is passed as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

# Assign domain from argument
DOMAIN="$1"

# Variables for file paths
PRIVATE_KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
RSA_PRIVATE_KEY_PATH="/usr/local/pf/conf/ssl/server.key"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/cert.pem"
CHAIN_PATH="/etc/letsencrypt/live/$DOMAIN/chain.pem"
COMBINED_CERT_PATH="/usr/local/pf/conf/ssl/server.crt"
COMBINED_CERT_FULLCHAIN_PATH="/usr/local/pf/conf/ssl/server.pem"
RADIUS_CA="/usr/local/pf/raddb/certs/ca.pem"
RADIUS_PRIVKEY="/usr/local/pf/raddb/certs/server.key"
RADIUS_FULLCHAIN="/usr/local/pf/raddb/certs/server.crt"

## WebGUI
# Check if the necessary files exist
if [ ! -f "$PRIVATE_KEY_PATH" ] || [ ! -f "$CERT_PATH" ] || [ ! -f "$CHAIN_PATH" ]; then
    echo "Error: One or more necessary files are missing for domain $DOMAIN."
    exit 1
fi

# Convert the private key to RSA format and save it to the new location
openssl pkey -in "$PRIVATE_KEY_PATH" -out "$RSA_PRIVATE_KEY_PATH" -traditional
if [ $? -ne 0 ]; then
    echo "Error converting private key to RSA format."
    exit 1
fi
echo "Private key converted to RSA PKCS#1 format and saved to $RSA_PRIVATE_KEY_PATH"

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
cat "$COMBINED_CERT_PATH" > "$COMBINED_CERT_FULLCHAIN_PATH"
echo "" >> "$COMBINED_CERT_FULLCHAIN_PATH"
cat "$RSA_PRIVATE_KEY_PATH" >> "$COMBINED_CERT_FULLCHAIN_PATH"
if [ $? -ne 0 ]; then
    echo "Error appending private key to the certificate file."
    exit 1
fi
echo "Private key appended to the certificate file."

# Set file permissions
chown pf:pf "$RSA_PRIVATE_KEY_PATH" "$COMBINED_CERT_PATH" "$COMBINED_CERT_FULLCHAIN_PATH" && chmod 664 "$RSA_PRIVATE_KEY_PATH" "$COMBINED_CERT_PATH" "$COMBINED_CERT_FULLCHAIN_PATH"

# Restart the packetfence services
/usr/local/pf/bin/pfcmd service haproxy-admin restart
/usr/local/pf/bin/pfcmd service haproxy-portal restart
if [ $? -ne 0 ]; then
    echo "Error restarting services."
    exit 1
fi
echo "WEBGUI restarted successfully."

## Radius Cert
# Copy Intermeidate CA and Privkey
cp /etc/letsencrypt/live/$DOMAIN/chain.pem "$RADIUS_CA"
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem "$RADIUS_PRIVKEY"

# Combine for server.crt
cat "$CERT_PATH" > "$RADIUS_FULLCHAIN"
echo"" >> "$RADIUS_FULLCHAIN"
cat "$CHAIN_PATH" >> "$RADIUS_FULLCHAIN"
echo"" >> "$RADIUS_FULLCHAIN"
curl https://letsencrypt.org/certs/isrgrootx1.pem >> "$RADIUS_FULLCHAIN"

# Restart radiusd
/usr/local/pf/bin/pfcmd service radiusd restart
if [ $? -ne 0 ]; then
    echo "Error restarting services."
    exit 1
fi
echo "Radius Auth restarted successfully."

# Set permissions
chown pf:systemd-coredump "$RADIUS_CA" "$RADIUS_PRIVKEY" && chmod 664 "$RADIUS_CA" "$RADIUS_PRIVKEY"
chown pf:pf "$RADIUS_FULLCHAIN" && chmod 664 "$RADIUS_FULLCHAIN"
