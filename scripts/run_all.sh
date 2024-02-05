#!/bin/bash
# Default configurations #################
BENCH_DIR="./"                                  # Set proper path.
# FS="ext4"
# FS="ext4_nojournal"
FS="zj"
DIR="/mnt/${FS}/filebench_test" # Basename is used as a bench run name. Use different name. Ex) /mnt/ext4/text_ext4 --> text_ext4 is name.
WORKLOAD="myfileserver.f"
PROFILE_CPU_UTILIZATION=1
PINNING="numactl -N 0 -m 0"
##########################################

DATE=$(date +"%y%m%d-%H%M%S")

dropCache() {
	{ echo 3 | sudo tee /proc/sys/vm/drop_caches; } &>/dev/null
	sleep 10
}

### Microbench throughput
runFilebench() {
	cd "$BENCH_DIR" || exit

	# Set workload path.
	sed -i "/set \$dir=*/c\set \$dir=${DIR}" $WORKLOAD

	# Set output file path.
	OUT_DIR="./results/${WORKLOAD%.*}/$FS/$DATE"
	OUT_FILE=$OUT_DIR/out.txt
	mkdir -p $OUT_DIR

	cp $WORKLOAD "${OUT_DIR}/"

	echo "Dropping cache."
	dropCache

	if [ -n $PROFILE_CPU_UTILIZATION ]; then
		OUT_CPU_FILE=${OUT_DIR}/cpu.txt

		# Start to record CPU utilization with time stamps in background.
		iostat -c 1 | awk '!/^$|avg-cpu|Linux/ {print systime(), $0}' >$OUT_CPU_FILE &
	fi

	if [[ -n $OXBOW_PREFIX && $DIR == *"$OXBOW_PREFIX" ]]; then
		CMD="$PINNING $LIBFS/run.sh filebench -f $WORKLOAD"
	else
		CMD="$PINNING filebench -f $WORKLOAD"
	fi

	# Print command.
	echo Command: "$CMD" | tee ${OUT_FILE}

	# Execute
	$CMD | tee -a ${OUT_FILE}

	if [ -n $PROFILE_CPU_UTILIZATION ]; then
		# Kill top background process.
		sudo pkill -9 -x "iostat"
	fi
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	runFilebench
	# runMicroLat
	echo "Output files are in 'results' directory."
fi
