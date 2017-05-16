# Bootstrapping an H/A Kubernetes Control Plane

In this lab you will bootstrap a 3 node Kubernetes controller cluster. The following virtual machines will be used:

* master0 
* master1
* master2

In this lab you will also create a frontend load balancer with a public IP address for remote access to the API servers and H/A.

## Why

The Kubernetes components that make up the control plane include the following components:

* API Server
* Scheduler
* Controller Manager

Each component is being run on the same machine for the following reasons:

* The Scheduler and Controller Manager are tightly coupled with the API Server
* Only one Scheduler and Controller Manager can be active at a given time, but it's ok to run multiple at the same time. Each component will elect a leader via the API Server.
* Running multiple copies of each component is required for H/A
* Running each component next to the API Server eases configuration.

## Provision the Kubernetes Controller Cluster

Run the following commands on `master0`, `master1`, `master2`:

> Login to each machine using the gcloud compute ssh command

---

Copy the bootstrap token into place:

```
sudo mkdir -p /var/lib/kubernetes/
```

```
sudo mv token.csv /var/lib/kubernetes/
```

### TLS Certificates

The TLS certificates created in the [Setting up a CA and TLS Cert Generation](02-certificate-authority.md) lab will be used to secure communication between the Kubernetes API server and Kubernetes clients such as `kubectl` and the `kubelet` agent. The TLS certificates will also be used to authenticate the Kubernetes API server to etcd via TLS client auth.

Copy the TLS certificates to the Kubernetes configuration directory:

```
sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
```

### Kubernetes API Server

Capture the internal IP address of the machine:

```
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

Create the manifest file:

```
mkdir -p /etc/kubernetes/manifests
cat > apiserver.manifest << EOF
apiVersion: v1
kind: Pod
metadata:
  name: apiserver 
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: var-lib
      hostPath:
        path: /var/lib
  containers:
    - name: apiserver
      image: quay.io/coreos/hyperkube:v1.6.3_coreos.0
      args:
        - /hyperkube
        - apiserver
        - --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
        - --advertise-address=${INTERNAL_IP}
        - --allow-privileged=true
        - --apiserver-count=3 
        - --audit-log-maxage=30 
        - --audit-log-maxbackup=3 
        - --audit-log-maxsize=100 
        - --audit-log-path=/var/lib/audit.log 
        - --bind-address=0.0.0.0
        - --client-ca-file=/var/lib/kubernetes/ca.pem
        - --enable-swagger-ui=true
        - --etcd-cafile=/var/lib/kubernetes/ca.pem 
        - --etcd-certfile=/var/lib/kubernetes/kubernetes.pem
        - --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem 
        - --etcd-servers=https://10.180.0.10:2379,https://10.180.0.11:2379,https://10.180.0.12:2379
        - --event-ttl=1h 
        - --experimental-bootstrap-token-auth 
        - --insecure-bind-address=0.0.0.0
        - --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem 
        - --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem 
        - --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem 
        - --kubelet-https=true 
        - --runtime-config=rbac.authorization.k8s.io/v1alpha1 
        - --service-account-key-file=/var/lib/kubernetes/ca-key.pem 
        - --service-cluster-ip-range=10.180.1.0/24 
        - --service-node-port-range=30000-32767 
        - --tls-cert-file=/var/lib/kubernetes/kubernetes.pem 
        - --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem 
        - --token-auth-file=/var/lib/kubernetes/token.csv 
      livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 8080
        initialDelaySeconds: 15
        timeoutSeconds: 1
      volumeMounts:
        - mountPath: /var/lib
          name: var-lib
EOF
sudo mv apiserver.manifest /etc/kubernetes/manifests
```


### Kubernetes Controller Manager

```
cat > controller-manager.manifest << EOF
apiVersion: v1
kind: Pod
metadata:
  name: controller-manager 
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: var-lib
      hostPath:
        path: /var/lib
  containers:
    - name: controller-manager 
      image: quay.io/coreos/hyperkube:v1.6.3_coreos.0
      args:
        - /hyperkube
        - controller-manager
        - --address=0.0.0.0
        - --allocate-node-cidrs=true 
        - --cluster-cidr=10.180.128.0/17 
        - --cluster-name=kubernetes 
        - --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem 
        - --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem 
        - --leader-elect=true 
        - --master=http://${INTERNAL_IP}:8080 
        - --root-ca-file=/var/lib/kubernetes/ca.pem 
        - --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem 
        - --service-cluster-ip-range=10.180.1.0/24
      livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 8080
        initialDelaySeconds: 15
        timeoutSeconds: 1
      volumeMounts:
        - mountPath: /var/lib
          name: var-lib
EOF
sudo mv controller-manager.manifest /etc/kubernetes/manifests
```

### Kubernetes Scheduler
```
cat > scheduler.manifest << EOF
apiVersion: v1
kind: Pod
metadata:
  name:  scheduler 
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
    - name: scheduler
      image: quay.io/coreos/hyperkube:v1.6.3_coreos.0
      args:
        - /hyperkube
        - scheduler 
        - --leader-elect=true 
        - --master=http://${INTERNAL_IP}:8080 
      livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 8080
        initialDelaySeconds: 15
        timeoutSeconds: 1
EOF
sudo mv scheduler.manifest /etc/kubernetes/manifests
```

### Verification

```
kubectl get componentstatuses
```

```
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}  
```

> Remember to run these steps on `master0`, `master1`, and `master2`

## Setup Kubernetes API Server Frontend Load Balancer

The virtual machines created in this tutorial will not have permission to complete this section. Run the following commands from the same place used to create the virtual machines for this tutorial.

```
gcloud compute http-health-checks create kube-apiserver-health-check \
  --description "Kubernetes API Server Health Check" \
  --port 8080 \
  --request-path /healthz
```

```
gcloud compute target-pools create kubernetes-target-pool \
  --http-health-check=kube-apiserver-health-check
```

```
gcloud compute target-pools add-instances kubernetes-target-pool \
  --instances controller0,controller1,controller2
```

```
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region us-central1 \
  --format 'value(address)')
```

```
gcloud compute forwarding-rules create kubernetes-forwarding-rule \
  --address ${KUBERNETES_PUBLIC_ADDRESS} \
  --ports 6443 \
  --target-pool kubernetes-target-pool \
  --region us-central1
```
