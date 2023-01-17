#!/bin/bash

# Logging function
log() {
    echo "$(date +"%Y-%m-%d %T") - $1" >> restore.log
}

# Error handling function
handle_error() {
    log "Error: $1. Exiting script."
    exit 1
}

log "Starting restore script"

# First, check if the /backup NFS mount point is mounted correctly
if mount | grep -q '/backup'; then
    log "/backup is mounted correctly"
else
    handle_error "/backup is not mounted correctly"
fi

# Check if required packages are installed:
if command -v docker > /dev/null && command -v restic > /dev/null; then
    log "All required packages are installed."
else
    handle_error "One or more required packages are not installed"
fi

# Check if restic is configured
if [ ! -d "/backup/restic-repo" ]; then
    handle_error "Restic is not configured. Please configure restic and try again"
fi

# Get list of available backup dates
BACKUP_DATES=$(ls -l /backup/container | grep -v ^l | awk '{print $9}')

if [ -z "$BACKUP_DATES" ]; then
    handle_error "No backup dates found."
else
    echo "Select a date to restore:"
    select DATE in $BACKUP_DATES; do
        if [ -n "$DATE" ]; then
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

# Get list of backed up containers for selected date
CONTAINERS=$(ls -l /backup/container/$DATE | grep -v ^l | awk '{print $9}' | awk -F '-' '{print $1}')

if [ -z "$CONTAINERS" ]; then
    handle_error "No backed up containers found for the selected date."
else
    echo "Select a container to restore:"
    select CONTAINER in $CONTAINERS; do
        if [ -n "$CONTAINER" ]; then
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

# Create volumes corresponding to the container
docker inspect --format='{{range .Mounts}}{{.Name}} {{end}}' $CONTAINER | xargs -n1 docker volume create

# Restore volumes data from restic repository
docker inspect --format='{{range .Mounts}}{{.Source}} {{end}}' $CONTAINER | xargs -n1 restic -r /backup/restic-repo --password-file ./pass.txt restore latest

# Start container
docker run --name $CONTAINER -v $(docker inspect --format='{{range .Mounts}}{{.Name}}:{{.Source}} {{end}}' $CONTAINER) $CONTAINER
