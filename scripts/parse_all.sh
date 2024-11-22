#!/bin/bash
# set -xe
#
# PERF_BIN="perf" # Set correct perf bin path.
PERF_BIN="/lib/modules/$(uname -r)/source/tools/perf/perf" # Set correct perf bin path.

printUsage() {
	echo "$(basename $0) <result_dir>"
}

getAggrCPUUsage(){
	f_name=$(basename $1 | cut -d "." -f 1)
	d_path=$(dirname $1)
	report_file="${d_path}/${f_name}.report"

	# sudo $PERF_BIN report --sort overhead -i $1 -F overhead,pid,period,socket --stdio > $report_file
	sudo $PERF_BIN report --sort overhead -i $1 -F overhead,comm,period,socket --stdio > $report_file

	# cat only the processes that consumes more than 1% of CPU.
	cat $report_file | grep -v -E " 0...%|#" > ${d_path}/${f_name}.cpu
}

### top
# getCpuUsage() {
# 	parse_first_line=0
# 	while read -r line; do
# 		if [[ $parse_first_line = 0 ]]; then
# 			parse_first_line=1
# 			start_time=$(echo "$line" | cut -d " " -f1)
# 			echo -n "$start_time,"
# 		fi
# 		cpu_usage=$(echo "$line" | xargs | cut -d " " -f10)
# 		echo -n "$cpu_usage,"
# 	done <"$1"

# 	echo ""
# }

### iostat
getCpuUsage() {
	parse_first_line=0
	while read -r line; do
		if [[ $parse_first_line = 0 ]]; then
			parse_first_line=1
			start_time=$(echo "$line" | cut -d " " -f1)
			echo -n "$start_time,"
		fi
		cpu_idle=$(echo "$line" | xargs | cut -d " " -f7)

		# cpu usage = 100 - idle
		cpu_usage=$(awk "BEGIN {print 100.00 - $cpu_idle}")
		# cpu_usage=$(echo "100.00 $cpu_idle" | awk '{printf "%.2f", $1 - $2}')
		echo -n "$cpu_usage,"
	done <"$1"

	echo ""
}

getCpuCycles() {
	if [ -f $1 ]; then
		cpu_cycles=$(grep "Event count" $1 | xargs | cut -d ' ' -f 5)
		echo -n "$cpu_cycles"
	fi
}

# $1 = myvarmail
parseWorkload() {

	# Extracting CPU usage from perf data.
	for d in $1/*; do
		if ! [ -d "$d" ]; then
			continue
		fi

		for f in $(find $d -type f -name "*.perfdata"); do
			getAggrCPUUsage $f
		done
	done

	# Parse throughput.
	echo "### Throughput (ops/s) - Workload: $(basename $1) ###"
	echo "sys,threads,ops,tput,cycles"
	for d in $1/*; do
		if ! [ -d "$d" ]; then
			continue
		fi


		# Parsing output.
		for f in $(find $d -type f -name "*.out"); do
			filename=$(basename $f)
			sys=$(basename $d)
			thnum=$(echo $filename | cut -d "." -f1 | cut -d "t" -f1)
			ops=$(grep 'IO Summary' $f | xargs | cut -d ' ' -f4)
			thput=$(grep 'IO Summary' $f | xargs | cut -d ' ' -f6)

			echo -n "$sys,$thnum,$ops,$thput,"

			getCpuCycles "${f%.*}".report

			echo ""
		done
	done

	# Parse CPU utilization. (top or iostat)
#	echo "### CPU Utilization (% every second, 100% = 1 core) ###"
#	echo "name,op,iosize,threads,start(timestamp),cpuutil..."
#	for d in $1/*; do
#		if ! [ -d "$d" ]; then
#			continue
#		fi
#
#		for f in $(find $d -type f -name "*.cpu"); do
#			filename=$(basename $f)
#			op=$(echo $filename | cut -d "_" -f1)
#			iosize=$(echo $filename | cut -d "_" -f2)
#			thnum=$(echo $filename | cut -d "_" -f3 | cut -d "t" -f1)
#			filetype=$(echo $filename | cut -d "." -f2)
#
#			echo -n "$(basename $d),${op},${iosize},${thnum},"
#
#			getCpuUsage $f
#		done
#	done

}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

	if [ -z $1 ] || [ $1 = "-h" ] || [ $1 = "--help" ]; then
		printUsage
	fi

	for dir in $1/*; do
		parseWorkload $dir > temp_result.txt

		# Sort and print
		cat temp_result.txt | head -n 2
		cat temp_result.txt | tail -n +3 | sort -t, -k1,1 -k2,2n
		rm temp_result.txt

	done
fi
