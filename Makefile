.PHONY: kind setup tmpdir

ROOT:=$(shell pwd)
TMPDIR:=${ROOT}/.tmp

KIND_CONFIG_FILE?="${ROOT}/default-config.yaml"
KUBE_VERSION?="v1.25.3"
kind:
	kind delete cluster
	kind create cluster --image kindest/node:${KUBE_VERSION} --config ${KIND_CONFIG_FILE}

tmpdir:
	mkdir -p ${TMPDIR}

ARCH?=amd64
OS?=linux
OPERATOR_SDK_DL_URL:=https://github.com/operator-framework/operator-sdk/releases/download/v1.25.1
get_operator_sdk: tmpdir
	echo "Downloading Operator SDK"
	curl -Lo ${TMPDIR}/operator_sdk ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
	chmod +x ${TMPDIR}/operator_sdk

olm_install: tmpdir get_operator_sdk
	echo "Installing OLM Resources"
	${TMPDIR}/operator_sdk olm install

certmanager_install:
	echo "Installing Cert Manager"
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.yaml

nfsserver_install:
	echo "Setting Up NFS Server"
	docker exec -t kind-control-plane bash -c " \
	  	apt update &&\
		apt install -y nfs-kernel-server &&\
		mkdir -p /var/nfs &&\
		chown -R nobody:nogroup /var/nfs &&\
		echo '/var/nfs     127.0.0.1(rw,sync,no_subtree_check)' > /etc/exports &&\
		exportfs -a &&\
		systemctl restart nfs-kernel-server"

nfsstorageclass_install:
	echo "Initalizing NFS Storage Class"
	kubectl apply -f ${ROOT}/nfs/namespace.yaml
	kubectl apply -f ${ROOT}/nfs/.
	kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

setup: tmpdir olm_install certmanager_install nfsserver_install nfsstorageclass_install
	
lock:
	bash -c "${ROOT}/lock_cluster.sh"
	kubectl taint nodes kind-control-plane spoofed=true:NoSchedule

KUBEMARK_IMAGE?=kubemark:internal
image:
	docker build --tag ${KUBEMARK_IMAGE} .

image.push:
	docker push ${KUBEMARK_IMAGE}

image.load:
	kind load docker-image ${KUBEMARK_IMAGE} 

KUBECONFIG?=${TMPDIR}/kubeconfig.yaml
exportconfig: tmpdir
	echo "Exporting kind config to ${KUBECONFIG}"
	kind get kubeconfig --internal > ${KUBECONFIG}

NODE_RESOURCE?=${ROOT}/hollow-node.yaml
node: tmpdir
	echo "kind: Namespace\napiVersion: v1\nmetadata:\n  name: hollow" | kubectl apply -f -
	echo "kind: Secret\napiVersion: v1\nmetadata:\n  name: kubeconfig\n  namespace: hollow\ndata:\n  kubelet.kubeconfig: $(shell cat ${KUBECONFIG} | base64 -w 0)" | kubectl apply -f -
	kubectl apply -f ${NODE_RESOURCE}