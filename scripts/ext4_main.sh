#!/bin/bash
# Main function for Filebench.
set -ex

source scripts/run_all.sh || { echo "Run in the project root directory."; exit 1;}

MOUNT_PATH="/mnt/ext4"

# Set nvme device path.
# DEV_PATH="/dev/nvme2n1"
#
# Or, get it automatically. nvme-cli is required. (sudo apt install nvme-cli)
DEV_PATH="$(sudo nvme list | grep "SAMSUNG MZPLJ3T2HBJR-00007" | xargs | cut -d " " -f 1)"
echo Device path: "$DEV_PATH"

# Set total journal size.
# TOTAL_JOURNAL_SIZE=5120 # 5 GB
TOTAL_JOURNAL_SIZE=$((38 * 1024)) # 38 GB

############# Overriding configurations.
# NUM_THREADS="1 4 8 16"

dropCache() {
	{ echo 3 | sudo tee /proc/sys/vm/drop_caches; } &>/dev/null
	sleep 10
}

flushCache() {
	dropCache
}

umountFS() {
	sudo umount $MOUNT_PATH || true
}

configMultiThread() {
	# Set nthread.
	sed -i "/set \$nthreads=*/c\set \$nthreads=${NUM_THREAD}" $WORKLOAD
}

###### File system specific main function. Should be declared.
runFileSystemSpecific() {
	echo "Ext4 main function."

	# dump file system configs.
	sudo dumpe2fs -h $DEV_PATH > ${OUT_FILE}.fsconf

	# dump workload.
	echo $WORKLOAD > ${OUT_FILE}.wkld
	cat $WORKLOAD >> ${OUT_FILE}.wkld

	CMD="$PERF_PREFIX sudo $PINNING filebench -f $WORKLOAD"

	# Print command.
	echo Command: "$CMD" | tee ${OUT_FILE}.out

	# Execute
	$CMD | tee -a ${OUT_FILE}.out
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# fixCPUFreq

	umountFS

	### Run data=journal mode
	DIR="$MOUNT_PATH/ext4_journal"

	# Configure and mount file system.
	sudo mke2fs -t ext4 -J size=$TOTAL_JOURNAL_SIZE -F -G 1 $DEV_PATH
	sudo mount -t ext4 -o data=journal $DEV_PATH $MOUNT_PATH
	sudo chown -R $USER:$USER $MOUNT_PATH
	mkdir -p $DIR

	loopFilebench

	umountFS

	# Run data=ordered mode
	DIR="$MOUNT_PATH/ext4_ordered"
	sudo mke2fs -t ext4 -J size=$TOTAL_JOURNAL_SIZE -F -G 1 $DEV_PATH
	sudo mount -t ext4 $DEV_PATH $MOUNT_PATH
	sudo chown -R $USER:$USER $MOUNT_PATH
	mkdir -p $DIR

	loopFilebench

	umountFS

	echo "Output files are in 'results' directory."
fi
