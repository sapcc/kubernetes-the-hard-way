# Setting up a Certificate Authority and Creating TLS Certificates

In this lab you will setup the necessary PKI infrastructure to secure the Kubernetes components. This lab will leverage CloudFlare's PKI toolkit, [cfssl](https://github.com/cloudflare/cfssl), to bootstrap a Certificate Authority and generate TLS certificates to secure the following Kubernetes components:

* etcd
* kube-apiserver
* kubelet
* kube-proxy

After completing this lab you should have the following TLS keys and certificates:

```
admin.pem
admin-key.pem
ca-key.pem
ca.pem
kubelet.pem
kubelet-key.pem
kubernetes-key.pem
kubernetes.pem
kube-proxy.pem
kube-proxy-key.pem
```

## Install CFSSL

This lab requires the `cfssl` and `cfssljson` binaries. Download them from the [cfssl repository](https://pkg.cfssl.org).

### OS X

```
wget https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
chmod +x cfssl_darwin-amd64
sudo mv cfssl_darwin-amd64 /usr/local/bin/cfssl
```

```
wget https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
chmod +x cfssljson_darwin-amd64
sudo mv cfssljson_darwin-amd64 /usr/local/bin/cfssljson
```

### Linux

```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
```

```
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```

## Set up a Certificate Authority

Create a CA configuration file:

```
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```

Create a CA certificate signing request:


```
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "DE",
      "L": "Berlin",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Berlin"
    }
  ]
}
EOF
```

Generate a CA certificate and private key:

```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Results:

```
ca-key.pem
ca.pem
```

## Generate client and server TLS certificates

In this section we will generate TLS certificates for each Kubernetes component and a client certificate for the admin user.

### Create the Admin client certificate

Create the admin client certificate signing request:

```
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "DE",
      "L": "Berlin",
      "O": "system:masters",
      "OU": "Cluster",
      "ST": "Berlin"
    }
  ]
}
EOF
```

Generate the admin client certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
```

Results:

```
admin-key.pem
admin.pem
```

### Create the kubelet client certificate

Create the kubelet client certificate signing request:

```
cat > kubelet-csr.json <<EOF
{
  "CN": "system:node:kubelet",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "DE",
      "L": "Berlin",
      "O": "system:nodes",
      "OU": "Cluster",
      "ST": "Berlin"
    }
  ]
}
EOF
```

Generate the kube-proxy client certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubelet-csr.json | cfssljson -bare kubelet
```

Results:

```
kubelet-key.pem
kubelet.pem
```


### Create the kube-proxy client certificate

Create the kube-proxy client certificate signing request:

```
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "DE",
      "L": "Berlin",
      "O": "system:node-proxier",
      "OU": "Cluster",
      "ST": "Berlin"
    }
  ]
}
EOF
```

Generate the kube-proxy client certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
```

Results:

```
kube-proxy-key.pem
kube-proxy.pem
```

### Create the kubernetes server certificate

The Kubernetes public IP address will be included in the list of subject alternative names for the Kubernetes server certificate. This will ensure the TLS certificate is valid for remote client access.

Create the Kubernetes server certificate signing request:

```
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "10.180.0.100",
    "10.180.0.101",
    "10.180.0.102",
    "10.180.0.200",
    "10.180.0.201",
    "10.180.0.202",
    "${KUBERNETES_PUBLIC_ADDRESS}",
    "127.0.0.1",
    "localhost",
    "kubernetes.default",
    "minion0",
    "minion1",
    "minion2"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "DE",
      "L": "Berlin",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Berlin"
    }
  ]
}
EOF
```

Generate the Kubernetes certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```

Results:

```
kubernetes-key.pem
kubernetes.pem
```

## Distribute the TLS certificates

The following commands will copy the TLS certificates and keys to each Kubernetes host using the gateway we created.

```
scp -oProxyJump=core@$GATEWAY:22 ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem kubelet.pem kubelet-key.pem core@10.180.0.100:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem kubelet.pem kubelet-key.pem core@10.180.0.101:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem kubelet.pem kubelet-key.pem core@10.180.0.102:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem kubernetes-key.pem kubernetes.pem kube-proxy.pem kube-proxy-key.pem core@10.180.0.200:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem kubernetes-key.pem kubernetes.pem kube-proxy.pem kube-proxy-key.pem core@10.180.0.201:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem kubernetes-key.pem kubernetes.pem kube-proxy.pem kube-proxy-key.pem core@10.180.0.202:~/
```
