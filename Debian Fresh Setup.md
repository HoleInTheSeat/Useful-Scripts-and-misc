## If Using ventoy, Boot in UEFI mode (grub 2)

* Change Passwords if needed:
```
passwd
su -
passwd
```
* Permit Root Login via ssh public key auth:
```
sed -i -E 's/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
```
* Update System:
```
apt update && apt upgrade -y
```
* Install Tmux and Sudo:
```
apt install sudo tmux -y
usermod -aG sudo <user>
```
* Set TTY Banner:
```
printf "Debian GNU/Linux 12\n%s\n" "$(ls /sys/class/net | grep -Ev '^(lo|docker|veth|br|vmnet|virbr|wl)' | awk '{printf "         \\4{%s}\n", $1}')" > /etc/issue
```
* Set SSH banner and MOTD:
```
printf "This\nis\na\nbanner" > /etc/ssh/banner
```
* Check for updates again:
```
apt update && apt upgrade -y
```
* [Optional] Disable AppArmor:
```
systemctl stop apparmor
systemctl disable apparmor
nano /etc/default/grub
	add apparmor=0 in the "" on GRUB_CMDLINE_LINUX_DEFAULT=
	Example: GRUB_CMDLINE_LINUX_DEFAULT="quiet splash apparmor=0"
update-grub
```
* [Optional] Disable Resolveconf:
```
systemctl stop resolvconf
systemctl disable resolvconf
apt remove resolvconf
reboot now
```
* [Optional] Install kernel development package:
```
apt install linux-headers-$(uname -r) -y
```