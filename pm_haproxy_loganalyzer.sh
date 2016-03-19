#!/bin/bash
# Poor man's HAProxy Log Analyzer 
# Description: Display statistics from HAProxy log files
# Author: Fabien Loudet

# Variables
LINES=0
FILE="/var/log/haproxy.log"
COMMAND=""
IP=""

# Display Usage
_usage() {

	echo "Usage: $0 [-h] [ -n lines ] [ -f file ] [ -c command | -i IP ]"
	echo "Options: "
	echo "    -h --help     * show help and exit" 
	echo "    -n [lines]    * number of lines to process (default: all)"
	echo "    -f [file]     * log file to analyze (default: /var/log/haproxy.log)"
	echo "    -c [command]  * statistic requested, possible values:" 
	echo "                          top-ips"
	echo "                          top-response-codes"
	echo "                          top-url-requests"
	echo "    -i [IP]       * requests statistics for specific IP"
	exit -1
}

# Test the validity of an IP address
function _valid_ip() {

	local  IP=$1
	local  ISVALID=1

	if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		IP=($IP)
		IFS=$OIFS
		[[ ${IP[0]} -le 255 && ${IP[1]} -le 255 && ${IP[2]} -le 255 && ${IP[3]} -le 255 ]]
		ISVALID=$?
	fi
	return $ISVALID
}

# Get options from command line
if [[ -z $1 ]]; then _usage; exit -1; fi
if [[ $1 == "--help" ]]; then _usage; exit -1; fi
while getopts "hn:f:c:i:" ARG
do
	case "$ARG" in
		h)	_usage
			;;
		n)	LINES=$OPTARG
			;;
		f)	FILE=$OPTARG
			;;
		c)
		case "$OPTARG" in
			"top-ips")
				COMMAND="top-ips"
				;;
			"top-response-codes")
				COMMAND="top-response-codes"
				;;
			"top-url-requests")
				COMMAND="top-url-requests"
				;;
			*) 
				echo "invalid command provided for -c"
				_usage
				;;
		esac
		;;
		i)	IP=$OPTARG
			;;
		*)	_usage
			;;
	esac
done

# Does the log file provided exists and is readable
if [[ ! -r $FILE ]];then
	echo "'$FILE' doesn't exists or cannot be opened"
	exit -1
fi

if [[ -z $COMMAND && -z $IP ]];then
	echo "you must provide -c or -i"
	_usage
fi

if [[ $COMMAND && $IP ]];then
	echo "you cannot use -c with -i"
	exit -1
fi

if [[ $IP ]];then
	_valid_ip $IP
	if [[ $? -ne 0 ]];then
		echo "Invalid IP address provided"
		exit -1
	fi
fi

## Start build command
if [[ $LINES -eq 0 ]];then
	TORUN="cat $FILE "
else
	TORUN="tail -n $LINES $FILE"
fi

if [[ $IP ]];then
	# Yes I'm grepping the cat :)
	TORUN=$TORUN" | grep \"$IP\" | awk '{print \$4}' | sort -n | uniq -c | awk '{if(min==\"\"){min=max=\$1};if(\$1>max){max=\$1}; if(\$1<min){min=\$1}; sum+=\$1} END { print \"Avg req/s: \",sum/NR, \"\nMin req/s: \",min, \"\nMax req/s: \",max}'"
	## End build command (-i)
else
	case "$COMMAND" in
		"top-ips")
			TORUN=$TORUN" | awk '{ print \$4 }' | cut -d':' -f1"
			;;
		"top-response-codes")
			TORUN=$TORUN" | awk '{ print \$9 }' | cut -d':' -f1"
			;;
		"top-url-requests")
			TORUN=$TORUN" | cut -d'\"' -f2"
			;;
	esac

	TORUN=$TORUN' | sort | uniq -c | sort -gr'
	## End build command (-c)
fi

# Run the command and display the output
OUTPUT=$(eval $TORUN)
if [[ -z $OUTPUT ]];then
	if [[ $DELETE -eq 0 ]];then 
		echo "No output, something went wrong"
	fi
else
	echo "$OUTPUT"
fi

