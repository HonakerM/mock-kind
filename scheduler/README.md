docker build --tag test-scheduler .      
kind load image
docker cp config/schedule_override.yaml kind-control-plane:/mnt/schedule_override.yaml 
docker exec -it kind-control-plane bash -c "cat /etc/kubernetes/manifests/kube-scheduler.yaml" | yq '.spec.image="test-scheduler:latest" , .spec.volumes += [ {"hostPath":{"path":"/mnt/schedule_override.yaml","type":"FileOrCreate"},"name":"kubeconfig"} ], .spec.containers[0].volumeMounts += [{"mountPath":"/etc/kubernetes/schedule_override.yaml","name":"scheduleconfig","readOnly": true}] ,.spec.containers[0].command += ["--config=/etc/kubernetes/schedule_override.yaml"]'

