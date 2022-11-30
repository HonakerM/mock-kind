#!/bin/bash

if [[ ! $# -eq 2 ]] ; then
    echo "Not enough arguements: $#"
    exit 1
fi

folder=$1
service_name=$2

if [ "$(kubectl get namespace webhook -ojsonpath='{.metadata.name}')" != "webhook" ]; then
    kubectl create namespace webhook
fi
kubectl delete secret ${service_name}-tls -n webhook
kubectl create secret tls ${service_name}-tls -n webhook --cert "${folder}/admission-tls.crt" --key "${folder}/admission-tls.key"

kubectl apply -f ./manifests/deployment.yaml

sed "s/<<CA_BUNDLE>>/$(cat ${folder}/ca.crt | base64 | tr -d '\n')/" manifests/webhook.yaml | kubectl apply -f -
