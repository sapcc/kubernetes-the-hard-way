## Setting up the kubelet

On every host we will deploy and control all components with containers.
To orchestrate startup and liveness we will rely on the kubernetes native way of
doing things.

### Move certs and create dirs

```
sudo mkdir -p /var/lib/{kubelet,kube-proxy,kubernetes}
sudo mkdir -p /var/run/kubernetes
sudo mkdir -p /var/lib/kubelet/manifests
sudo mv bootstrap.kubeconfig /var/lib/kubelet
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy
sudo cp kubernetes.pem /var/lib/kubelet
sudo cp kubernetes-key.pem /var/lib/kubelet
```

```
export API_SERVERS=$(sudo cat /var/lib/kubelet/bootstrap.kubeconfig | \
  grep server | cut -d ':' -f2,3,4 | tr -d '[:space:]')
```

### Create a service to start our kubelet

```
cat > kubelet.service <<EOF
[Unit]
Description=Start RKT kubelet
After=rpc-statd.service
Requires=rpc-statd.service
[Service]
Environment="KUBELET_IMAGE_TAG=v1.6.1_coreos.0"
Environment="RKT_OPTS=--volume=resolv,kind=host,source=/etc/resolv.conf --mount volume=resolv,target=/etc/resolv.conf"
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin:/usr/share/oem/bin
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --tls-private-key-file=/var/lib/kubelet/kubelet-key.pem \
  --tls-cert-file=/var/lib/kubelet/kubelet.pem \
  --api-servers=$APISERVERS \
  --kubeconfig=/var/lib/kubelet/bootstrap.kubeconfig \
  --allow-privileged=true \
  --host-network-sources="*" \
  --pod-manifest-path=/var/lib/kubelet/manifests \
  --register-schedulable=true \
  --max-pods=250
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
