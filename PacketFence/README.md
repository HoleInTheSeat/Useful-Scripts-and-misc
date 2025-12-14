# [ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh](ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh)
Install the required Packages
Here is what that would look like with a debian based OS:
```
sudo apt install certbot python3-certbot-dns-cloudflare
```
To get started, download the script to your desired directory
```
wget https://raw.githubusercontent.com/HoleInTheSeat/Useful-Scripts-and-misc/refs/heads/main/PacketFence/ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh
```
Give the script Execute Permissions:
```
chmod +x ./ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh
```
where `cloudflare.ini` is a file containg your API token in the following format:
```
dns_cloudflare_api_token = <your token>
```
You'll need to manually create the desired certificat with the CertBot before Hand with something similar to the following
```
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /path/to/cloudflare.ini --dns-cloudflare-propagation-seconds 120 --email <email> --agree-tos --key-type rsa -d packetfence.domain.com -d portal.domain.com --deploy-hook /path/to/script
```
cloudflare has documentation on how to get an api token [here](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
Its not recommended to use a global api key

Ideally, you would create a cron job to run this script on a desired interval
Something like:
```
0 0 * * 0 certbot renew --cert-name <certname> --deploy-hook "/path/to/script"
```
You can get a list of certnames with
```
certbot certificates
```
EXAMPLE:
```
echo "0 0 * * 0 certbot renew --cert-name packetfence.domain.com --deploy-hook "/path/to/cert" " >> /etc/cron.d/packetfence
```
You can view the logs with
```
less +G /var/log/letsencrypt/letsencrypt.log
```
