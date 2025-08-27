* Common Issues:
  * File permission Issues:
    ```
    /usr/local/pf/bin/pfcmd fixpermissions
    ```
  * Schema Issue:
    ```
    FATAL - The PacketFence database schema version 'XX.X' does not match the current *minor* installed version 'XX.X'
    Please refer to the UPGRADE guide on how to complete an upgrade of PacketFence
    ```
    * Solution: 
      
      Upgrade Schema Versions in order using Provided SQL Files
      ```
      mysql -u root -p -v pf < /usr/local/pf/db/upgrade-<current_schema_version>-<next_schema_version>.sql
      # Reload and restart config and service after finishing upgrades:
      /usr/local/pf/bin/pfcmd pfconfig clear_backend
	  /usr/local/pf/bin/pfcmd configreload hard
	  /usr/local/pf/bin/pfcmd service pf restart
      ```
  * MariaBackup was not successful when using backup-and-maintenance.sh
	* Solution:
      
      Verify the issue via logs
      ```
      less /usr/local/pf/logs/innobackup.log
	  ```
      If it is a permissions issue, run the following
      ```
      # Enter DB
      mysql -u root -p
      # Set Perms
	  GRANT PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'pf'@'localhost';
	  GRANT PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'pf'@'%';
	  # Flush Privileges
      FLUSH PRIVILEGES;
      ```
  * Duplicate Key Issue
    ```
    ERROR 1062 (23000) at line 72: Duplicate entry '' for key 'person_psk'
	```
      * Solution
        ```
        mysql -u root -p
	    use pf;
	    UPDATE person SET psk = NULL WHERE psk = '';
	    ```	  
---
### After importing on a fresh install, you may need to to do the following via the webgui
* Re-setup AD
* Fix network Interfaces
---
### Backups:
* Running an RSYNC to pull from /root/backup is a very easy way to have backups of good exports. I reccomend, not deleting to match source
* Using Mariadb-Backup can help to prevent locking tables and causing slow downs.
```
apt install mariadb-backup
```
---