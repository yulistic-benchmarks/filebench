#!/bin/bash
# Main function for Filebench.
set -ex

DEVICE_IP="192.168.14.114" # Set DevFS IP address. Need ssh access without password.

if [ -z "$OXBOW_ENV_SOURCED" ]; then
	echo "Do source set_env.sh first."
	exit
fi

source scripts/run_all.sh || { echo "Run in the project root directory."; exit 1;}

MOUNT_PATH="$OXBOW_PREFIX"

# Set nvme device path.
# DEV_PATH="/dev/nvme2n1"
#
# Or, get it automatically. nvme-cli is required. (sudo apt install nvme-cli)
DEV_PATH="$(sudo nvme list | grep "SAMSUNG MZPLJ3T2HBJR-00007" | xargs | cut -d " " -f 1)"
echo Device path: "$DEV_PATH"

############# Overriding configurations.
# NUM_THREADS="1 4 8 16"

initOxbow() {
	# Runninng Daemon as background
	$SECURE_DAEMON/run.sh -b
	sleep 10
	DAEMON_PID=$(pgrep "secure_daemon")
	echo "[OXBOW_MICROBENCH] Daemon runnning PID: $DAEMON_PID"

	sudo mount -t illufs dummy $OXBOW_PREFIX
	echo "[OXBOW_MICROBENCH] mount oxbow FS\n"
	sleep 5
}

killBgOxbow() {
	# Kill Daemon
	echo "[OXBOW_MICROBENCH] Kill secure daemon($DAEMON_PID) and umount Oxbow."
	$SECURE_DAEMON/run.sh -k
	sleep 5

	# sudo kill -9 $DAEMON_PID
	# echo "[OXBOW_MICROBENCH] Exit secure daemon $DAEMON_PID"
	# sleep 5

	# sudo umount $OXBOW_PREFIX
	# echo "[OXBOW_MICROBENCH] umount oxbow FS\n"
	# sleep 5

}

dumpOxbowConfig() {
	if [ -e "${LIBFS}/myconf.sh" ]; then
		echo "$LIBFS/myconf.sh:" >${OUT_FILE}.fsconf
		cat $LIBFS/libfs_conf.sh >>${OUT_FILE}.fsconf
	fi

	echo "$LIBFS/libfs_conf.sh:" >>${OUT_FILE}.fsconf
	cat $LIBFS/libfs_conf.sh >>${OUT_FILE}.fsconf

	if [ -e "${SECURE_DAEMON}/myconf.sh" ]; then
		echo "$SECURE_DAEMON/myconf.sh" >>${OUT_FILE}.fsconf
		cat $SECURE_DAEMON/myconf.sh >>${OUT_FILE}.fsconf
	fi

	echo "$SECURE_DAEMON/secure_daemon_conf.sh:" >>${OUT_FILE}.fsconf
	cat $SECURE_DAEMON/secure_daemon_conf.sh >>${OUT_FILE}.fsconf

	if [ -e "${DEVFS}/myconf.sh" ]; then
		echo "$DEVFS/myconf.sh" >>${OUT_FILE}.fsconf
		cat $DEVFS/myconf.sh >>${OUT_FILE}.fsconf
	fi

	echo "$DEVFS/devfs_conf.sh:" >>${OUT_FILE}.fsconf
	cat $DEVFS/devfs_conf.sh >>${OUT_FILE}.fsconf
}

# Send remote checkpoint signal to DevFS.
checkpoint() {
	sig_nu=$(expr $(kill -l SIGRTMIN) + 1)
	cmd="sudo pkill -${sig_nu} devfs"
	ssh ${DEVICE_IP} $cmd
}

###### File system specific reset function. It is called before each benchmark run. Should be declared.
flushCache() {
	# dropCache
	checkpoint
	killBgOxbow
	initOxbow
}

configMultiThread() {
	# Set nthread.
	sed -i "/set \$nthreads=*/c\set \$nthreads=${NUM_THREAD}" $WORKLOAD
}

###### File system specific main function. Should be declared.
runFileSystemSpecific() {
	echo "Oxbow main function."

	# dump file system configs.
	dumpOxbowConfig

	# dump workload.
	echo $WORKLOAD > ${OUT_FILE}.wkld
	cat $WORKLOAD >> ${OUT_FILE}.wkld

	CMD="$PERF_PREFIX '$LIBFS/run.sh filebench -f $WORKLOAD'" # PINNING is set in run.sh

	# Print command.
	echo Command: "$CMD" | tee ${OUT_FILE}.out

	# Execute
	eval $CMD | tee -a ${OUT_FILE}.out
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# fixCPUFreq

	DIR="$OXBOW_PREFIX" # Overriding config.

	# Umount if mounted.
	sudo umount $OXBOW_PREFIX || true

	# Kill all the Oxbow processes and bench processes.
	$SECURE_DAEMON/run.sh -k || true
	sudo pkill -9 filebench || true
	sleep 3

	# Oxbow is initialized in flushCache.
	# initOxbow

	# Configure and mount file system.
	sudo chown -R $USER:$USER $MOUNT_PATH
	mkdir -p $DIR

	loopFilebench

	killBgOxbow

	echo "Output files are in 'results' directory."
fi
