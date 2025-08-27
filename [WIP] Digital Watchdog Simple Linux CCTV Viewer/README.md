# Setting Up a simple cctv montior for digital watchdog using Ubuntu Linux
1. Get a fresh install of Ubuntu Desktop Installed, and log in as the user that the DW Spectrum client will run as. (if using ssh, ensure you SSH as the user)
2. Disable Wayland

    * ```sudo nano /etc/gdm3/custom.conf```
    * add the line: ```WaylandEnable=false```
3. Install gnome-screenshot and set alias

    * ```sudo apt install gnome-screenshot```
    * ```echo 'alias screenshot="gnome-screenshot -f ./screenshot.png && sudo cp /home/$USER/screenshot.png /var/www/mgmt/screenshot.png && sudo chmod 644 /var/www/mgmt/screenshot.png"' >> ~/.bashrc```
    * ```source ~/.bashrc```
4. Set Sudoers Permissions

    * ```sudo echo "$USER ALL=(ALL) NOPASSWD: /bin/cp /home/$USER/screenshot.png /var/www/mgmt/screenshot.png, /bin/chmod 644 /var/www/mgmt/screenshot.png" | sudo tee -a /etc/sudoers > /dev/null```
    * ```sudo echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill, /usr/bin/apt, /usr/bin/dpkg, /bin/rm, /bin/cp, /bin/sed, /sbin/reboot, /usr/bin/gnome-screenshot, /usr/local/bin/updateclient.sh" | sudo tee -a /etc/sudoers > /dev/null```
5. Setup Cron Screenshot Job (must be run by user with DE that is running DW Client)

    * ```( sudo crontab -u $USER -l; echo "* * * * * DISPLAY=:0 XAUTHORITY=/home/$USER/.Xauthority sudo -u $USER /usr/bin/gnome-screenshot -f /home/$USER/screenshot.png && cp /home/$USER/screenshot.png /var/www/mgmt/screenshot.png" ) | sudo crontab -u $USER -```
    * ```sudo service cron reload```
6. Install NGINX and PHP

    * ```sudo apt update```
    * ```sudo apt install nginx php-fpm php-cli php-mbstring php-xml php-curl php-gd -y```
    * ```sudo systemctl enable --now nginx php8.3-fpm```
    * ```sudo touch /etc/nginx/sites-available/mgmt```
7. Configure NGINX

    *   ```
        echo 'server {
            listen 80;
            server_name localhost;

            root /var/www/mgmt;
            index index.php index.html;

            location / {
                try_files $uri $uri/ =404;
            }

            location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php8.3-fpm.sock;
            }

            location ~ /\.ht {
                deny all;
            }
        }' | sudo tee /etc/nginx/sites-available/mgmt > /dev/null
        ```
    *   ```
        sudo rm /etc/nginx/sites-enabled/default
        sudo ln -s /etc/nginx/sites-available/mgmt /etc/nginx/sites-enabled/default
        sudo nginx -t
        sudo systemctl reload nginx
        ```
8. Create update script
   * ```
     sudo wget https://raw.githubusercontent.com/HoleInTheSeat/Useful-Scripts-and-misc/refs/heads/main/%5BWIP%5D%20Digital%20Watchdog%20Simple%20Linux%20CCTV%20Viewer/update_client.sh > /usr/local/bin/updateclient.sh
     sudo chmod 755 /usr/local/bin/updateclient.sh
     ```

10. Download Management webpage

    *   ```
        wget https://raw.githubusercontent.com/HoleInTheSeat/Useful-Scripts-and-misc/refs/heads/main/%5BWIP%5D%20Digital%20Watchdog%20Simple%20Linux%20CCTV%20Viewer/simple%20management%20webgui/index.php > /var/www/mgmt/index.php
        sudo chown -R root:www-data /var/www/mgmt
        sudo chmod -R 755 /var/www/mgmt
        ```
