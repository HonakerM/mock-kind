/*
Copyright 2019 The Kubernetes Authors.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package spoofed

import (
	"context"
	"fmt"
	"strings"
	"regexp"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/kubernetes/pkg/scheduler/framework"
)



// SpoofControl is a plugin that checks if a pod tolerates a node's taints.
type SpoofControl struct {
	handle framework.Handle
}

var _ framework.FilterPlugin = &SpoofControl{}

const (
	// Name is the name of the plugin used in the plugin registry and configurations.
	Name = "SpoofControl"
)

func (sc *SpoofControl) Name() string {
	return Name
}

// Filter invoked at the filter extension point.
func (sc *SpoofControl) Filter(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeInfo *framework.NodeInfo) *framework.Status {
	node := nodeInfo.Node()
	if node == nil {
		return framework.AsStatus(fmt.Errorf("invalid nodeInfo"))
	}

	if val, ok := pod.GetAnnotations()["nodeName"]; ok {
		if val == node.GetName() {
			return nil
		}
		return framework.NewStatus(framework.UnschedulableAndUnresolvable, fmt.Sprintf("pod had nodeName annotation %s but did not match any nodes",val))
	}

	clientset := sc.handle.ClientSet()
	namespace, err := clientset.CoreV1().Namespaces().Get(ctx, pod.GetNamespace(), metav1.GetOptions{})
	if err != nil {
		return framework.NewStatus(framework.UnschedulableAndUnresolvable, "unable to fetch namespace resource")
	}

	if isSpoofedNamespace(namespace) {
		// check if pod should be schedulable
		if checkSpoofedExcludedPod(namespace, pod) {
			if ! isSpoofedNode(node){
				return nil
			} else {
				errReason := fmt.Sprintf("SpoofedNamespace %s listed pod %s as excluded but node %s is spoofed", namespace.GetName(), pod.GetName(), node.GetName())
				return framework.NewStatus(framework.UnschedulableAndUnresolvable, errReason)
			}
		}

		// if both namespace and node are spoofed then schedule pod
		if isSpoofedNode(node) {
			return nil
		} else {
			errReason := fmt.Sprintf("SpoofedNamespace %s but node %s is real", namespace.GetName(), node.GetName())
			return framework.NewStatus(framework.UnschedulableAndUnresolvable, errReason)
		}
	} else {
		if isSpoofedNode(node) {
			errReason := fmt.Sprintf("Namespace %s is real but node %s is spoofed", namespace.GetName(), node.GetName())
			return framework.NewStatus(framework.UnschedulableAndUnresolvable, errReason)
		}
	}
	
	return nil
}


// New initializes a new plugin and returns it.
func New(_ runtime.Object, h framework.Handle) (framework.Plugin, error) {
	return &SpoofControl{handle: h}, nil
}


/*
3 * Helper Functions
3 */
func isSpoofedNamespace(namespace *v1.Namespace) bool {
	annotations := namespace.GetAnnotations()
	if val, ok := annotations["spoofed"]; ok {
		return val == "true"
	}
	return false
}

func isSpoofedNode(node *v1.Node) bool {
	annotations := node.GetAnnotations()
	if val, ok := annotations["spoofed"]; ok {
		return val == "true"
	}
	return false
}

func checkSpoofedExcludedPod(namespace *v1.Namespace, pod *v1.Pod) bool {
	name := pod.GetName()

	if excluded_string, ok := namespace.GetAnnotations()["spoofed_excluded_pods"]; ok {
		excluded_list := strings.Split(excluded_string, ",")
		return stringOrRegexInSlice(name, excluded_list)
	}
	return false
}

func stringOrRegexInSlice(a string, list []string) bool {
    for _, b := range list {
        if b == a {
            return true
        }
		match, _ := regexp.MatchString(b, a)
		if match {
			return true
		}
    }
    return false
}