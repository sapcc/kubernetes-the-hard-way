# Configuring the Kubernetes Client - Remote Access

Run the following commands from the machine which will be your Kubernetes Client

## Download and Install kubectl

### OS X

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.6.3/bin/darwin/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

### Linux

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.6.3/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

## Configure Kubectl

In this section you will configure the kubectl client to point to the [Kubernetes API Server Frontend Load Balancer](04-kubernetes-controller.md#setup-kubernetes-api-server-frontend-load-balancer).

Use the load balancer's floating ip from earlier:
```
KUBERNETES_PUBLIC_ADDRESS=10.47.40.33
```

Also be sure to locate the CA certificate [created earlier](02-certificate-authority.md). Since we are using self-signed TLS certs we need to trust the CA certificate so we can verify the remote API Servers.

### Build up the kubeconfig entry

The following commands will build up the default kubeconfig file used by kubectl.

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}
```

```
kubectl config set-credentials admin \
  --embed-certs=true \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem
```

```
kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin
```

```
kubectl config use-context kubernetes-the-hard-way
```

At this point you should be able to connect securly to the remote API server:

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


