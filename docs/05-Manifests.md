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
