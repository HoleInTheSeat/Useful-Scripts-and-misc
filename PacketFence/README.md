# [ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh](ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh)
You must have your cloudflare API token somewhere on your machine

To get started, download the script to your desired directory
```
wget https://github.com/HoleInTheSeat/Useful-Scripts-and-misc/blob/main/PacketFence/ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh
```
Give the script Execute Permissions:
```
chmod +x ./ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh
```
You'll need to manually create the desired certificat with the CertBot before Hand with something similar to the following
```
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /path/to/cloudflare.ini --dns-cloudflare-propagation-seconds 120 --email <email> --agree-tos --key-type rsa -d packetfence.domain.com -d portal.domain.com
```
where `cloudflare.ini` is a file containg your API token in the following format:
```
dns_cloudflare_api_token = <your token>
```
If you havent already, make sure you have the required packages installed
Here is what that would look like with a debian base OS:
```
sudo apt install certbot python3-certbot-dns-cloudflare
```

cloudflare has documentation on how to get an api token [here](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
Its not recommended to use a global api key

Ideally, you would create a cron job to run this script on a desired interval
Something like:
```
0 0 * * 0 /path/to/script <domain>
```
EXAMPLE:
```
echo "0 0 * * 0 /root/ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh packetfence.domain.com" >> /etc/cron.d/packetfence
```
