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
        shell_exec('sudo /home/wcr7/dwupdate/updateclient.sh >> /tmp/dwupdate.log 2>&1');
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
