apt-update
apt install nfs-kernel-server
mkdir -p /var/nfs
chown -R nobody:nogroup /var/nfs
echo "/var/nfs     127.0.0.1(rw,sync,no_subtree_check)" > /etc/exports
exportfs -a
systemctl restart nfs-kernel-server