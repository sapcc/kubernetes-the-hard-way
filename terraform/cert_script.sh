export OS_VER=`uname -a|awk '{print $1}'`
echo "OS is: $OS_VER"

GATEWAY=`awk '{print $1}' ipaddr.txt`

if [[ $OS_VER -eq "Darwin" ]]; then 
	if [[ -z $(which cfssl) ]]; then 
		wget https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
		chmod +x cfssl_darwin-amd64
		sudo mv cfssl_darwin-amd64 /usr/local/bin/cfssl
	fi
	if [[ -z $(which cfssljson) ]]; then
		wget https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
		chmod +x cfssljson_darwin-amd64
		sudo mv cfssljson_darwin-amd64 /usr/local/bin/cfssljson
	fi
elif [[ $OS_VER -eq "Linux" ]]; then 
	if [[ -z $(which cfssl) ]]; then
		wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
		chmod +x cfssl_linux-amd64
		sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
	fi
	if [[ -z $(which cfssljson) ]]; then
		wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
		chmod +x cfssljson_linux-amd64
		sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson 
	fi
else 
	echo 'Not *NIX OS' 
fi

#Create a CA configuration file:
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
#Create a CA certificate signing request:
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

# Generate a CA certificate and private key:
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

#Generate client and server TLS certificates
#Create the admin client certificate signing request:

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

#Generate the admin client certificate and private key:

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin


#Create the kubelet client certificate signing request:
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
#Generate the kube-proxy client certificate and private key:
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubelet-csr.json | cfssljson -bare kubelet
#Create the kube-proxy client certificate signing request:
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

#Generate the kube-proxy client certificate and private key:
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

# Create the kubernetes server certificate
# Create the Kubernetes server certificate signing request:

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "10.180.1.1",
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
    "master0",
    "master1",
    "master2",
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

# Generate the Kubernetes certificate and private key:
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

scp -oProxyJump=core@$GATEWAY:22 ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem kubelet.pem kubelet-key.pem core@10.180.0.100:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem kubelet.pem kubelet-key.pem core@10.180.0.101:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem kubelet.pem kubelet-key.pem core@10.180.0.102:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem kubernetes-key.pem kubernetes.pem kube-proxy.pem kube-proxy-key.pem core@10.180.0.200:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem kubernetes-key.pem kubernetes.pem kube-proxy.pem kube-proxy-key.pem core@10.180.0.201:~/
scp -oProxyJump=core@$GATEWAY:22 ca.pem kubernetes-key.pem kubernetes.pem kube-proxy.pem kube-proxy-key.pem core@10.180.0.202:~/

