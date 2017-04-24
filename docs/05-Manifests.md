```
cat > kube-proxy.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: var-lib-kube-proxy
      hostPath:
        path: /var/lib/kube-proxy
  containers:
    - name: proxy
      image: quay.io/coreos/hyperkube:v1.6.1_coreos.0
      args:
        - /hyperkube
        - proxy
        - --bind-address=10.180.0.12
        - --kubeconfig=/var/lib/kube-proxy/kube-proxy.kubeconfig
      livenessProbe:
        httpGet:
          host: 127.0.0.1
          path: /healthz
          port: 10249
          initialDelaySeconds: 15
          timeoutSeconds: 1
      volumeMounts:
        - mountPath: /var/lib/kube-proxy
          name: var-lib-kube-proxy
          readOnly: true
          securityContext:
            privileged: true
EOF
```
```
cat > etcd.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: etcd
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: var-lib-etcd2
      hostPath:
        path: /var/lib/etcd2
  containers:
    - name: etcd
      image: quay.io/coreos/etcd:v2.2.5
      env:
        - name: ETCD_NAME
          value: $HOSTNAME
        - name: ETCD_DATA_DIR
          value: /var/lib/etcd2/$HOSTNAME
        - name: ETCD_INITIAL_CLUSTER
          value: master0.novalocal=http://10.180.0.10:2380,master1.novalocal=http://10.180.0.11:2380,master2.novalocal=http://10.180.0.12:2380
        - name: ETCD_INITIAL_CLUSTER_TOKEN
          value: kubernetes-the-hard-way
        - name: ETCD_INITIAL_ADVERTISE_PEER_URLS
          value: http://10.180.0.10:2380
        - name: ETCD_ADVERTISE_CLIENT_URLS
          value: http://localhost:2379
        - name: ETCD_LISTEN_PEER_URLS
          value: http://10.180.0.10:2380
        - name: ETCD_LISTEN_CLIENT_URLS
          value: http://127.0.0.1:2379,http://10.180.0.10:2379
      livenessProbe:
        httpGet:
          host: 127.0.0.1
          path: /health
          port: 2379
          initialDelaySeconds: 300
          timeoutSeconds: 5
      volumeMounts:
        - name: var-lib-etcd2
          mountPath: /var/lib/etcd2
EOF
```
```
cat > kubernetes.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: kubernetes
  namespace: kube-system
spec:
  hostNetwork: true
  volumes:
    - name: var-lib-kubernetes
      hostPath:
        path: /var/lib/kubernetes
  containers:
    - name: apiserver
      securityContext:
      capabilities:
        add:
          - NET_ADMIN
      image: sapcc/hyperkube-amd64:{{.kubernetes.version}}
      args:
        - /hyperkube
        - apiserver
        - --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
        - --allow-privileged=true
        - --advertise-address=$KUBERNETES_PUBLIC_ADDRESS
        - --client-ca-file=/var/lib/kubernetes/ca.pem
        - --etcd-servers=http://127.0.0.1:2379
        - --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem
        - --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem
        - --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem
        - --kubelet-https=true
        - --runtime-config=extensions/v1beta1=true,extensions/v1beta1/thirdpartyresources=true
        - --secure_port=443
        - --service-account-key-file=/var/lib/kubernetes/ca-key.pem
        - --service-cluster-ip-range=10.32.0.0/24
        - --tls-cert-file=/var/lib/kubernetes/kubernetes.pem
        - --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem
      livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 8080
        initialDelaySeconds: 15
        timeoutSeconds: 1
      volumeMounts:
        - mountPath: /var/lib/kubernetes
          name: var-lib-kubernetes
          readOnly: true
    - name: controller-manager
      image: sapcc/hyperkube-amd64:{{.kubernetes.version}}
      args:
        - /hyperkube
        - controller-manager
        - --kubeconfig=/etc/kubernetes/config/controller-manager
        - --leader-elect=true
        - --root-ca-file=/etc/kubernetes/ssl/ca.pem
        - --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem
      livenessProbe:
        httpGet:
          host: 127.0.0.1
          path: /healthz
          port: 10252
          initialDelaySeconds: 15
          timeoutSeconds: 1
      volumeMounts:
        - mountPath: /var/lib/kubernetes
          name: var-lib-kubernetes
          readOnly: true
    - name: scheduler
      image: sapcc/hyperkube-amd64:{{.kubernetes.version}}
      args:
        - /hyperkube
        - scheduler
        - --kubeconfig=/etc/kubernetes/config/scheduler
        - --leader-elect=true
      livenessProbe:
        httpGet:
          host: 127.0.0.1
          path: /healthz
          port: 10251
          initialDelaySeconds: 15
          timeoutSeconds: 1
      volumeMounts:
        - mountPath: /var/lib/kubernetes
          name: var-lib-kubernetes
          readOnly: true
EOF
```
