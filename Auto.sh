#!/bin/bash
while true
do
	ps -ef | grep "node" | grep -v "grep"
	if [ "$?" -eq 1 ]
		then 
		echo "process has restarting..."
		GOEXPERIMENT=arenas go run ./...
		echo "process has been restarted!"
	else
		echo "process already started!"
	fi
	sleep 10
 done
