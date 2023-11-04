#!/bin/sh

# run certbot (checks for existing cert and renews if needed)
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /home/packetfence/.secrets/cloudflare.ini -d <Admin WebGUI Domain> -d <Portal Domain> --preferred-challenges dns-01 --non-interactive --expand

# copy in new cert
cat /etc/letsencrypt/live/packetfence.armchairsavages.net/fullchain.pem > /usr/local/pf/conf/ssl/server.crt
cat /etc/letsencrypt/live/packetfence.armchairsavages.net/fullchain.pem > /usr/local/pf/conf/ssl/server.pem
cat /etc/letsencrypt/live/packetfence.armchairsavages.net/privkey.pem >> /usr/local/pf/conf/ssl/server.pem
cat /etc/letsencrypt/live/packetfence.armchairsavages.net/privkey.pem > /usr/local/pf/conf/ssl/server.key

# Restart HAPROXY
/usr/local/pf/bin/pfcmd service haproxy-admin restart
/usr/local/pf/bin/pfcmd service haproxy-portal restart
