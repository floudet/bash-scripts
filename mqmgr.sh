#!/bin/bash
# postfix mail queue management script
# Description: Allows to manage postfix mail queue
# Author: Fabien Loudet

# Variables
MAILQ=/usr/bin/mailq
DEBUG=0
MAILFROM=""
RCPTTO=""
SORT=0
DELETE=0

# Display Usage
_usage() {
	echo "Usage: $0 [ -f sender | -t recipient ] [ -p partial ] [ -d delete ] [ -s sort]"
	echo "Search options: "
	echo "    -f search queue for emails sent by specified sender (\"from\")" 
	echo "    -t search queue for emails sent to specified recipient (\"to\")"
	echo "    -p partial search"
	echo "Display options: "
	echo "    -s group and sort by number of occurences" 
	echo "Action options : "
	echo "    -d remove search results from the queue (requires root privileges)"
	echo "Diagnostic Options: "
	echo "    -D Debug "
	exit -1
}

# Get options from command line
if [[ -z $1 ]]; then _usage; exit -1; fi
if [[ $1 == "--help" ]]; then _usage; exit -1; fi
while getopts "Dpsf:t:d" ARG
do
	case "$ARG" in
		D)	DEBUG=1
			;;
		f)	MAILFROM=$OPTARG
			;;
		t)	RCPTTO=$OPTARG
			;;
		p)	PARTIAL=1
			;;
		s)	SORT=1
			;;
		d)	DELETE=1
			;;
		*)	_usage
			;;
	esac
done

# Check options
if [[ -z $MAILFROM && -z $RCPTTO ]];then
	echo "-f or -t option is mandatory"
	exit -1
fi

if [[ $MAILFROM && $RCPTTO ]];then
	echo "you cannot use -f with -t"
	exit -1
fi

if [[ $SORT -gt 0 && $DELETE -gt 0 ]];then
	echo "you cannot use -s with -d"
	exit -1
fi 	

if [[ $DELETE -gt 0 && $EUID -ne 0 ]];then
	echo "-d (delete) option requires root privileges"
	exit -1
fi

## Start build command
TORUN="$MAILQ | tail -n +2 | grep -v '^ *(' | awk  'BEGIN { RS = \"\" } { if ( " 

if [[ $PARTIAL -gt 0 ]];then
	if [[ $MAILFROM ]];then
		TORUN=$TORUN'$7 ~ /'$MAILFROM'/'
	fi
	if [[ $RCPTTO ]];then
		TORUN=$TORUN'$8 ~ /'$RCPTTO'/'
	fi
else
	if [[ $MAILFROM ]];then
		TORUN=$TORUN'$7 == "'$MAILFROM'"'
	fi
	if [[ $RCPTTO ]];then
		TORUN=$TORUN'$8 == "'$RCPTTO'"'
	fi
fi

# Output format
# $1:		Queue ID
# $7: 		Sender
# $8:		Recipient
FORMAT='"%s\t%s\t%s\n",$1,$7,$8' 
if [[ $SORT -gt 0 ]];then
	if [[ $MAILFROM ]];then
		FORMAT='"%s\n",$8'
	fi
	if [[ $RCPTTO ]];then
		FORMAT='"%s\n",$7'
	fi
fi
if [[ $DELETE -gt 0 ]];then
	TORUN=$TORUN' ) print $1 }'"'"
else
	TORUN=$TORUN' ) printf ('$FORMAT') }'"'"
fi

# Exclude emails being processed
TORUN=$TORUN' | tr -d '"'"'*!'"'" 

# Sort
if [[ $SORT -gt 0 ]];then
	TORUN=$TORUN' | sort | uniq -c | sort -nr'
fi

# Delete
if [[ $DELETE -gt 0 ]];then
	TORUN=$TORUN' | postsuper -d -'
fi
## End build command

# If -D Debug option is selected, print the command
if [[ $DEBUG -gt 0 ]];then echo $TORUN; fi

# Run the command and display the output
OUTPUT=$(eval $TORUN)
if [[ -z $OUTPUT ]];then
	if [[ $DELETE -eq 0 ]];then 
		echo "No entries found"
	fi
else
	echo "$OUTPUT"
fi

