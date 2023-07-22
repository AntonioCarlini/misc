#!/bin/bash
set -x trace

borg --version

BACKUP_AREAS="/var/lib/automysqlbackup"
BACKUP_AREAS="${BACKUP_AREAS} /var/lib/mediawiki*"

borg list /mnt/Antonio/Backups/borg/pi44gb

echo "$(date +"%Y-%m-%d %H:%M:%S"): Starting backup of automysqlbackup and mediawiki tree: ${BACKUP_AREAS}"
borg create /mnt/Antonio/Backups/borg/pi44gb::pi44gb-full-`date "+%Y%m%d%H%M"` ${BACKUP_AREAS}  --stats --list --filter=AME  --show-rc
echo "$(date +"%Y-%m-%d %H:%M:%S"): Backup completed"
