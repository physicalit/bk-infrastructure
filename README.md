# Backup Script

This script is a backup script that backs up Docker containers, volumes, and directories using the restic backup tool. The script has several error-handling and logging functions, and it checks for the existence of certain directories and packages.

## Requirements
- The script requires restic, jq and docker to be installed on the system.
- The script assumes that the /backup directory is mounted and is present on the system
- The script requires a password file named "pass.txt" to be present in the same directory as the script for restic

## Usage
```
/backup.sh [retention_value]
```
- retention_value: The number of backups to retain

## Functionality
- The script will check if /backup is mounted and if restic, jq, and docker are installed. If any of these are not present, the script will exit with an error
- The script will check if restic is configured by checking if /backup/restic-repo directory exists. If it doesn't, the script will exit with an error
- The script will backup all running containers and save them to the /backup/container directory with the current date
- The script will backup all volumes that are mounted in the running containers
- The script will backup /mnt and if /share and /cloud exists on the system, it will backup those directories as well.
- The script will retain the specified number of backups and delete older backups
- The script will log all actions in backup.log file

## Note
- The script uses the `rm -rf` command to delete backups that are older than the specified retention period. Be sure to test this script thoroughly before using it in a production environment, and make sure that you understand the implications of using the `rm -rf` command.
