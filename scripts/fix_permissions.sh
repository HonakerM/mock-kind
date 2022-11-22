account_list=$(kubectl get sa -ojsonpath="{range .items[*]}{.metadata.name}{' '}")
NAMESPACE=$(kubectl get sa -ojsonpath="{.items[0].metadata.namespace}")
for sa in $account_list ; do 
  kubectl delete clusterrolebinding $sa-cluster-admin
  kubectl create clusterrolebinding  $sa-cluster-admin --clusterrole=cluster-admin --serviceaccount=${NAMESPACE}:$sa ;
done
