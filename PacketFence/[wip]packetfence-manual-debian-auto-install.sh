passwd
su -
passwd
echo cd /usr/local/pf >> /root/.bashrc
printf " ______________________________________________\n|                                              |\n|   Property of Webb City R7 School District   |\n|                                              |\n|  Unauthorized access is strictly Prohibited  |\n|                                              |\n ----------------------------------------------\n    Debian GNU/Linux 12\n%s\n" "$(ls /sys/class/net | grep -Ev '^(lo|docker|veth|br|vmnet|virbr|wl)' | awk '{printf "         \\4{%s}\n", $1}')" > /etc/issue
sed -i '/^deb cdrom:/ s/^/#/' /etc/apt/sources.list
apt update && apt upgrade -y
apt install sudo tmux -y
usermod -aG sudo pf
printf " ______________________________________________\n|                                              |\n|   Property of Webb City R7 School District   |\n|                                              |\n|  Unauthorized access is strictly Prohibited  |\n|                                              |\n ----------------------------------------------\n" > /etc/ssh/banner
sed -i 's|^#Banner none|Banner /etc/ssh/banner|' /etc/ssh/sshd_config
systemctl stop apparmor
systemctl disable apparmor
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="quiet"|GRUB_CMDLINE_LINUX_DEFAULT="quiet apparmor=0"|' /etc/default/grub
update-grub
systemctl stop resolvconf
systemctl disable resolvconf
apt remove resolvconf
apt update && apt upgrade -y
ssh-keygen -t ed25519 -C "$USER@$HOSTNAME" -f "$HOME/.ssh/id_ed25519" -N "" -q
cat "$HOME/.ssh/id_ed25519.pub"
reboot now

echo [pub key] >> /root/.ssh/authorized_keys

/usr/local/pf/bin/pfcmd fixpermissions
/usr/local/pf/bin/pfcmd pfconfig clear_backend
systemctl restart packetfence-config
/usr/local/pf/bin/pfcmd configreload hard
/usr/local/pf/bin/pfcmd service pf restart