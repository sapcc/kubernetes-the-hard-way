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

On every host we will deploy and control all components with containers. To
orchestrate startup and liveness we will rely on the Kubernetes `kubelet` as
supervisor.

Run the following commands on `master0`, `master1`, `master2`:

```
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

### Prepare Config

```
sudo mkdir -p /etc/kubernetes/manifests
sudo cp * /etc/kubernetes
```

### Setup the Kubelet Service

```
cat > kubelet.service <<EOF
[Service]
Environment=KUBELET_IMAGE_TAG=v1.6.3_coreos.0
Environment="RKT_RUN_ARGS=--volume=resolv,kind=host,source=/etc/resolv.conf \
  --mount volume=resolv,target=/etc/resolv.conf \
  --uuid-file-save=/var/run/kubelet-pod.uuid"
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --cloud-config=/etc/kubernetes/openstack.config \
  --cloud-provider=openstack \
  --network-plugin=kubenet \
  --require-kubeconfig \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --kubeconfig=/etc/kubernetes/master.kubeconfig \
  --register-with-taints=node-role.kubernetes.io/master=:NoSchedule 
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
sudo cp kubelet.service /etc/systemd/system/
```

Start the kubelet
```
sudo systemctl enable kubelet
sudo systemctl start kubelet
```

### Provision Etcd 

All Kubernetes components are stateless which greatly simplifies managing a Kubernetes cluster. All state is stored
in etcd, which is a database and must be treated specially. To limit the number of compute resource to complete this lab etcd is being installed on the Kubernetes controller nodes, although some people will prefer to run etcd on a dedicated set of machines for the following reasons:

* The etcd lifecycle is not tied to Kubernetes. We should be able to upgrade etcd independently of Kubernetes.
* Scaling out etcd is different than scaling out the Kubernetes Control Plane.
* Prevent other applications from taking up resources (CPU, Memory, I/O) required by etcd.

However, all the e2e tested configurations currently run etcd on the master nodes.

#### Setup ETCD Data Directory

All etcd data is stored under the etcd data directory. In a production cluster the data directory should be backed by a persistent disk. Create the etcd data directory:

```
sudo mkdir -p /var/lib/etcd
```

#### Set The Internal IP Address

Each etcd member must have a unique name within an etcd cluster. Set the etcd name:

```
ETCD_NAME=master$(echo $INTERNAL_IP | cut -c 11)
```

Create the manifest file:

```
cat > etcd.manifest << EOF
apiVersion: v1
kind: Pod
metadata:
  name: etcd
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: etc-kubernetes
      hostPath:
        path: /etc/kubernetes
    - name: var-lib-etcd
      hostPath:
        path: /var/lib/etcd
  containers:
    - name: etcd
      image: quay.io/coreos/etcd:v3.1.4
      env:
        - name: ETCD_NAME
          value: ${ETCD_NAME}
        - name: ETCD_DATA_DIR
          value: /var/lib/etcd
        - name: ETCD_INITIAL_CLUSTER
          value: master0=https://10.180.0.10:2380,master1=https://10.180.0.11:2380,master2=https://10.180.0.12:2380
        - name: ETCD_INITIAL_CLUSTER_TOKEN
          value: kubernetes-the-hard-way
        - name: ETCD_INITIAL_ADVERTISE_PEER_URLS
          value: https://${INTERNAL_IP}:2380
        - name: ETCD_ADVERTISE_CLIENT_URLS
          value: https://${INTERNAL_IP}:2379
        - name: ETCD_LISTEN_PEER_URLS
          value: https://${INTERNAL_IP}:2380
        - name: ETCD_LISTEN_CLIENT_URLS
          value: http://127.0.0.1:2379,https://${INTERNAL_IP}:2379
        - name: ETCD_CERT_FILE
          value: /etc/kubernetes/kubernetes.pem
        - name: ETCD_KEY_FILE
          value: /etc/kubernetes/kubernetes-key.pem
        - name: ETCD_CLIENT_CERT_AUTH
          value: "true"
        - name: ETCD_TRUSTED_CA_FILE
          value: /etc/kubernetes/ca.pem
        - name: ETCD_PEER_CERT_FILE
          value: /etc/kubernetes/kubernetes.pem
        - name: ETCD_PEER_KEY_FILE
          value: /etc/kubernetes/kubernetes-key.pem
        - name: ETCD_PEER_CLIENT_CERT_AUTH
          value: "true"
        - name: ETCD_PEER_TRUSTED_CA_FILE
          value: /etc/kubernetes/ca.pem
      livenessProbe:
        httpGet:
          host: 127.0.0.1
          path: /health
          port: 2379
          initialDelaySeconds: 300
          timeoutSeconds: 5
      volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
EOF
sudo mv etcd.manifest /etc/kubernetes/manifests/
```

#### Verification

Once all 3 etcd nodes have been bootstrapped verify the etcd cluster is healthy:

* On one of the controller nodes run the following command:

```
sudo etcdctl \
  --ca-file=/etc/etcd/ca.pem \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  cluster-health
```

```
member 3a57933972cb5131 is healthy: got healthy result from https://10.240.0.12:2379
member f98dc20bce6225a0 is healthy: got healthy result from https://10.240.0.10:2379
member ffed16798470cab5 is healthy: got healthy result from https://10.240.0.11:2379
cluster is healthy
```

### Kubernetes API Server

Capture the internal IP address of the machine:

```
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

Create the manifest file:

```
cat > apiserver.manifest << EOF
apiVersion: v1
kind: Pod
metadata:
  name: apiserver 
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: etc-kubernetes
      hostPath:
        path: /etc/kubernetes
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
        - --client-ca-file=/etc/kubernetes/ca.pem
        - --enable-swagger-ui=true
        - --etcd-cafile=/etc/kubernetes/ca.pem 
        - --etcd-certfile=/etc/kubernetes/kubernetes.pem
        - --etcd-keyfile=//etc/kubernetes/kubernetes-key.pem 
        - --etcd-servers=https://10.180.0.10:2379,https://10.180.0.11:2379,https://10.180.0.12:2379
        - --event-ttl=1h 
        - --experimental-bootstrap-token-auth 
        - --insecure-bind-address=0.0.0.0
        - --kubelet-certificate-authority=/etc/kubernetes/ca.pem 
        - --kubelet-client-certificate=/etc/kubernetes/kubernetes.pem 
        - --kubelet-client-key=/etc/kubernetes/kubernetes-key.pem 
        - --kubelet-https=true 
        - --runtime-config=rbac.authorization.k8s.io/v1alpha1 
        - --service-account-key-file=/etc/kubernetes/ca-key.pem 
        - --service-cluster-ip-range=10.180.1.0/24 
        - --service-node-port-range=30000-32767 
        - --tls-cert-file=/etc/kubernetes/kubernetes.pem 
        - --tls-private-key-file=/etc/kubernetes/kubernetes-key.pem 
        - --token-auth-file=/etc/kubernetes/token.csv 
        - --cloud-config=/etc/kubernetes/openstack.config 
        - --cloud-provider=openstack 
      livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 8080
        initialDelaySeconds: 15
        timeoutSeconds: 1
      volumeMounts:
        - mountPath: /etc/kubernetes
          name: etc-kubernetes
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
    - name: etc-kubernetes
      hostPath:
        path: /etc/kubernetes
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
        - --cluster-signing-cert-file=/etc/kubernetes/ca.pem 
        - --cluster-signing-key-file=/etc/kubernetes/ca-key.pem 
        - --leader-elect=true 
        - --master=http://${INTERNAL_IP}:8080 
        - --root-ca-file=/var/lib/kubernetes/ca.pem 
        - --service-cluster-ip-range=10.180.1.0/24
        - --cloud-config=/etc/kubernetes/openstack.config 
        - --cloud-provider=openstack 
      livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 8080
        initialDelaySeconds: 15
        timeoutSeconds: 1
      volumeMounts:
        - mountPath: /etc/kubernetes
          name: etc-kubernetes
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

There should now be 6 containers running:

```
docker ps
CONTAINER ID        IMAGE                                                                                              COMMAND                  CREATED             STATUS              PORTS               NAMES
b49023226e8c        quay.io/coreos/hyperkube@sha256:7ced4a382599959c5734a7df517075045e53257e0b316f24ed3e0c783191d026   "/hyperkube controlle"   16 minutes ago      Up 16 minutes                           k8s_controller-manager_controller-manager-master0_kube-system_d484fa3545b5bb3c4e17cde9feb2052c_0
cf30455aaa36        gcr.io/google_containers/pause-amd64:3.0                                                           "/pause"                 16 minutes ago      Up 16 minutes                           k8s_POD_controller-manager-master0_kube-system_d484fa3545b5bb3c4e17cde9feb2052c_0
4518a60e179a        quay.io/coreos/hyperkube@sha256:7ced4a382599959c5734a7df517075045e53257e0b316f24ed3e0c783191d026   "/hyperkube apiserver"   27 minutes ago      Up 27 minutes                           k8s_apiserver_apiserver-master0_kube-system_88220154ada103f7554889d274a7b2d0_0
48a50a86bd98        gcr.io/google_containers/pause-amd64:3.0                                                           "/pause"                 27 minutes ago      Up 27 minutes                           k8s_POD_apiserver-master0_kube-system_88220154ada103f7554889d274a7b2d0_0
c56b42649123        quay.io/coreos/etcd@sha256:23e46a0b54848190e6a15db6f5b855d9b5ebcd6abd385c80aeba4870121356ec        "/usr/local/bin/etcd"    29 minutes ago      Up 29 minutes                           k8s_etcd_etcd-master0_kube-system_2114fdc971582767170c42a49e73d92b_3
d8ad37ce38f6        gcr.io/google_containers/pause-amd64:3.0                                                           "/pause"                 29 minutes ago      Up 29 minutes                           k8s_POD_etcd-master0_kube-system_2114fdc971582767170c42a49e73d92b_0 
```

Not all containers running? Check with `docker ps -a` if they died unexpectely.
Grab their logs with `docker logs b49023226e8c`. Still nothing? Check the `kubelet` with `journalctl -u kubelet`.


The `kubelets` will register themselves automatically and setup a static route
for their pods. The router should look similar to:

```
neutron router-show $ROUTER_ID
+-------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field                                           | Value                                                                                                                                                  |
+-------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------+
| id                                              | 29635b60-d79f-4536-8144-b2271031461d                                                                                                                   |
| name                                            | kthw-router                                                                                                                                            |
| routes                                          | {"destination": "10.180.131.0/24", "nexthop": "10.180.0.10"}                                                                                           |
|                                                 | {"destination": "10.180.128.0/24", "nexthop": "10.180.0.11"}                                                                                           |
|                                                 | {"destination": "10.180.129.0/24", "nexthop": "10.180.0.12"}                                                                                           |
...
+-------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------+
```


> Remember to run these steps on `master0`, `master1`, and `master2`

## Setup Kubernetes API Server Frontend Load Balancer

Create a load balancer:
```
neutron lbaas-loadbalancer-create --name masters-lb $NETWORK
```

Create and fill the pool with out master nodes:
```
neutron lbaas-pool-create --lb-algorithm ROUND_ROBIN --protocol TCP --name masters-pool --loadbalancer masters-lb
neutron lbaas-member-create --subnet $SUBNET --protocol-port 6443 --address 10.180.0.10 masters-pool
neutron lbaas-member-create --subnet $SUBNET --protocol-port 6443 --address 10.180.0.11 masters-pool
neutron lbaas-member-create --subnet $SUBNET --protocol-port 6443 --address 10.180.0.12 masters-pool
```

Create a health check:
```
neutron lbaas-healthmonitor-create --name masters-health --delay 5 --max-retries 2 --timeout 3 --type TCP --pool masters-pool 
```

Create a listener:
```
neutron lbaas-listener-create --protocol TCP --protocol-port 443 --loadbalancer master --default-pool masters-pool --name masters-listener
```

Attach our previously reserved floating-ip:

```
neutron port-list
+--------------------------------------+----------------------------------------------------------------------------------------+-------------------+------------------------------------------------------------------------------------+
| id                                   | name                                                                                   | mac_address       | fixed_ips                                                                          |
+--------------------------------------+----------------------------------------------------------------------------------------+-------------------+------------------------------------------------------------------------------------+
| 08899903-ca6c-42a0-b210-f8a380dfcd80 | loadbalancer-abb068fc-d6ed-4a81-b424-b95a5f775bcc                                      | fa:16:3e:8b:54:99 | {"subnet_id": "83aab941-87f4-4372-9fbc-9f702092e3cf", "ip_address": "10.180.0.7"}  |
...
+--------------------------------------+----------------------------------------------------------------------------------------+-------------------+------------------------------------------------------------------------------------+


neutron floatingip-list
+--------------------------------------+------------------+---------------------+--------------------------------------+
| id                                   | fixed_ip_address | floating_ip_address | port_id                              |
+--------------------------------------+------------------+---------------------+--------------------------------------+
| cacce782-68b6-4944-87c6-3640c94f7159 |                  | 10.47.40.33         |                                      |
| 9a4bff45-d72c-4777-a5b1-abe5e76de613 | 10.180.0.30      | 10.47.41.49         | 848396d3-5e18-4410-9a7f-949295428e3f |
+--------------------------------------+------------------+---------------------+--------------------------------------+

neutron floatingip-associate cacce782-68b6-4944-87c6-3640c94f7159 08899903-ca6c-42a0-b210-f8a380dfcd80
```

### Verification

```
curl -k https://10.47.40.33/healthz
Unauthorized
```

Using the previously setup `kubectl`, you can now connect to the api.

```
kubectl get nodes 
```

```
NAME      STATUS    AGE       VERSION
master0   Ready     2h        v1.6.3+coreos.0
master1   Ready     36m       v1.6.3+coreos.0
master2   Ready     35m       v1.6.3+coreos.0
```

You can also see the mirrored, static pods:

```
kubectl get pods --namespace=kube-system
```

```
NAMESPACE     NAME                         READY     STATUS    RESTARTS   AGE
kube-system   apiserver-master0            1/1       Running   0          1h
kube-system   apiserver-master1            1/1       Running   0          37m
kube-system   apiserver-master2            1/1       Running   0          36m
kube-system   controller-manager-master0   1/1       Running   0          1h
kube-system   controller-manager-master1   1/1       Running   0          37m
kube-system   controller-manager-master2   1/1       Running   0          36m
kube-system   etcd-master0                 1/1       Running   3          38m
kube-system   etcd-master1                 1/1       Running   0          37m
kube-system   etcd-master2                 1/1       Running   0          36m`
```

As well as grab their logs:
```
kubectl get logs apiserver-master0 --namespace=kube-system
```

Take note that what you see here are mirror pods. They reflect the status of
the static pods which we provisioned with the above manifest files. Modifying
or deleting these "mirrors" will **NOT** change the actual manifest file.
