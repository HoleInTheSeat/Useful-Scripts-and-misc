# [ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh](ACME-LETSENCRYPT-CLOUDFLARE_DNS.sh)
You must have your cloudflare API token somewhere on your machine

To get started, You need to manually create the desired certificat with the CertBot before Hand with something similar to the following
`certbot certonly --dns-cloudflare --dns-cloudflare-credentials /path/to/cloudflare.ini --dns-cloudflare-propagation-seconds 120 --email itrecords@wcr7.org --agree-tos -d packetfence.domain.com -d portal.domain.com`
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
0 0 * * 0 /path/to/script
```
