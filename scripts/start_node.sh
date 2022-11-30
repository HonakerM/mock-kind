#!/bin/bash

if [[ ! $# -eq 2 ]] ; then
    echo "Not enough arguements: $#. need 2"
    exit 1
fi

kubeconfig=$1
resource=$2

# Create node resources
if [ "$(kubectl get namespace hollow -ojsonpath='{.metadata.name}')" != "hollow" ]; then
    kubectl create namespace hollow
fi
if [ "$(kubectl get secret kubeconfig -n hollow -ojsonpath='{.metadata.name}')" != "kubeconfig" ]; then
    kubectl create secret generic kubeconfig --type=Opaque --namespace hollow --from-file=kubelet.kubeconfig=${kubeconfig} 
fi
kubectl apply -f ${resource}

# wait until nodes are up
echo "Waiting until nodes are ready"
until [ $(kubectl get nodes --field-selector="metadata.name!=kind-control-plane" -oname | wc -l) != "$(kubectl get pods -n hollow | wc -l)" ];
do
    echo "Nodes are not ready waiting 5 more seconds...."
    sleep 5
    if [ $(kubectl get nodes --field-selector="metadata.name!=kind-control-plane" -oname | wc -l) != "$(kubectl get pods -n hollow | wc -l)" ]; then
        echo "Nodes are Ready!"
        break
    fi
done

echo "Annotating nodes"
kubectl annotate node --field-selector="metadata.name!=kind-control-plane" --overwrite spoofed=true