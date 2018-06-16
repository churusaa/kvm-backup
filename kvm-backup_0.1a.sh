#!/bin/bash

# Set the language to English so virsh does it's output
# in English as well
# LANG=en_US

# Set the path where backups will be stored
# No trailing slash expected here
BACKUP_ROOT=/mnt/backups

# Define the script name, this is used with systemd-cat to
# identify this script in the journald output
SCRIPTNAME=kvm-backup

# List domains
DOMAINS=$(virsh list | tail -n +3 | awk '{print $2}')

# Loop over the domains found above and do the
# actual backup

for DOMAIN in $DOMAINS; do

	echo "Starting backup for $DOMAIN on $(date +'%d-%m-%Y %H:%M:%S')" | systemd-cat -t $SCRIPTNAME

	# Generate the backup folder URI - this is something you should
	# change/check
	BACKUPFOLDER=$BACKUP_ROOT/$DOMAIN/$(date +%d-%m-%Y)
	mkdir -p $BACKUPFOLDER

	# Get the target disk
	TARGETS=$(virsh domblklist $DOMAIN --details | grep disk | awk '{print $3}')

	# Get the image page
	IMAGES=$(virsh domblklist $DOMAIN --details | grep disk | awk '{print $4}')

	# Create the snapshot/disk specification
	DISKSPEC=""

	for TARGET in $TARGETS; do
		DISKSPEC="$DISKSPEC --diskspec $TARGET,snapshot=external"
	done

	virsh snapshot-create-as --domain $DOMAIN --name "backup-$DOMAIN" --no-metadata --atomic --disk-only $DISKSPEC 1>/dev/null 2>&1

	if [ $? -ne 0 ]; then
		echo "Failed to create snapshot for $DOMAIN" | systemd-cat -t $SCRIPTNAME
		exit 1
	fi

	# Copy disk image
	for IMAGE in $IMAGES; do
		NAME=$(basename $IMAGE)
                # cp $IMAGE $BACKUPFOLDER/$NAME
                # pv $IMAGE > $BACKUPFOLDER/$NAME
        if hash rsync 2>/dev/null; then
        	rsync -ah --progress $IMAGE $BACKUPFOLDER/$NAME
        else
        	echo "Transmitting backup of $DOMAIN with cp. Install rsync to enable"
        	echo "statistics, estimated time, and progress readout during transfer"
        	cp $IMAGE $BACKUPFOLDER/$NAME
        fi
	done

	# Compress disk image at target
	if hash pv 2>/dev/null; then
		for IMAGE in $IMAGES; do
			NAME=$(basename $IMAGE)
			echo "Concatenating and compressing backup of $DOMAIN in place with tar and gzip"
			tar cf - $BACKUPFOLDER/ -P | pv -s $(du -sb $BACKUPFOLDER/ | awk '{print $1}') | gzip > $BACKUPFOLDER/$NAME.tar.gz
		done
	else
		echo "Please install pv to get status updates and progress during compression"
		tar -cvzf $BACKUPFOLDER/$NAME.tgz /$BACKUPFOLDER/$NAME
	fi

	# Merge changes back
	BACKUPIMAGES=$(virsh domblklist $DOMAIN --details | grep disk | awk '{print $4}')

	for TARGET in $TARGETS; do
		virsh blockcommit $DOMAIN $TARGET --active --pivot 1>/dev/null 2>&1

		if [ $? -ne 0 ]; then
			echo "Could not merge changes for disk of $TARGET of $DOMAIN. VM may be in invalid state." | systemd-cat -t $SCRIPTNAME
			exit 1
		fi
	done

	# Cleanup left over backups
	for BACKUP in $BACKUPIMAGES; do
		rm -f $BACKUP
	done

	# Dump the configuration information.
	virsh dumpxml $DOMAIN > $BACKUPFOLDER/$DOMAIN.xml 1>/dev/null 2>&1

	echo "Finished backup of $DOMAIN at $(date +'%d-%m-%Y %H:%M:%S')" | systemd-cat -t $SCRIPTNAME
done

exit 0
