ifeq (secret.load,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
endif

ROOT:=$(shell pwd)
TMPDIR:=${ROOT}/.tmp

### Cluster setup
KIND_CONFIG_FILE?="${ROOT}/default-config.yaml"
KUBE_VERSION?=v1.24.3
kind:
	kind delete cluster
	kind create cluster --image kindest/node:${KUBE_VERSION} --config ${KIND_CONFIG_FILE}

tmpdir:
	mkdir -p ${TMPDIR}


### Cluster Configuration
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

### Scheduler Funcitions and Image
SCHEDULER_IMAGE?=spoofed-scheduler:internal
scheduler:
	cd scheduler && \
	make build IMAGE_NAME=${SCHEDULER_IMAGE}

scheduler.push:
	docker push ${SCHEDULER_IMAGE}

scheduler.load:
	kind load docker-image ${SCHEDULER_IMAGE} 

# Replace this with yq
scheduler.install:
	docker exec -t kind-control-plane bash -c " \
		sed -i 's/k8s.gcr.io\/kube-scheduler:${KUBE_VERSION}/${SCHEDULER_IMAGE}/g' /etc/kubernetes/manifests/kube-scheduler.yaml &&\
		sed -i 's/- kube-scheduler/- \/kube-scheduler\n    - --config=\/etc\/kubernetes\/custom-scheduler.conf/g' /etc/kubernetes/manifests/kube-scheduler.yaml \
	"

### Webhook Functions and Image
WEBHOOK_IMAGE?=spoofed-webhook:internal
webhook:
	cd webhook && \
	make build IMAGE_NAME=${WEBHOOK_IMAGE}

webhook.push:
	docker push ${WEBHOOK_IMAGE}

webhook.load:
	kind load docker-image ${WEBHOOK_IMAGE} 

webhook.install:
	cd webhook && \
	make install 
	

### KubeMark Fucntion and  Image
KUBEMARK_IMAGE?=kubemark:internal
image:
	docker build --tag ${KUBEMARK_IMAGE} --build-arg VERSION=${KUBE_VERSION} .

image.push:
	docker push ${KUBEMARK_IMAGE}

image.load:
	kind load docker-image ${KUBEMARK_IMAGE} 

### Hollow Node Setup
KUBECONFIG?=${TMPDIR}/kubeconfig.yaml
exportconfig: tmpdir
	echo "Exporting kind config to ${KUBECONFIG}"
	kind get kubeconfig --internal > ${KUBECONFIG}

secret.load:
	docker cp  ${RUN_ARGS} kind-control-plane:/var/lib/kubelet/config.json

### Hollow Node Start
NODE_RESOURCE?=${ROOT}/hollow-node.yaml
node: tmpdir
	${ROOT}/scripts/start_node.sh ${KUBECONFIG} ${NODE_RESOURCE}
	
node.uninstall:
	kubectl delete secret kubeconfig --namespace hollow || true
	kubectl delete -f ${NODE_RESOURCE} || true
	kubectl delete  $(shell kubectl get nodes --field-selector='metadata.name!=kind-control-plane' -oname) || true

### Helper Hacks to fix pods meant for openshift
fix.catalog:
	${ROOT}/scripts/fix_security_pod.sh $(shell  bash -c "kubectl get pods | grep 'catalog' | grep -v 'Running' | cut -d ' ' -f 1")

fix.operator:
	${ROOT}/scripts/fix_security_deployment.sh $(shell  bash -c "kubectl get deployment | grep '0' | cut -d ' ' -f 1")

fix.permissions:
	${ROOT}/scripts/fix_permissions.sh

$(eval $(RUN_ARGS):;@:)
.PHONY: kind $(MAKECMDGOALS)
