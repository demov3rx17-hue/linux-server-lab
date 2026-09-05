#!/usr/bin/env bash
# Run as root. Creates redacted, portfolio-safe verification reports in /tmp.
set -Eeuo pipefail

OUT_DIR="${1:-/tmp/linux-server-lab-evidence}"
install -d -m 0755 "$OUT_DIR"

{
  id admin
  id operator
  id developer
  printf '\n[operator sudo policy]\n'
  sudo -l -U operator
  printf '\n[isolated directories]\n'
  stat -c '%A %U:%G %n' /srv/admin /srv/operator /srv/developer
} >"$OUT_DIR/01-users-and-access.log" 2>&1

{
  sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowusers) '
} >"$OUT_DIR/02-ssh-policy.log" 2>&1

{
  ufw status numbered
  printf '\n[listening sockets]\n'
  ss -tulpn
} >"$OUT_DIR/03-firewall-and-ports.log" 2>&1

{
  systemctl is-active nginx
  nginx -t
  curl --noproxy '*' -sS -I http://127.0.0.1/
  curl --noproxy '*' -sS http://127.0.0.1/
} >"$OUT_DIR/04-nginx.log" 2>&1

{
  systemctl status server-monitor.service --no-pager || true
  systemctl list-timers server-monitor.timer --no-pager
  tail -n 20 /var/log/linux-server-lab/monitor.log
} >"$OUT_DIR/05-monitoring.log" 2>&1

{
  /usr/local/sbin/backup.sh
  tail -n 20 /var/log/linux-server-lab/backup.log
  ls -lh /var/backups/linux-server-lab/
  crontab -l
} >"$OUT_DIR/06-backup-and-cron.log" 2>&1

chown -R admin:admin "$OUT_DIR"
find "$OUT_DIR" -type f -exec chmod 0644 {} +
