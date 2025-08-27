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
    * ```sudo echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill, /usr/bin/apt, /usr/bin/dpkg, /bin/rm, /bin/cp, /bin/sed, /sbin/reboot, /usr/bin/gnome-screenshot, /home/$USER/dwupdate/updateclient.sh" | sudo tee -a /etc/sudoers > /dev/null```
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
8. Create Management webpage

    *   ```sudo rm /etc/nginx/sites-enabled/default
        sudo ln -s /etc/nginx/sites-available/mgmt /etc/nginx/sites-enabled/default
        sudo nginx -t
        sudo systemctl reload nginx
        nano /var/www/mgmt/index.php
        ```
    *   Paste this in, making sure to change <USER> to the username of who will be running the dw client
        ```
        <?php
        // Disable caching
        header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
        header("Cache-Control: post-check=0, pre-check=0", false);
        header("Pragma: no-cache");

        $screenshotFile = 'screenshot.png';
        $timestamp = file_exists($screenshotFile) ? filemtime($screenshotFile) : time();

        // Handle POST actions
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (isset($_POST['reboot'])) {
                // Reboot the system
                shell_exec('sudo reboot');
                header("Location: " . $_SERVER['PHP_SELF']);
                exit;
            } elseif (isset($_POST['updateclient'])) {
                // Run update client script
                shell_exec('sudo /home/<USER>/dwupdate/updateclient.sh >> /tmp/dwupdate.log 2>&1');
                header("Location: " . $_SERVER['PHP_SELF']);
                exit;
            }
        }
        ?>
        <!DOCTYPE html>
        <html>
        <head>
            <title><?= gethostname() ?> - System Control</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    text-align: center;
                    padding: 40px;
                    background-color: black;
                    color: white;
                }
                button {
                    padding: 10px 20px;
                    font-size: 16px;
                    margin: 10px;
                    background-color: gray;
                    color: white;
                    border: none;
                    cursor: pointer;
                }
                button:hover {
                    background-color: darkgray;
                }
                img {
                    max-width: 80%;
                    margin-top: 20px;
                    border: 1px solid #ccc;
                }
                #rebooting {
                    display: none;
                    font-size: 22px;
                    color: orange;
                    margin-top: 40px;
                }
                form.inline {
                    display: inline-block;
                    margin: 0 10px;
                }
            </style>
        </head>
        <body>

            <h1><?= gethostname() ?> - System Control Panel</h1>

            <div id="controls">
                <form method="POST" onsubmit="return handleReboot();" class="inline">
                    <button type="submit" name="reboot">Reboot System</button>
                </form>

                <form method="POST" onsubmit="return handleReboot();" class="inline">
                    <button type="submit" name="updateclient">Update Client</button>
                </form>
            </div>

            <a href="screenshot.png" target="_blank">
                <img id="screenshot" src="screenshot.png?ts=<?= $timestamp ?>" alt="Screenshot">
            </a>

            <div id="rebooting">🔁 Rebooting, please wait for the system to come back online...</div>

            <script>
                function handleReboot() {
                    localStorage.setItem('rebooting', 'true'); // Mark as rebooting
                    showRebootMessage();
                    return true; // Submit the form
                }

                function showRebootMessage() {
                    document.getElementById('controls').style.display = 'none';
                    document.getElementById('screenshot').style.display = 'none';
                    document.getElementById('rebooting').style.display = 'block';
                    checkServer();
                }

                function checkServer() {
                    const interval = setInterval(() => {
                        fetch(window.location.href, { cache: 'no-store' })
                            .then(res => {
                                if (res.status === 200) {
                                    clearInterval(interval);
                                    localStorage.removeItem('rebooting');
                                    location.reload();
                                }
                            })
                            .catch(() => {
                                // Server still down, keep checking
                            });
                    }, 5000);
                }

                // On load, check if reboot is in progress
                if (localStorage.getItem('rebooting') === 'true') {
                    showRebootMessage();
                }

                // Screenshot auto-refresh
                let lastTimestamp = <?= $timestamp ?>;
                setInterval(() => {
                    fetch('screenshot.png', { method: 'HEAD' }).then(response => {
                        const newTimestamp = new Date(response.headers.get('Last-Modified')).getTime() / 1000;
                        if (newTimestamp > lastTimestamp) {
                            location.reload();
                        }
                    });
                }, 5000);
            </script>

        <?php
        // Get installed DW Spectrum client version
        $installed_version = trim(shell_exec('dpkg-query -W -f=\'${Version}\' digitalwatchdog-client 2>/dev/null'));
        if (!$installed_version) {
            $installed_version = 'Not installed';
        }
        ?>
        <h2>Installed DW Spectrum Client Version: <?= htmlspecialchars($installed_version) ?></h2>

        </body>
        </html>
        ```
