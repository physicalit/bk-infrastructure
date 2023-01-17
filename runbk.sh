#!/bin/bash

# Logging function
log() {
    echo "$(date +"%Y-%m-%d %T") - $1" >> backup.log
}

# Error handling function
handle_error() {
    log "Error: $1. Exiting script."
    cat ./backup.log | mail -s "Backup Log - $DATE" giumsytec@gmail.com
    exit 1
}

log "Starting backup script"

# First, check if the /backup NFS mount point is mounted correctly
if mount | grep -q '/backup'; then
    log "/backup is mounted correctly"
else
    handle_error "/backup is not mounted correctly"
fi

# Check if required packages are installed:
if command -v docker > /dev/null && command -v restic > /dev/null && command -v jq > /dev/null && command -v mailx > /dev/null; then
    log "All required packages are installed."
else
    handle_error "One or more required packages are not installed"
fi

# Check if restic is configured
if [ ! -d "/backup/restic-repo" ]; then
    handle_error "Restic is not configured. Please configure restic and try again"
fi

# Get retention value
if [ -z "$1" ]; then
    handle_error "Please provide retention value"
else
    RETENTION=$1
fi

# Backup docker volumes - no binds
docker ps -q | xargs -I {} sh -c 'CONTAINER_NAME=$(docker inspect --format "{{.Name}}" {} | cut -c 2-) && docker stop {} && docker inspect --format "{{json .Mounts}}" {} | jq -r ".[] | select(.Type == \"volume\") | .Source" | xargs -I {} sh -c "docker run --rm -v {}:{} -v $(pwd)/pass.txt:/password-file -v /backup/restic-repo:/repo restic/restic -r /repo --host $CONTAINER_NAME --password-file /password-file backup {}" && docker start {}'

# Get current date
DATE=$(date +"%Y-%m-%d")

# Create backup directory with current date
BACKUP_DIR=/backup/container/$DATE
mkdir -p $BACKUP_DIR

# Get list of running containers
CONTAINERS=$(docker ps --format "{{.Names}}")

# Loop through list of running containers
for CONTAINER in $CONTAINERS; do
    # Commit container to image
    IMAGE_NAME=$(echo $CONTAINER | tr '[:upper:]' '[:lower:]'):$DATE
    docker commit $CONTAINER $IMAGE_NAME

    # Save image to backup directory
    docker save $IMAGE_NAME -o $BACKUP_DIR/$IMAGE_NAME-image.tar

    # Export container's filesystem to backup directory
    docker export $CONTAINER -o $BACKUP_DIR/$CONTAINER-export.tar
done

# Retention of backups
BACKUP_COUNT=$(ls -ld /backup/container/*  | grep -v ^l | wc -l)
BACKUP_COUNT=$((BACKUP_COUNT-$RETENTION))
if [ $BACKUP_COUNT -gt 0 ]; then
    ls -t /backup/container | tail -n $BACKUP_COUNT | xargs rm -rf -- /backup/container/
fi
# backup /mnt
restic -r /backup/restic-repo --password-file ./pass.txt --verbose backup  /mnt

# backup if /share exists
if [ -d "/share" ]; then
restic -r /backup/restic-repo --password-file ./pass.txt --verbose backup --exclude /share/Videos --exclude /share/moto --exclude /share/mc --exclude /share/Downloads --exclude /share/Video /share
fi

# Backup if /cloud exists
if [ -d "/cloud" ]; then
restic -r /backup/restic-repo --password-file ./pass.txt --verbose backup /cloud
fi

restic forget --keep-last $RETENTION -r /backup/restic-repo/

log "Backup script finished successfully"

cat ./backup.log | mail -s "Backup Log - $DATE" giumsytec@gmail.com
