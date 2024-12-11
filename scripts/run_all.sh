#!/bin/bash
set -ex
# Default configurations #################
BENCH_DIR="/home/yulistic/oxbow/bench/filebench"                                  # Set proper path.
#DIR="/mnt/ext4/filebench_test" # Basename is used as a bench run name. Use different name. Ex) /mnt/ext4/text_ext4 --> text_ext4 is name.
NUM_THREADS="1 2 4 8 16" # Ex: "1 16 4 1"
# WORKLOADS="myfileserver.f myvarmail.f mywebserver.f"
WORKLOADS="varmail_oxbow.f"
PROFILE_CPU_UTILIZATION=1
PINNING=""
# PINNING="numactl -N 1 -m 1"
PERF_BIN="/lib/modules/$(uname -r)/source/tools/perf/perf" # Set correct perf bin path.
##########################################
#

# Check bench dir.
if [ ! -d "$BENCH_DIR" ]; then
	echo "Set proper BENCH_DIR. Current setup: ${BENCH_DIR}"
	exit 1
fi

# Check perf bin.
if [ "$PROFILE_CPU_UTILIZATION" = "1" ]; then
	$PERF_BIN -h &>/dev/null || { echo "Set proper perf bin. Current setup: ${PERF_BIN}"; exit 1; }
fi

DATE=$(date +"%y%m%d-%H%M%S")

# Disable randomization. Filebench issue.
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

### Microbench throughput
loopFilebench() {
	for wl in $WORKLOADS; do
		WORKLOAD="${BENCH_DIR}/workloads/${wl}"

		# Set workload path.
		sed -i "/set \$dir=*/c\set \$dir=${DIR}" $WORKLOAD

		for NUM_THREAD in $NUM_THREADS; do

			# Configuration with the different number of threads.
			[[ $(type -t configMultiThread) == function ]] && configMultiThread

			# Set output file path.
			OUT_DIR=$(basename $WORKLOAD)
			OUT_DIR="$BENCH_DIR/results/${OUT_DIR%.*}/$(basename $DIR)"
			mkdir -p $OUT_DIR

			# file name without extension.
			OUT_FILE="$OUT_DIR/${NUM_THREAD}t"

			echo "Dropping cache."
			flushCache

			if [ "$PROFILE_CPU_UTILIZATION" = "1" ]; then
				### Using iostat
				#OUT_CPU_FILE=${OUT_FILE}.cpu
				## Start to record CPU utilization with time stamps in background.
				#iostat -c 1 | awk '!/^$|avg-cpu|Linux/ {print systime(), $0}' >$OUT_CPU_FILE &

				### Using perf.
				OUT_CPU_FILE=${OUT_FILE}.perfdata
				PERF_PREFIX="sudo $PERF_BIN record -F 99 -e cycles -a -o $OUT_CPU_FILE --"
			else
				PERF_PREFIX=""
			fi

			# if [[ -n $OXBOW_PREFIX && $DIR == *"$OXBOW_PREFIX" ]]; then
			#         CMD="$PINNING $LIBFS/run.sh filebench -f $WORKLOAD"
			# else
			#	CMD="sudo $PINNING filebench -f $WORKLOAD"
			# fi

			# Print mount state.
			sudo mount > ${OUT_FILE}.mount

			runFileSystemSpecific

			# if [ "$PROFILE_CPU_UTILIZATION" = "1" ]; then
			#         # Kill top background process.
			#         sudo pkill -9 -x "iostat"
			# fi

		done
	done
}

# Execute only this script is directly executed. (Not sourced)
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#         loopFilebench
#         echo "Output files are in 'results' directory."
# fi
