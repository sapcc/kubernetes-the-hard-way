# Bootstrapping a H/A etcd cluster

In this lab you will bootstrap a 3 node etcd cluster. The following virtual machines will be used:

* master0 
* master1
* master2

## Why

All Kubernetes components are stateless which greatly simplifies managing a Kubernetes cluster. All state is stored
in etcd, which is a database and must be treated specially. To limit the number of compute resource to complete this lab etcd is being installed on the Kubernetes controller nodes, although some people will prefer to run etcd on a dedicated set of machines for the following reasons:

* The etcd lifecycle is not tied to Kubernetes. We should be able to upgrade etcd independently of Kubernetes.
* Scaling out etcd is different than scaling out the Kubernetes Control Plane.
* Prevent other applications from taking up resources (CPU, Memory, I/O) required by etcd.

However, all the e2e tested configurations currently run etcd on the master nodes.

## Provision the etcd Cluster

Run the following commands on `master0`, `master1`, `master2`:

### TLS Certificates

The TLS certificates created in the [Setting up a CA and TLS Cert Generation](02-certificate-authority.md) lab will be used to secure communication between the Kubernetes API server and the etcd cluster. The TLS certificates will also be used to limit access to the etcd cluster using TLS client authentication. Only clients with a TLS certificate signed by a trusted CA will be able to access the etcd cluster.

Copy the TLS certificates to the etcd configuration directory:

```
sudo mkdir -p /etc/etcd/
```

```
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```

### Setup the Kubelet Service

On every host we will deploy and control all components with containers. To orchestrate startup and liveness we will rely on the Kubernetes `kubelet` as
supervisor.

```
cat > kubelet.service <<EOF
[Service]
Environment=KUBELET_IMAGE_TAG=v1.6.1_coreos.0
Environment="RKT_RUN_ARGS=--volume=resolv,kind=host,source=/etc/resolv.conf \
  --mount volume=resolv,target=/etc/resolv.conf \
  --uuid-file-save=/var/run/kubelet-pod.uuid"
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --pod-manifest-path=/etc/kubernetes/manifests
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
```

Move the service file to the right location
```
sudo cp kubelet.service /etc/systemd/system/
```

Start the kubelet
```
sudo systemctl enable kubelet
sudo systemctl start kubelet
```

### Setup ETCD Data Directory

All etcd data is stored under the etcd data directory. In a production cluster the data directory should be backed by a persistent disk. Create the etcd data directory:

```
sudo mkdir -p /var/lib/etcd
```

### Set The Internal IP Address

The internal IP address will be used by etcd to serve client requests and communicate with other etcd peers.

```
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name:

```
ETCD_NAME=master$(echo $INTERNAL_IP | cut -c 11)
```

Create the manifest file:

```
sudo mkdir -p /etc/kubernetes/manifests
cat > etcd.manifest << EOF
apiVersion: v1
kind: Pod
metadata:
  name: etcd
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: etcd-etcd
      hostPath:
        path: /etc/etcd
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
          value: /etc/etcd/kubernetes.pem
        - name: ETCD_KEY_FILE
          value: /etc/etcd/kubernetes-key.pem
        - name: ETCD_CLIENT_CERT_AUTH
          value: "true"
        - name: ETCD_TRUSTED_CA_FILE
          value: /etc/etcd/ca.pem
        - name: ETCD_PEER_CERT_FILE
          value: /etc/etcd/kubernetes.pem
        - name: ETCD_PEER_KEY_FILE
          value: /etc/etcd/kubernetes-key.pem
        - name: ETCD_PEER_CLIENT_CERT_AUTH
          value: "true"
        - name: ETCD_PEER_TRUSTED_CA_FILE
          value: /etc/etcd/ca.pem
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
        - name: etcd-etcd
          mountPath: /etc/etcd
EOF
sudo mv etcd.manifest /etc/kubernetes/manifests/
```

> Remember to run these steps on `master0`, `master1`, and `master2`

## Verification

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
