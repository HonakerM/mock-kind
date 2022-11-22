#!/bin/bash

CSV_LIST=$(kubectl get pods | grep "catalog" | grep -v "Running" | awk '{print $1}')
for pod in ${CSV_LIST} ; do 
	echo $pod
        kubectl get pod $pod -o json | jq 'del(.status, (.metadata | .creationTimestamp, .ownerReferences, .resourceVersion, .uid), .spec.containers[0].securityContext, .spec.securityContext)| .metadata.name="\(.metadata.generateName)static"|.spec.securityContext.runAsNonRoot=false|.spec.securityContext.runAsUser=0' | kubectl apply -f - ;
done
