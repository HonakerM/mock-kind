#!/bin/bash

if [[ ! $# -eq 2 ]] ; then
    echo "Not enough arguements: $#"
    exit 1
fi

folder=$1
service_name=$2

#openssl req -nodes -new -x509 -keyout ${folder}/ca.key -out ${folder}/ca.crt -subj "/CN=Spoofed Webhook"
#openssl genrsa -out ${folder}/admission-tls.key 2048
#openssl req -new -key ${folder}/admission-tls.key -subj "/CN=Spoofed Webhook" -addext "subjectAltName = DNS:spoofed-webhook.webhook.svc" | openssl x509 -req -CA ${folder}/ca.crt -CAkey ${folder}/ca.key -CAcreateserial -out ${folder}/admission-tls.crt

openssl req -nodes -new -x509 -keyout ${folder}/ca.key -out ${folder}/ca.crt -subj "/CN=Spoofed Webhook"
openssl genrsa -out ${folder}/admission-tls.key 2048
openssl req -new -key ${folder}/admission-tls.key -subj "/CN=Spoofed Webhook" -out ${folder}/admission-tls.csr
echo -e "[ req ]\nreq_extensions = req_ext\n\n[ v3_ext ]\nsubjectAltName = DNS:${service_name}.webhook.svc" > ${folder}/ext.cnf
openssl x509 -req -CA ${folder}/ca.crt -CAkey ${folder}/ca.key -CAcreateserial -out ${folder}/admission-tls.crt -in ${folder}/admission-tls.csr -extfile ${folder}/ext.cnf --extensions v3_ext