#!/bin/sh

CONFIG=passwall
TMP_PATH=/tmp/etc/$CONFIG
TMP_BIN_PATH=$TMP_PATH/bin
TMP_SCRIPT_FUNC_PATH=$TMP_PATH/script_func
TMP_ID_PATH=$TMP_PATH/id
LOCK_FILE_DIR=/tmp/lock
LOCK_FILE=${LOCK_FILE_DIR}/${CONFIG}_script.lock

config_n_get() {
	local ret=$(uci -q get $CONFIG.$1.$2 2>/dev/null)
	echo ${ret:=$3}
}

config_t_get() {
	local index=0
	[ -n "$4" ] && index=$4
	local ret=$(uci -q get $CONFIG.@$1[$index].$2 2>/dev/null)
	echo ${ret:=$3}
}

ENABLED=$(config_t_get global enabled 0)
[ "$ENABLED" != 1 ] && return 1
ENABLED=$(config_t_get global_delay start_daemon 0)
[ "$ENABLED" != 1 ] && return 1
sleep 58s
while [ "$ENABLED" -eq 1 ]; do
	[ -f "$LOCK_FILE" ] && {
		rm -f $LOCK_FILE
		sleep 10s
		continue
	}
	touch $LOCK_FILE

	for filename in $(ls ${TMP_SCRIPT_FUNC_PATH}); do
		cmd=$(cat ${TMP_SCRIPT_FUNC_PATH}/${filename})
		cmd_check=$(echo $cmd | awk -F '>' '{print $1}')
		[ -n "$(echo $cmd_check | grep "dns2socks")" ] && cmd_check=$(echo $cmd_check | sed "s#:# #g")
		if ! echo "$cmd_check" | grep -q "url_test"; then
			icount=$(pgrep -f "$(echo $cmd_check)" | wc -l)
			if [ $icount = 0 ]; then
			    # Make Sure Process not Started by Other Scripts
		        sleep 10s
				icount=$(pgrep -f "$(echo $cmd_check)" | wc -l)
			    if [ $icount = 0 ]; then
					echo "${cmd_check} Crashed, Restarting..." >> /tmp/log/passwall.log
					eval $(echo "nohup ${cmd} 2>&1 &") >/dev/null 2>&1 &
				fi
			fi
		fi
	done
	
	rm -f $LOCK_FILE
	sleep 20s
done
