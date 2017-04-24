```
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
       image: sapcc/hyperkube-amd64:{{.kubernetes.version}}
       args: 
         - /hyperkube
         - proxy 
         - --bind-address={{.internal_network.address}}
         - --disable-externalip-security-measures=true
         - --kubeconfig=/etc/kubernetes/config/proxy
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
```
