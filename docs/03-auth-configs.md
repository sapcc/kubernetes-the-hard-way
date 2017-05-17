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

## Client Authentication Configs

This section will walk you through creating kubeconfig files that will be used to bootstrap kubelets, which will then generate their own kubeconfigs based on dynamically generated certificates, and a kubeconfig for authenticating kube-proxy clients.

Each kubeconfig requires a Kubernetes master to connect to. To support H/A the IP address assigned to the load balancer sitting in front of the Kubernetes API servers will be used.

## Create client kubeconfig files

### Create the master-kubelet kubeconfig file

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://localhost:6443
  --kubeconfig=master.kubeconfig
```

```
kubectl config set-credentials kubelet \
  --client-certificate=kubelet.pem \
  --client-key=kubelet-key.pem \
  --embed-certs=true \
  --kubeconfig=master.kubeconfig
```

```
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=kubelet \
  --kubeconfig=master.kubeconfig
```

```
kubectl config use-context default --kubeconfig=master.kubeconfig
```

### Create the minion-bootstrap kubeconfig file

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS} \
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
  --server=https://${KUBERNETES_PUBLIC_ADDRESS} \
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

## Cloud Provider Config

```
cat > openstack.config <<EOF
[Global]
auth-url = ${OS_AUTH_URL} 
username = ${OS_USERNAME} 
password = ${OS_PASSWORD} 
domain-name = ${OS_PROJECT_DOMAIN_NAME}
tenant-name = ${OS_PROJECT_NAME} 
region = ${OS_REGION_NAME} 
[LoadBalancer]
lb-version=v2
subnet-id= ${SUBNET}
create-monitor = yes
monitor-delay = 1m
monitor-timeout = 30s
monitor-max-retries = 3
[BlockStorage]
trust-device-path = no
[Route]
router-id = ${ROUTER_ID}
EOF
```

## Distribute the client configuration 

```
scp *config token.csv core@$GATEWAY:~/
ssh -A core@$GATEWAY
scp master.kubeconfig openstack.config token.csv core@10.180.0.10:~/
scp master.kubeconfig openstack.config token.csv core@10.180.0.11:~/
scp master.kubeconfig openstack.config token.csv core@10.180.0.12:~/
scp bootstrap.kubeconfig kube-proxy.kubeconfig openstack.config core@10.180.0.20:~/
scp bootstrap.kubeconfig kube-proxy.kubeconfig openstack.config core@10.180.0.21:~/
scp bootstrap.kubeconfig kube-proxy.kubeconfig openstack.config core@10.180.0.22:~/
```
