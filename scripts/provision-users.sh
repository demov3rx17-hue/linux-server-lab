#!/usr/bin/env bash
# Run once as root on Debian: sudo bash provision-users.sh
set -Eeuo pipefail

for group in admins operators developers; do
  getent group "$group" >/dev/null || groupadd "$group"
done

create_user() {
  local name="$1" group="$2"
  id "$name" >/dev/null 2>&1 || useradd -m -s /bin/bash -G "$group" "$name"
  usermod -aG "$group" "$name"
}

create_user admin admins
create_user operator operators
create_user developer developers

# Administrative access is granted to the admins group.
usermod -aG sudo admin

# Isolated working directories demonstrate group-based access control.
install -d -o admin -g admins -m 0770 /srv/admin
install -d -o operator -g operators -m 0770 /srv/operator
install -d -o developer -g developers -m 0770 /srv/developer

# Operators have narrowly scoped service-management rights; developers have none.
cat >/etc/sudoers.d/linux-server-lab-operators <<'EOF'
%operators ALL=(root) NOPASSWD: /usr/bin/systemctl status nginx, /usr/bin/systemctl restart nginx, /usr/bin/systemctl status server-monitor.service, /usr/bin/journalctl -u nginx, /usr/bin/journalctl -u server-monitor.service
EOF
chmod 0440 /etc/sudoers.d/linux-server-lab-operators
visudo -cf /etc/sudoers.d/linux-server-lab-operators

printf '%s\n' 'Users and access directories configured successfully.'
