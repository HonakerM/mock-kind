package pods

import (
	"encoding/json"
	//"math/rand"
	"github.com/douglasmakey/admissioncontroller/pkg/admissioncontroller"

	admissionv1 "k8s.io/api/admission/v1"
	v1 "k8s.io/api/core/v1"
)

// NewMutationHook creates a new instance of pods mutation hook
func NewMutationHook() admissioncontroller.Hook {
	return admissioncontroller.Hook{
		Create: mutateCreate(),
	}
}

// mutateCreate handles creating the handler
func mutateCreate() admissioncontroller.AdmitFunc {
	return func(r *admissionv1.AdmissionRequest) (*admissioncontroller.Result, error) {
		var operations []admissioncontroller.PatchOperation
		pod, err := parsePod(r.Object.Raw)
		if err != nil {
			return &admissioncontroller.Result{Msg: err.Error()}, nil
		}

		// if RunAsNonRoot is set but no user supplied then generate random user id
		psc := pod.Spec.SecurityContext
		if psc.RunAsNonRoot!=nil && *psc.RunAsNonRoot == true {
			operations = append(operations, admissioncontroller.ReplacePatchOperation("/spec/securityContext/runAsNonRoot", false))

			//manual fix for catalgo
			if psc.RunAsUser!=nil && *psc.RunAsUser == 1001 {
				operations = append(operations, admissioncontroller.ReplacePatchOperation("/spec/securityContext/runAsUser", 0))
			}
		}

		var containers []v1.Container
		for _, container := range pod.Spec.Containers {
			new_container := container.DeepCopy()
			csc := container.SecurityContext 
			if csc.RunAsNonRoot!=nil && *csc.RunAsNonRoot == true {
				updatedRunAsRoot := false
				new_container.SecurityContext.RunAsNonRoot = &updatedRunAsRoot
			}
			containers = append(containers, *new_container)
		}
		operations = append(operations, admissioncontroller.ReplacePatchOperation("/spec/containers", containers))



		/*
		if psc.RunAsNonRoot!=nil && *psc.RunAsNonRoot == true && psc.RunAsUser == nil {
			uid := rand.Int63n(2147483647)
			operations = append(operations, admissioncontroller.AddPatchOperation("/spec/securityContext/runAsUser", uid))
			operations = append(operations, admissioncontroller.AddPatchOperation("/spec/securityContext/fsGroup", uid))
		}

		if psc.FSGroup ==nil && *psc.RunAsUser != nil {
			operations = append(operations, admissioncontroller.AddPatchOperation("/spec/securityContext/fsGroup", psc.RunAsUser))
		}*/


		return &admissioncontroller.Result{
			Allowed:  true,
			PatchOps: operations,
		}, nil
	}
}

func parsePod(object []byte) (*v1.Pod, error) {
	var pod v1.Pod
	if err := json.Unmarshal(object, &pod); err != nil {
		return nil, err
	}

	return &pod, nil
}
