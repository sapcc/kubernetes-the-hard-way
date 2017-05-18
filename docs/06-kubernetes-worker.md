# Bootstrapping Kubernetes Workers

In this lab you will bootstrap 3 Kubernetes worker nodes. The following virtual machines will be used:

* minion0 
* minion1 
* minion2

## Why

Kubernetes worker nodes are responsible for running your containers. All Kubernetes clusters need one or more worker nodes. We are running the worker nodes on dedicated machines for the following reasons:

* Ease of deployment and configuration
* Avoid mixing arbitrary workloads with critical cluster components. We are building machine with just enough resources so we don't have to worry about wasting resources.

Some people would like to run workers and cluster services anywhere in the cluster. This is totally possible, and you'll have to decide what's best for your environment.

## Prerequisites

Each worker node will provision a unique TLS client certificate as defined in the [kubelet TLS bootstrapping guide](https://kubernetes.io/docs/admin/kubelet-tls-bootstrapping/). The `kubelet-bootstrap` user must be granted permission to request a client TLS certificate. 

Enable TLS bootstrapping by binding the `kubelet-bootstrap` user to the `system:node-bootstrapper` cluster role:

```
kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap
```

## Install the Kubelet

Run the following commands on `minion0`, `minion1`, `minion2`:

### Prepare Config

```
sudo mkdir -p /etc/kubernetes/manifests
sudo cp * /etc/kubernetes
```

### Setup the Kubelet Service

```
cat > kubelet.service <<EOF
[Unit]
After=docker.service
Requires=docker.service
[Service]
Environment=KUBELET_IMAGE_TAG=v1.6.3_coreos.0
Environment="RKT_RUN_ARGS=--volume=resolv,kind=host,source=/etc/resolv.conf \
  --mount volume=resolv,target=/etc/resolv.conf \
  --volume=var-log,kind=host,source=/var/log \
  --mount volume=var-log,target=/var/log \
  --uuid-file-save=/var/run/kubelet-pod.uuid"
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --cloud-config=/etc/kubernetes/openstack.config \
  --cloud-provider=openstack \
  --allow-privileged=true \
  --network-plugin=kubenet \
  --require-kubeconfig \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --kubeconfig=/etc/kubernetes/minion.kubeconfig \
  --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \
  --cert-dir=/etc/kubernetes
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
sudo cp kubelet.service /etc/systemd/system/
```

Start the kubelet:
```
sudo systemctl enable kubelet
sudo systemctl start kubelet
```

### Setup the kube-proxy Manifest

```
cat > kube-proxy.manifest <<EOF
apiVersion: v1
kind: Pod
metadata: 
  name: kube-proxy
  namespace: kube-system
spec: 
  hostNetwork: true
  volumes:
    - name: etc-kubernetes
      hostPath:
        path: /etc/kubernetes
  containers: 
    - name: proxy 
      image: quay.io/coreos/hyperkube:v1.6.3_coreos.0
      args: 
        - /hyperkube
        - proxy 
        - --cluster-cidr=10.180.128.0/17 
        - --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig
        - --masquerade-all 
      livenessProbe:
        httpGet:
          host: 127.0.0.1 
          path: /healthz
          port: 10249
        initialDelaySeconds: 15
        timeoutSeconds: 1
      volumeMounts:
        - mountPath: /etc/kubernetes
          name: etc-kubernetes
          readOnly: true
      securityContext:
        privileged: true
EOF
sudo mv kube-proxy.manifest /etc/kubernetes/manifests
```

> Remember to run these steps on `minion0`, `minion1`, and `minion2`

## Approve the TLS certificate requests

Each worker node will submit a certificate signing request which must be approved before the node is allowed to join the cluster.

List the pending certificate requests:

```
kubectl get csr
```

```
NAME        AGE       REQUESTOR           CONDITION
csr-XXXXX   1m        kubelet-bootstrap   Pending
```

> Use the kubectl describe csr command to view the details of a specific signing request.

Approve each certificate signing request using the `kubectl certificate approve` command:

```
kubectl certificate approve csr-XXXXX
```

```
certificatesigningrequest "csr-XXXXX" approved
```

Once all certificate signing requests have been approved all nodes should be registered with the cluster:

```
kubectl get nodes
```

```
NAME      STATUS    AGE       VERSION
master0   Ready     2h        v1.6.3+coreos.0
master1   Ready     2h        v1.6.3+coreos.0
master2   Ready     2h        v1.6.3+coreos.0
minion0   Ready     3m        v1.6.3+coreos.0
minion1   Ready     2m        v1.6.3+coreos.0
minion2   Ready     1m        v1.6.3+coreos.0
```
