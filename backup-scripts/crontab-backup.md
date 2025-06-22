# Backup crontab every minute (if changes were made) by adding the following line to crontab file under root user
( `sudo su` to change to root )

Create Backup Directory
```
mkdir /var/spool/cron/backups
```

Create first backup
```
cp /var/spool/cron/crontabs/$(whoami) /var/spool/cron/backups/$(whoami)
```

Add the following to crontab by running `crontab -e`
```
# backup root crontab
* * * * * cmp --silent /var/spool/cron/crontabs/$(whoami) /var/spool/cron/backups/$(whoami) && exit || cp -a /var/spool/cron/backups/$(whoami) /var/spool/cron/backups/$(whoami).$(date '+%Y-%m-%d-%H-%M-%S') && cp -a /var/spool/cron/crontabs/$LOGNAME /var/spool/cron/backups/$LOGNAME
```
```
sudo service cron reload
```

A back up should be created on the very next minute. After that, the job will check every minute if the crontab has changed, if it has, it will create a new backup.
