# Backup crontab every minute (if changes were made) by adding the following line to crontab file under root user
( `sudo su` to change to root )

Create Backup Directory
```
mkdir /var/spool/cron/backups
```

Create first backup
```
cp /var/spool/cron/crontabs/$USER /var/spool/cron/backups/$USER
```

Add the following to crontab by running `crontab -e`
```
# backup root crontab
* * * * * cmp --silent /var/spool/cron/crontabs/$USER /var/spool/cron/backups/$USER && exit || cp -a /var/spool/cron/backups/$USER "/var/spool/cron/backups/$USER.$(date '+%Y-%m-%d')" && cp -a /var/spool/cron/crontabs/$USER "/var/spool/cron/backups/$USER"
```

Reload Cron
```
sudo service cron reload
```
