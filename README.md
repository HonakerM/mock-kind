# Mock Kind

This repo contains the scripts and configuration files for setting up a semi mocked or "hollow" kubernetes environment. This repo utilizes a kubernetes testing tool called [kubemark](https://github.com/kubernetes/community/blob/4026287dc3a2d16762353b62ca2fe4b80682960a/contributors/devel/sig-scalability/kubemark-setup-guide.md). Kubemark was originally created by the kubernetes `sig-scalability` group to test how the kube api handles dealing with extremely large clusters (i.e. 1000+ nodes) without having to actually provision those resources. It does this by starting a pod running a "hollow" kubelet which then registers itself with the cluster. Any pods scheduled to that "hollow" node are immediatly marked as `Ready` without contactng the CRI. However, kubemark still performes any validation that would normally go into starting a pod (i.e. mounting PVC's, resources available, etc). In traditional kubemark tests you're supposed to utilize two seperate clusters: 1 for running the kubemark pods and 1 that's just a control plane node that the hollow nodes register to. The main difference with my implementation is that the hollow pods are running on the same cluster they register to. This has the benift of only needing one cluster but the drawback is that you then have to be careful where you're scheduling pods.


All interaction with the repo should be done via `make` commands. To update the version of kubernetes being used set the `KUBE_VERSION` variable (default `v1.25.3`).

## Pre Reqs
This repository assumes you have [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/), [GNU Make](https://www.gnu.org/software/make/) and [docker](https://docs.docker.com/get-docker/) already installed.

## Initial Cluster Setup

To spin up a bare bones kind cluster you can run the following command. The kubernetes version is configurable via the `KUBE_VERSION` (default: v1.25.3) argument. One thing to note is that this will tear down any currently running kind cluster.
```
make kind
```


Once the kind cluster is up you can install the general dependencies using the following make command. This installs cert manager v1.10.0, olm v1.25.1, and configures a nfs storage class to be used by all nodes. 
```
make setup
```

After setup has completed feel free to deploy any more resources you'll want actually running on the cluster. So things like operators and the like should be installed at this point. 

### Post Setup

Once you have the cluster to your liking its time to lock down the resources to the `kind-control-plane` node. As mentioned above `kubemock` adds nodes to the cluster so any pod scheduled on them is spoofed. To prevent this from happening to pods we want running you have to run the following command. 
```
make lock
```
This command patches every deployment and statefulset to include the following yaml. This forces all pods to be scheduled on the `kind-control-plane` node regardless of tains or affinities. Then the command taints the node with `spoofed=true:NoSchedule` to force all future pods to utilize other "hollow" nodes.
```
spec:
  template:
    spec:
      nodeName: kind-control-plane
```
## Hollowing out Kubernetes

### Building the Image
Now that your cluster is locked down its time to start adding "hollow" nodes. Before you can add the node you first have to build the node image by running the following make command. You can customize the image name via the `KUBEMARK_IMAGE` argument (default: `kubemark:latest`) and cutomize the kubemakr image using `KUBE_VERSION` (default: v1.25.3)  Note this build can take awhile and uses up alot of storage as it requires cloning the entire kubernetes repo&builds it; however, the final image is only around `123MB`
```
make image
```
Once the image has been built you can either push it to a registry using `make image.push` or just sideload it into the `kind-control-plane` docker container using `make image.load`. The same `KUBEMARK_IMAGE` works here as well.

### Configuring KubeConfig
The hollow nodes will need a kubeconfig that has atleast `system:node` cluster role level permissions. The easiest way this can be done is by running the make command found bellow which copies the clusters admin kubeconfig. Another way is by creating a `ServiceAccount` and `ClusterRoleBinding` and then exporting the kubeconfig but that is not documented here. For the make command you can change the export location using `KUBECONFIG`.
```
make exportconfig
```

### Starting the nodes
Once the cluster can access the image and the kubeconfig has been saved the last thing to do is start the nodes. If you want to use the default configuration you can run the `make` command located after this paragraph. The first thing this command does is upload the kubeconfig secret gathered earlier. It assumes the file was saved to `.tmp/kubeconfig.yaml` but that can be changed via the `KUBECONFIG` setting. Next it applies the statefulset found at [hollow-node.yaml](hollow-node.yaml). If you're using a custom image name update both of the containers `image:` before running the command. Finally the node resources can be updated by changing the pod requests. 
```
make node
```


## FootNote

### Pulling from a Private Registry
If you'd like to pull from a private registry first generate a [kubernetes auth config json file](https://kubernetes.io/docs/concepts/containers/images/#config-json) and save it somewhere locally. Then run the `make` command located below to update the kubernetes control plane's docker auth config. Kubernetes will now use your auth file for any image pull's it requires.
```
make secret.load <path-to-kube-config>
```