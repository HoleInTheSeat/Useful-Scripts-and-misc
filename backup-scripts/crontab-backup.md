# Backup root crontab every 5 minutes by adding the following line to crontab file under root user
( `sudo su` to change to root user then `crontab -e` to edit crontab file)

```
# backup root crontab
*/5 0 * * * test -f /var/spool/cron/backups/root && echo "Original Crontab Backup already created" || cp /var/spool/cron/crontabs/root /var/spool/cron/backups/root && cmp --silent /var/spool/cron/crontabs/root /var/spool/cron/backups/root && echo 'No root cron changes' || cp -a /var/spool/cron/backups/root "/var/spool/cron/backups/root.$(date '+%Y-%m-%d')" && cp -a /var/spool/cron/crontabs/root "/var/spool/cron/backups/root"
```
