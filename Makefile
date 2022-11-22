
ifeq (secret.load,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
endif

ROOT:=$(shell pwd)
TMPDIR:=${ROOT}/.tmp

KIND_CONFIG_FILE?="${ROOT}/default-config.yaml"
KUBE_VERSION?="v1.24.3"
kind:
	kind delete cluster
	kind create cluster --image kindest/node:${KUBE_VERSION} --config ${KIND_CONFIG_FILE}

tmpdir:
	mkdir -p ${TMPDIR}

ifeq ($(uname_m),x86_64)
ARCH:=amd64
endif
ifeq ($(uname_m),aarch64)
ARCH:=arm64
endif
ARCH?=amd64
OS?=$(shell bash -c "uname  | tr '[:upper:]' '[:lower:]'")
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


fix.csv:
	${ROOT}/scripts/fix_csv.sh

fix.permissions:
	${ROOT}/scripts/fix_permissions.sh

lock:
	bash -c "${ROOT}/scripts/lock_cluster.sh"
	kubectl taint nodes kind-control-plane spoofed=true:NoSchedule

unlock:
	kubectl taint nodes --all spoofed=true:NoSchedule
	kubectl taint nodes kind-control-plane spoofed=true:NoSchedule-

KUBEMARK_IMAGE?=kubemark:internal
image:
	docker build --tag ${KUBEMARK_IMAGE} --build-arg VERSION=${KUBE_VERSION} .

image.push:
	docker push ${KUBEMARK_IMAGE}

image.load:
	kind load docker-image ${KUBEMARK_IMAGE} 

secret.load:
	docker cp  ${RUN_ARGS} kind-control-plane:/var/lib/kubelet/config.json


KUBECONFIG?=${TMPDIR}/kubeconfig.yaml
exportconfig: tmpdir
	echo "Exporting kind config to ${KUBECONFIG}"
	kind get kubeconfig --internal > ${KUBECONFIG}

NODE_RESOURCE?=${ROOT}/hollow-node.yaml
node: tmpdir
	echo "kind: Namespace\napiVersion: v1\nmetadata:\n  name: hollow" | kubectl apply -f -
	kubectl create secret generic kubeconfig --type=Opaque --namespace hollow --from-file=kubelet.kubeconfig=${KUBECONFIG}
	kubectl apply -f ${NODE_RESOURCE}


$(eval $(RUN_ARGS):;@:)

.PHONY: kind $(MAKECMDGOALS)
