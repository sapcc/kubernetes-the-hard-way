## Setting up the kubelet

On every host we will deploy and control all components with containers.
To orchestrate startup and liveness we will rely on the kubernetes native way of
doing things.

### Create a service to start our kubelet

```
cat > kubelet.service <<EOF
[Unit]
Description=Start RKT kubelet
After=rpc-statd.service
Requires=rpc-statd.service
[Service]
Environment="KUBELET_VERSION={{.kubernetes.version}}_coreos.0"
Environment="RKT_OPTS=--volume=resolv,kind=host,source=/etc/resolv.conf --mount volume=resolv,target=/etc/resolv.conf"
EnvironmentFile=/etc/metadata
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin:/usr/share/oem/bin
ExecStart=/opt/bin/kubelet-wrapper \
  --address={{.internal_network.address}} \
  --port=10250 \
  --tls-private-key-file=/opt/kubernetes/ssl/kubelet-key.pem \
  --tls-cert-file=/opt/kubernetes/ssl/kubelet.pem \
  --api-servers=https://$KUBERNETES_PUBLIC_ADDRESS \
  --kubeconfig=/opt/kubernetes/config/bootstrap.kubeconfig \
  --allow-privileged=true \
  --host-network-sources="*" \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --register-schedulable=true \
  --max-pods=250
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
```
