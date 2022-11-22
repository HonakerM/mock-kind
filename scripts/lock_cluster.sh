for namespace in $(kubectl get namespaces -A -ojsonpath='{range .items[*]}{.metadata.name}{" "}{end}')
do
    for deployment in $(kubectl get deployments -n ${namespace} -ojsonpath='{range .items[*]}{.metadata.name}{" "}{end}')
    do
        echo Locking deployment ${deployment} in ${namespace}
        kubectl patch deployment ${deployment} -n ${namespace} --type merge --patch '{"spec":{"template":{"spec":{"nodeName":"kind-control-plane"}}}}'
    done
    for statefulset in $(kubectl get statefulset -n ${namespace} -ojsonpath='{range .items[*]}{.metadata.name}{" "}{end}')
    do
        echo Locking statefulset ${statefulset} in ${namespace}
        kubectl patch statefulset ${statefulset} -n ${namespace} --type merge --patch '{"spec":{"template":{"spec":{"nodeName":"kind-control-plane"}}}}'
    done
done
