#!/usr/bin/env bash
# Create dated compressed backups, retain the newest BACKUP_KEEP copies, and log all outcomes.
set -Eeuo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/linux-server-lab}"
LOG_FILE="${LOG_FILE:-/var/log/linux-server-lab/backup.log}"
BACKUP_KEEP="${BACKUP_KEEP:-7}"
SOURCES=(/etc/nginx /var/www/site)
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
ARCHIVE="$BACKUP_DIR/site-backup_${TIMESTAMP}.tar.gz"

log() {
  printf '%s | %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE" >&2
}

on_error() {
  local exit_code=$?
  log "ERROR: backup failed (exit code: $exit_code)"
  exit "$exit_code"
}
trap on_error ERR

[[ "$BACKUP_KEEP" =~ ^[1-9][0-9]*$ ]] || { log "ERROR: BACKUP_KEEP must be a positive integer"; exit 2; }
install -d -m 0750 "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

for source in "${SOURCES[@]}"; do
  [[ -d "$source" ]] || { log "ERROR: source directory does not exist: $source"; exit 3; }
done

log "Backup started: $ARCHIVE"
tar -czf "$ARCHIVE" -C / etc/nginx var/www/site
gzip -t "$ARCHIVE"
log "Archive verified: $(du -h "$ARCHIVE" | awk '{print $1}')"

mapfile -t old_archives < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'site-backup_*.tar.gz' -printf '%T@ %p\n' | sort -nr | awk -v keep="$BACKUP_KEEP" 'NR > keep {print $2}')
for old_archive in "${old_archives[@]:-}"; do
  [[ -n "$old_archive" ]] && rm -f -- "$old_archive" && log "Removed expired archive: $old_archive"
done

log "Backup completed successfully"
