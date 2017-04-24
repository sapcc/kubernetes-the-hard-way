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
          value: {{.hostname}}
        - name: ETCD_DATA_DIR
          value: /var/lib/etcd2/{{.hostname}}
        - name: ETCD_INITIAL_CLUSTER
          value: {{.kubernetes.etcd_initial_cluster}}
        - name: ETCD_INITIAL_CLUSTER_TOKEN
          value: kubernetes-{{.region}}
        - name: ETCD_INITIAL_ADVERTISE_PEER_URLS
          value: http://{{.internal_network.address}}:2380
        - name: ETCD_ADVERTISE_CLIENT_URLS
          value: http://localhost:2379
        - name: ETCD_LISTEN_PEER_URLS
          value: http://{{.internal_network.address}}:2380
        - name: ETCD_LISTEN_CLIENT_URLS
          value: http://127.0.0.1:2379,http://{{.internal_network.address}}:2379
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
