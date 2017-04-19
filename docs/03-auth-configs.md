# Setting up Authentication

In this lab you will setup the necessary authentication configs to enable Kubernetes clients to bootstrap and authenticate using RBAC (Role-Based Access Control).

The following should be done on the gateway else the file has to be transported first.

## Download and Install kubectl

The kubectl client will be used to generate kubeconfig files which will be consumed by the kubelet and kube-proxy services.

### OS X

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.6.0/bin/darwin/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

### Linux

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.6.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

### Gateway

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.6.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mkdir -p /opt/bin
sudo mv kubectl /opt/bin
```

## Authentication

The following components will leverge Kubernetes RBAC:

* kubelet (client)
* kube-proxy (client)
* kubectl (client)

The other components, mainly the `scheduler` and `controller manager`, access the Kubernetes API server locally over the insecure API port which does not require authentication. The insecure port is only enabled for local access.

### Create the TLS Bootstrap Token

This section will walk you through the creation of a TLS bootstrap token that will be used to [bootstrap TLS client certificates for kubelets](https://kubernetes.io/docs/admin/kubelet-tls-bootstrapping/). 

Generate a token:

```
BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
```

Generate a token file:

```
cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
```

Distribute the bootstrap token file to each controller node:

```
scp token.csv 10.180.0.11:~/
```
Repeat for every master.


## Client Authentication Configs

This section will walk you through creating kubeconfig files that will be used to bootstrap kubelets, which will then generate their own kubeconfigs based on dynamically generated certificates, and a kubeconfig for authenticating kube-proxy clients.

Each kubeconfig requires a Kubernetes master to connect to. To support H/A the IP address assigned to the load balancer sitting in front of the Kubernetes API servers will be used.

## Create client kubeconfig files

### Create the bootstrap kubeconfig file

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=bootstrap.kubeconfig
```

```
kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig
```

```
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig
```

```
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
```

### Create the kube-proxy kubeconfig


```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig
```

```
kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
```

```
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
```

```
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```

## Distribute the client kubeconfig files

```
scp bootstrap.kubeconfig kube-proxy.kubeconfig core@10.180.0.20:~/
```
Repeat for every minion.

