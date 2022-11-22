#!/bin/bash

if [[ ! $# -eq 2 ]] ; then
    echo "Not enough arguements: $#"
    exit 1
fi

type=$1
name=$2

echo "locking resource of type $deployment with name $name"
if [ "$type" == "deployment" ] || [ "$type" == "statefulset" ] || [ "$type" == "job" ] ; then
  kubectl patch $type $name --type merge -p '{"spec":{"template":{"spec":{"nodeName":"kind-control-plane"}}}}'
  exit 0
fi
