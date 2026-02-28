# 01-k8s-knowledge-checklist

Чеклист для отметки понимания после занятий.
Отмечайте пункт только если можете объяснить и применить его на практике.

## 0. Linux и container runtime

### Базовый уровень
- [ ] Linux namespaces
- [ ] cgroups
- [ ] cgroup v2
- [ ] capabilities
- [ ] seccomp
- [ ] overlayfs
- [ ] containerd
- [ ] CRI
- [ ] OCI image
- [ ] image layers
- [ ] image registry
- [ ] image digest
- [ ] image tag
- [ ] iptables
- [ ] nftables
- [ ] conntrack
- [ ] routing table
- [ ] DNS resolver
- [ ] /etc/resolv.conf
- [ ] kubectl
- [ ] crictl
- [ ] ctr

### Продвинутый уровень
- [ ] user namespaces
- [ ] mount propagation
- [ ] seccomp-bpf filtering modes
- [ ] eBPF
- [ ] XDP
- [ ] tc
- [ ] ip rule
- [ ] policy routing
- [ ] IPVS (механизм)
- [ ] overlay network (VXLAN)
- [ ] overlay network (Geneve)
- [ ] MTU
- [ ] ARP
- [ ] gratuitous ARP
- [ ] netfilter internals

## 1. Архитектура Kubernetes

### Базовый уровень
- [ ] Kubernetes API
- [ ] kube-apiserver
- [ ] etcd
- [ ] kube-scheduler
- [ ] kube-controller-manager
- [ ] cloud-controller-manager
- [ ] kubelet
- [ ] kube-proxy
- [ ] CNI plugin
- [ ] CoreDNS
- [ ] container runtime
- [ ] control plane node
- [ ] worker node
- [ ] static pod
- [ ] component health endpoints

### Продвинутый уровень
- [ ] API aggregation layer
- [ ] API Priority and Fairness
- [ ] feature gates
- [ ] component config
- [ ] leader election
- [ ] controller-runtime library
- [ ] kubelet eviction manager
- [ ] kubelet pod lifecycle manager

## 2. API machinery и декларативная модель

### Базовый уровень
- [ ] desired state
- [ ] observed state
- [ ] reconciliation loop
- [ ] Kubernetes object
- [ ] metadata
- [ ] labels
- [ ] annotations
- [ ] selectors
- [ ] kind
- [ ] API group
- [ ] API version
- [ ] watch
- [ ] list
- [ ] server-side apply

### Продвинутый уровень
- [ ] finalizers
- [ ] ownerReferences
- [ ] generation
- [ ] resourceVersion
- [ ] UID
- [ ] OpenAPI schema
- [ ] admission chain
- [ ] mutating admission
- [ ] validating admission
- [ ] patch (strategic/merge/json)
- [ ] informer
- [ ] controller pattern
- [ ] optimistic concurrency control
- [ ] conflict handling
- [ ] managedFields
- [ ] field manager
- [ ] subresources
- [ ] status vs spec separation
- [ ] garbage collector
- [ ] propagationPolicy

## 3. Core ресурсы

### Базовый уровень
- [ ] Namespace
- [ ] Pod
- [ ] Service
- [ ] ConfigMap
- [ ] Secret
- [ ] ServiceAccount
- [ ] Node
- [ ] Event
- [ ] ResourceQuota
- [ ] LimitRange
- [ ] PersistentVolume
- [ ] PersistentVolumeClaim

### Продвинутый уровень
- [ ] Endpoints
- [ ] EndpointSlice
- [ ] Endpoints deprecation/migration to EndpointSlice
- [ ] Service topology
- [ ] Headless + Stateful DNS behavior
- [ ] NodeLease
- [ ] PodSecurityContext
- [ ] RuntimeClass
- [ ] ReplicationController
- [ ] PodTemplate
- [ ] Binding
- [ ] Lease

## 4. Workloads и controllers

### Базовый уровень
- [ ] ReplicaSet
- [ ] Deployment
- [ ] StatefulSet
- [ ] DaemonSet
- [ ] Job
- [ ] CronJob
- [ ] rollout
- [ ] rollout history
- [ ] rollout undo

### Продвинутый уровень
- [ ] ControllerRevision
- [ ] HorizontalPodAutoscaler
- [ ] VerticalPodAutoscaler
- [ ] PodDisruptionBudget
- [ ] maxSurge
- [ ] maxUnavailable
- [ ] revisionHistoryLimit
- [ ] updateStrategy
- [ ] partition update
- [ ] progressDeadlineSeconds
- [ ] minReadySeconds
- [ ] maxUnavailable in StatefulSet
- [ ] orderedReady pod management
- [ ] parallel pod management
- [ ] suspend (Job)
- [ ] suspend (CronJob)
- [ ] backoffLimit
- [ ] ttlSecondsAfterFinished

## 5. Pod internals

### Базовый уровень
- [ ] initContainers
- [ ] sidecar containers
- [ ] restartPolicy
- [ ] imagePullPolicy
- [ ] command/args
- [ ] env
- [ ] envFrom
- [ ] Downward API
- [ ] lifecycle hooks
- [ ] postStart hook
- [ ] preStop hook
- [ ] terminationGracePeriodSeconds
- [ ] readinessProbe
- [ ] livenessProbe
- [ ] startupProbe
- [ ] container states
- [ ] Pod phase

### Продвинутый уровень
- [ ] ephemeral containers
- [ ] QoS class
- [ ] OOMKilled
- [ ] shareProcessNamespace
- [ ] hostAliases
- [ ] termination message policy
- [ ] container restart backoff
- [ ] imagePullSecrets resolution order
- [ ] PodOverhead

## 6. Networking и доступ

### Базовый уровень
- [ ] Pod-to-Pod networking
- [ ] Pod-to-Service networking
- [ ] ClusterIP
- [ ] NodePort
- [ ] LoadBalancer Service
- [ ] ExternalName Service
- [ ] headless Service
- [ ] service discovery
- [ ] Ingress
- [ ] IngressClass
- [ ] ingress-nginx
- [ ] NetworkPolicy
- [ ] ingress rules
- [ ] egress rules

### Продвинутый уровень
- [ ] kube-proxy iptables mode
- [ ] kube-proxy IPVS mode
- [ ] kube-dns vs CoreDNS
- [ ] DNS policy
- [ ] DNS config
- [ ] stub domains
- [ ] ndots
- [ ] cluster DNS search path
- [ ] hairpin mode
- [ ] externalTrafficPolicy
- [ ] internalTrafficPolicy
- [ ] service session affinity
- [ ] nodeLocal DNS cache
- [ ] dual stack IPv4/IPv6
- [ ] namespaceSelector
- [ ] podSelector
- [ ] ipBlock
- [ ] TLS secret

## 7. Gateway API

### Базовый уровень
- [ ] GatewayClass
- [ ] Gateway
- [ ] HTTPRoute

### Продвинутый уровень
- [ ] GRPCRoute
- [ ] TCPRoute
- [ ] UDPRoute
- [ ] TLSRoute
- [ ] ReferenceGrant

## 8. Storage

### Базовый уровень
- [ ] volume
- [ ] emptyDir
- [ ] hostPath
- [ ] configMap volume
- [ ] secret volume
- [ ] StorageClass
- [ ] accessModes
- [ ] ReadWriteOnce
- [ ] ReadWriteMany
- [ ] ReadOnlyMany
- [ ] local PersistentVolume
- [ ] NFS volume
- [ ] StatefulSet volumeClaimTemplates

### Продвинутый уровень
- [ ] projected volume
- [ ] CSI
- [ ] CSIDriver
- [ ] CSINode
- [ ] CSIStorageCapacity
- [ ] VolumeAttachment
- [ ] CSI external components
- [ ] external-provisioner
- [ ] external-attacher
- [ ] external-resizer
- [ ] inline ephemeral volumes
- [ ] volume expansion
- [ ] topology aware provisioning
- [ ] reclaimPolicy
- [ ] volumeMode
- [ ] filesystem volume mode
- [ ] block volume mode
- [ ] raw block devices
- [ ] volumeBindingMode
- [ ] WaitForFirstConsumer
- [ ] fsGroupChangePolicy
- [ ] VolumeSnapshot
- [ ] VolumeSnapshotClass
- [ ] VolumeSnapshotContent

## 9. Scheduling и ресурсы

### Базовый уровень
- [ ] nodeSelector
- [ ] node affinity
- [ ] pod affinity
- [ ] pod anti-affinity
- [ ] taints
- [ ] tolerations
- [ ] requests
- [ ] limits
- [ ] ResourceQuota scopes
- [ ] LimitRange defaults
- [ ] cordon
- [ ] drain
- [ ] uncordon

### Продвинутый уровень
- [ ] scheduler profiles
- [ ] scoring plugins
- [ ] scheduling framework
- [ ] extender
- [ ] descheduler
- [ ] topologySpreadConstraints
- [ ] PriorityClass
- [ ] preemption
- [ ] eviction
- [ ] node pressure eviction
- [ ] memory pressure
- [ ] disk pressure
- [ ] PID pressure
- [ ] topology manager
- [ ] NUMA awareness
- [ ] hugepages
- [ ] Cluster Autoscaler
- [ ] HPA metrics

## 10. Конфигурация и секреты

### Базовый уровень
- [ ] ConfigMap
- [ ] Secret
- [ ] stringData
- [ ] data (base64)
- [ ] imagePullSecrets
- [ ] projected ServiceAccount token

### Продвинутый уровень
- [ ] immutable ConfigMap
- [ ] immutable Secret
- [ ] TokenRequest API
- [ ] envelope encryption
- [ ] KMS provider
- [ ] etcd encryption at rest
- [ ] secret rotation
- [ ] projected token expiration
- [ ] external secrets
- [ ] sealed secrets
- [ ] SOPS

## 11. Security и policy

### Базовый уровень
- [ ] RBAC
- [ ] Role
- [ ] ClusterRole
- [ ] RoleBinding
- [ ] ClusterRoleBinding
- [ ] Pod Security Admission
- [ ] baseline profile
- [ ] restricted profile
- [ ] runAsNonRoot
- [ ] runAsUser
- [ ] runAsGroup
- [ ] fsGroup
- [ ] readOnlyRootFilesystem
- [ ] allowPrivilegeEscalation
- [ ] seccompProfile

### Продвинутый уровень
- [ ] impersonation
- [ ] SubjectAccessReview
- [ ] privileged profile
- [ ] supplementalGroups
- [ ] privileged container
- [ ] hostNetwork
- [ ] hostPID
- [ ] hostIPC
- [ ] procMount
- [ ] capabilities drop/add
- [ ] NetworkPolicy default deny
- [ ] image policy webhook
- [ ] ValidatingAdmissionPolicy
- [ ] ValidatingAdmissionPolicyBinding
- [ ] MutatingWebhookConfiguration
- [ ] ValidatingWebhookConfiguration
- [ ] audit policy
- [ ] audit log
- [ ] certificate signing request
- [ ] workload identity
- [ ] SPIFFE
- [ ] SPIRE
- [ ] mTLS
- [ ] service account issuer
- [ ] bound service account tokens
- [ ] seccomp default profile
- [ ] rootless containers
- [ ] supply chain security
- [ ] cosign
- [ ] SBOM
- [ ] image signature verification

## 12. Наблюдаемость и диагностика

### Базовый уровень
- [ ] kubectl logs
- [ ] kubectl describe
- [ ] kubectl events
- [ ] Pod conditions
- [ ] Deployment conditions
- [ ] Node conditions
- [ ] metrics-server
- [ ] runbook

### Продвинутый уровень
- [ ] kube-state-metrics
- [ ] Prometheus
- [ ] Alertmanager
- [ ] Grafana
- [ ] OpenTelemetry
- [ ] tracing
- [ ] log aggregation
- [ ] structured logging
- [ ] RED metrics
- [ ] USE metrics
- [ ] exemplars
- [ ] distributed tracing context propagation
- [ ] eBPF observability
- [ ] log sampling
- [ ] structured events
- [ ] event rate limiting
- [ ] SLI
- [ ] SLO
- [ ] SLA
- [ ] MTTR
- [ ] MTBF

## 13. Расширяемость Kubernetes

### Базовый уровень
- [ ] CustomResourceDefinition (CRD)
- [ ] custom controller
- [ ] Operator pattern
- [ ] status subresource
- [ ] scale subresource

### Продвинутый уровень
- [ ] APIService aggregation
- [ ] conversion webhook
- [ ] apiextensions.k8s.io
- [ ] controller-runtime
- [ ] Kubebuilder
- [ ] admission webhook TLS handling
- [ ] CRD versioning strategy
- [ ] storage version migration

## 14. Helm, Kustomize, GitOps

### Базовый уровень
- [ ] Helm chart
- [ ] Chart.yaml
- [ ] values.yaml
- [ ] templates/
- [ ] helm lint
- [ ] helm template
- [ ] helm upgrade --install
- [ ] Kustomization
- [ ] base
- [ ] overlay
- [ ] Argo CD
- [ ] Application (Argo CD)
- [ ] AppProject (Argo CD)

### Продвинутый уровень
- [ ] helper templates
- [ ] named templates
- [ ] helm rollback
- [ ] patchStrategicMerge
- [ ] patchesJson6902
- [ ] sync policy
- [ ] prune
- [ ] self-heal
- [ ] Flux
- [ ] drift detection
- [ ] app-of-apps pattern
- [ ] sync waves
- [ ] hooks (Argo CD)
- [ ] health checks customization
- [ ] progressive delivery
- [ ] canary deployment
- [ ] blue-green deployment
- [ ] Argo Rollouts

## 15. kubeadm и lifecycle кластера

### Базовый уровень
- [ ] kubeadm init
- [ ] kubeadm join
- [ ] kubeadm upgrade plan
- [ ] kubeadm upgrade apply
- [ ] kubeadm certs check-expiration
- [ ] kubeadm certs renew
- [ ] kubeadm reset
- [ ] kubeconfig
- [ ] admin.conf
- [ ] controller-manager.conf
- [ ] scheduler.conf
- [ ] kubelet.conf
- [ ] /etc/kubernetes/manifests
- [ ] /var/lib/kubelet/config.yaml

### Продвинутый уровень
- [ ] bootstrap tokens
- [ ] etcd snapshot
- [ ] etcd restore
- [ ] version skew policy
- [ ] maintenance window
- [ ] control plane HA
- [ ] stacked etcd
- [ ] external etcd
- [ ] etcd compaction
- [ ] etcd defragmentation
- [ ] certificate rotation automation
- [ ] kubelet serving cert rotation

## 16. Экосистема и платформенные компоненты

### Базовый уровень
- [ ] ingress-nginx
- [ ] cert-manager
- [ ] external-dns
- [ ] metallb
- [ ] Calico
- [ ] Flannel
- [ ] local-path-provisioner

### Продвинутый уровень
- [ ] Cilium
- [ ] Velero
- [ ] Kyverno
- [ ] Gatekeeper (OPA)
- [ ] Istio
- [ ] Linkerd
- [ ] service mesh
- [ ] Argo Rollouts
- [ ] Crossplane
- [ ] External Secrets Operator
- [ ] KEDA
- [ ] Open Policy Agent standalone
- [ ] Falco
- [ ] Trivy
- [ ] Harbor

## 17. Incident-сценарии

### Базовый уровень
- [ ] CrashLoopBackOff
- [ ] ImagePullBackOff
- [ ] ErrImagePull
- [ ] CreateContainerConfigError
- [ ] CreateContainerError
- [ ] Pending (Insufficient CPU)
- [ ] Pending (Insufficient memory)
- [ ] Pending (taint mismatch)
- [ ] Readiness probe failed
- [ ] Liveness probe failed
- [ ] OOMKilled
- [ ] DNS resolution failure
- [ ] Service without endpoints
- [ ] Ingress 404
- [ ] Ingress 502
- [ ] Ingress 504
- [ ] TLS handshake error
- [ ] Node NotReady
- [ ] Evicted pod
- [ ] FailedScheduling

### Продвинутый уровень
- [ ] etcd quorum loss
- [ ] etcd disk full
- [ ] certificate expired
- [ ] API server high latency
- [ ] controller manager crash
- [ ] kubelet not posting node status
- [ ] CNI misconfiguration
- [ ] MTU mismatch
- [ ] conntrack table full
- [ ] DNS ndots latency spike
- [ ] runaway HPA
- [ ] stuck finalizer
- [ ] orphaned resources
- [ ] version skew issue

## 18. Platform engineering и multi-cluster

### Базовый уровень
- [ ] multi-cluster networking
- [ ] fleet management
- [ ] GitOps multi-cluster
- [ ] backup strategy
- [ ] disaster recovery strategy

### Продвинутый уровень
- [ ] cluster federation
- [ ] Cluster API
- [ ] workload migration
- [ ] cross-cluster policy management
- [ ] global traffic management
