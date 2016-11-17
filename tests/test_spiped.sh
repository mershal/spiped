#!/bin/sh

# Build directory (we don't allow out-of-tree builds in spiped).
bindir=.

# This test script requires three ports.
src_port=8000
mid_port=8001
dst_port=8002

# Constants
out="output-tests-spiped"

# Timing commands (in seconds).
sleep_nc_start=1
sleep_spiped_start=2
sleep_nc_stop=1

################################ Setup variables from the command-line

# Find script directory and load helper functions.
scriptdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
. ${scriptdir}/shared_test_functions.sh

# Find relative spiped binary paths.
spiped_binary=${scriptdir}/../spiped/spiped
spipe_binary=${scriptdir}/../spipe/spipe
spiped_nc=${scriptdir}/spiped_nc/spiped_nc

# Find system spiped if it supports -1.
system_spiped_binary=$( find_system spiped -1 )

# Check for required commands.
if ! command -v ${spiped_binary} >/dev/null 2>&1; then
	echo "spiped not detected; did you forget to run 'make all'?"
	exit 1
fi
if ! command -v ${spipe_binary} >/dev/null 2>&1; then
	echo "spiped not detected; did you forget to run 'make all'?"
	exit 1
fi

# Clean up previous directories, and create new ones.
prepare_directories

################################ Helper functions

check_leftover_spiped_nc_server() {
	# Repeated testing, especially when doing ctrl-c to break out of
	# (suspected) hanging, can leave a spiped_nc server floating around,
	# which is problematic for the next testing run.  Checking for this
	# shouldn't be necessary for normal testing (as opposed to test-script
	# development), but there's no harm in checking anyway.
	leftover=""

	# Find old spiped_nc server on ${dst_port}.
	cmd="spiped_nc ${dst_port}"
	oldpid=`ps -Aopid,command | grep "${cmd}" | grep -v "grep" | awk '{print $1}'`
	if [ ! -z ${oldpid} ]; then
		echo "Error: Left-over server from previous run: pid= ${oldpid}"
		leftover="1"
	fi

	# Early exit if any previous servers found.
	if [ ! -z ${leftover} ]; then
		echo "Exit from left-over servers"
		exit 1
	fi
}

################################ Server setup

## setup_spiped_decryption_server(nc_output=/dev/null, use_system_spiped=0):
# Set up a spiped decryption server, translating from ${mid_port}
# to ${dst_port}, saving the exit code to ${c_exitfile}.  Also set
# up a spiped_nc server listening to ${dst_port}, saving output to
# ${nc_output}.  Uses the system's spiped (instead of the
# version in this source tree) if ${use_system_spiped} is 1.
setup_spiped_decryption_server () {
	nc_output=${1:-/dev/null}
	use_system_spiped=${2:-0}
	check_leftover_spiped_nc_server

	# Select system or compiled spiped.
	if [ "${use_system_spiped}" -gt 0 ]; then
		spiped_cmd=${system_spiped_binary}
	else
		spiped_cmd=${spiped_binary}
	fi

	# Start backend server.
	${spiped_nc} ${dst_port} ${nc_output} &
	nc_pid=${!}
	sleep ${sleep_nc_start}

	# Start spiped to connect middle port to backend.
	(
		${spiped_cmd} -d			\
			-s [127.0.0.1]:${mid_port}	\
			-t [127.0.0.1]:${dst_port}	\
			-k /dev/null -F -1 -o 1
		echo $? > ${c_exitfile}
	) &
	sleep ${sleep_spiped_start}
}

## setup_spiped_decryption_server(basename):
# Set up a spiped encryption server, translating from ${src_port}
# to ${mid_port}, saving the exit code to ${c_exitfile}.
setup_spiped_encryption_server () {
	# Start spiped to connect source port to middle.
	(
		${spiped_cmd} -e			\
			-s [127.0.0.1]:${src_port}	\
			-t [127.0.0.1]:${mid_port}	\
			-k /dev/null -F -1 -o 1
		echo $? > ${c_exitfile}
	) &
	sleep ${sleep_spiped_start}
}

## nc_server_stop():
# Stops the nc server.
nc_server_stop() {
	sleep ${sleep_nc_stop}
	kill ${nc_pid}
	wait
}

####################################################

# Run the test scenarios; this will exit on the first failure.
run_scenarios ${scriptdir}/??-*.sh
