#!/bin/bash

CSV_LIST="$@"
for deployment in ${CSV_LIST} ; do 
	echo $deployment
        kubectl get deployment $deployment -o json | jq '(..|select(has("runAsNonRoot"))?) +=  {runAsNonRoot: false}' | kubectl apply -f - ;
done
