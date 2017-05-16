# Kubelet Installation

On every host we will deploy and control all components with containers. To
orchestrate startup and liveness we will rely on the Kubernetes `kubelet` as
supervisor.

We are going to setup the Kubelet for:

* master0 
* master1
* master2
* minion0
* minion1
* minion2

Run the following commands on `master0`, `master1`, `master2`, `minion0`,
`minion1`, `minion2`:

```
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

## Prepare Config

```
sudo mkdir -p /etc/kubernetes/manifests
sudo cp * /etc/kubernetes
```

## Setup the Kubelet Service

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
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \
  --require-kubeconfig \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --register-with-taints=node-role.kubernetes.io/master=:NoSchedule 
  --network-plugin=kubenet 
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
