
kind create cluster --config public-config.yaml

export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
export OS=$(uname | awk '{print tolower($0)}')
export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/v1.25.1
curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
chmod +x ./operator-sdk_${OS}_${ARCH}
./operator-sdk_${OS}_${ARCH} olm install 

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.yaml


docker exec -it kind-control-plane bash

apt update
apt install -y nfs-kernel-server
mkdir -p /var/nfs
chown -R nobody:nogroup /var/nfs
echo "/var/nfs     127.0.0.1(rw,sync,no_subtree_check)" > /etc/exports
exportfs -a
systemctl restart nfs-kernel-server
exit

kubectl apply -f ./nfs/namespace.yaml
kubectl apply -f ./nfs/.
kubectl patch storageclass standard  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

for namespace in $(kubectl get namespaces -A -ojsonpath='{range .items[*]}{.metadata.name}{" "}{end}')
do
    for pod in $(kubectl get deployments -n ${namespace} -ojsonpath='{range .items[*]}{.metadata.name}{" "}{end}')
    do
        echo ${namespace} ${pod}
        kubectl patch deployment ${pod} -n ${namespace} --type merge --patch '{"spec":{"template":{"spec":{"nodeName":"kind-control-plane"}}}}'
    done
    for pod in $(kubectl get statefulset -n ${namespace} -ojsonpath='{range .items[*]}{.metadata.name}{" "}{end}')
    do
        echo ${namespace} ${pod}
        kubectl patch statefulset ${pod} -n ${namespace} --type merge --patch '{"spec":{"template":{"spec":{"nodeName":"kind-control-plane"}}}}'
    done
done


kind get kubeconfig > config
kubectl create namespace hollow
kubectl create secret generic kubeconfig --namespace=hollow --type=Opaque --from-file=kubelet.kubeconfig=config --from-file=kubeproxy.kubeconfig=config

kubectl apply -f hollow-node.yaml

kubectl taint nodes kind-control-plane spoofed=true:NoSchedule