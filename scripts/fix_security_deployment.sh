#!/bin/bash

CSV_LIST="$@"
for pod in ${CSV_LIST} ; do 
	echo $pod
        kubectl get deployment $deployment -o json | jq '(..|select(has("runAsNonRoot"))?) +=  {runAsNonRoot: false}' | kubectl apply -f - ;
done
