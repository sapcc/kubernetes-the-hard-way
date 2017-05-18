# Cloud Infrastructure Provisioning - Openstack 

This lab will walk you through provisioning the compute instances required for running a H/A Kubernetes cluster. A total of 6 virtual machines will be created.

After completing this guide you should have the following compute instances:

```
nova list
```

````
+--------------------------------------+---------+--------+------------+-------------+----------------------+
| ID                                   | Name    | Status | Task State | Power State | Networks             |
+--------------------------------------+---------+--------+------------+-------------+----------------------+
| e676bf30-8904-4ba0-b7c2-010aaea2549b | master0 | ACTIVE | -          | Running     | kthw-net=10.180.0.10 |
| 9c493e8c-ae6f-4898-b994-b93197d961a8 | master1 | ACTIVE | -          | Running     | kthw-net=10.180.0.11 |
| e4885d23-0e31-46ec-afe1-73beeffae75c | master2 | ACTIVE | -          | Running     | kthw-net=10.180.0.12 |
| e3d30d4d-9434-4aec-8287-7df757e8709f | minion0 | ACTIVE | -          | Running     | kthw-net=10.180.0.20 |
| 7856b972-53de-40d0-9f2d-854b93a53d30 | minion1 | ACTIVE | -          | Running     | kthw-net=10.180.0.21 |
| 276ee9cf-c10d-4060-9108-af1274ce20a8 | minion2 | ACTIVE | -          | Running     | kthw-net=10.180.0.22 |
| a401b016-5f96-4d5b-8398-ca259f755844 | gateway | ACTIVE | -          | Running     | kthw-net=10.180.0.30 |
+--------------------------------------+---------+--------+------------+-------------+----------------------+
````

> All machines will be provisioned with fixed private IP addresses to simplify the bootstrap process.

To make our Kubernetes control plane remotely accessible, a public IP address will be provisioned and assigned to a Load Balancer that will sit in front of the 3 Kubernetes masters.

## Prerequisites

Create a project in Openstack and configure your CLI tools:

```
OS_AUTH_URL=https://identity.cloud.sap:443/v3
OS_IDENTITY_API_VERSION=3
OS_PROJECT_NAME=lab
OS_PROJECT_DOMAIN_NAME=lab
OS_USERNAME=D038720
OS_USER_DOMAIN_NAME=lab
OS_PASSWORD=abc123
OS_REGION_NAME=eu-de-1
```

```
docker run -ti --env-file lab_rc hub.global.cloud.sap/monsoon/cc-openstack-cli:latest -- bash
```

## Setup Networking


Create a custom network:

```
neutron net-create kthw-net
export NETWORK=ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed
```

Create a subnet for the Kubernetes cluster:

```
neutron subnet-create --name khw-subnet $NETWORK 10.180.0.0/24
export SUBNET=ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed
```

Create a router for the kubernetes network:
```
neutron router-create kthw-router
export ROUTER_ID=33c35501-1b53-4e3f-8ee1-0726f9913ec0
neutron router-interface-add $ROUTER_ID subnet=$SUBNET
```

Connect it to the gateway of the external network:
```
neutron net-list
export EXTERNAL_NETWORK=f55c8e3d-c798-4c6c-9f7e-eeb6600f6aed
neutron router-gateway-set $ROUTER_ID $EXTERNAL_NETWORK
```

### Create the Kubernetes Public Address

Create a public IP address that will be used by remote clients to connect to the Kubernetes control plane:

```
neutron floatingip-create $EXTERNAL_NETWORK
export KUBERNETES_PUBLIC_ADDRESS=10.47.40.96
```

### Create Firewall Rules

```
neutron security-group-create kubernetes-the-hard-way
export SECGROUP=ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed
```

Allow TCP/UDP/ICMP between instances on the private network:
```
neutron security-group-rule-create --description allow-internal --direction ingress --protocol tcp --remote-ip-prefix 10.180.0.0/16 $SECGROUP
neutron security-group-rule-create --description allow-internal --direction ingress --protocol udp --remote-ip-prefix 10.180.0.0/16 $SECGROUP
neutron security-group-rule-create --description allow-internal --direction ingress --protocol icmp --remote-ip-prefix 10.180.0.0/16 $SECGROUP
```

Allow TCP/UDP/ICMP between containes on the pod network:
```
neutron security-group-rule-create --description allow-internal --direction ingress --protocol tcp --remote-ip-prefix 10.200.0.0/16 $SECGROUP
neutron security-group-rule-create --description allow-internal --direction ingress --protocol udp --remote-ip-prefix 10.200.0.0/16 $SECGROUP
neutron security-group-rule-create --description allow-internal --direction ingress --protocol icmp --remote-ip-prefix 10.200.0.0/16 $SECGROUP
```

Allow external traffic:
```
neutron security-group-rule-create --description allow-external --direction ingress --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 $SECGROUP
neutron security-group-rule-create --description allow-external --direction ingress --protocol tcp --port-range-min 6443 --port-range-max 6443 --remote-ip-prefix 0.0.0.0/0 $SECGROUP
neutron security-group-rule-create --description allow-external --direction ingress --protocol icmp --remote-ip-prefix 0.0.0.0/0 $SECGROUP
```

### Validate rules

```
neutron security-group-show f5c7a0f1-95c5-4cf6-b79c-c3eec080cb5f
```

```
+----------------------+--------------------------------------------------------------------+
| Field                | Value                                                              |
+----------------------+--------------------------------------------------------------------+
| description          |                                                                    |
| id                   | f5c7a0f1-95c5-4cf6-b79c-c3eec080cb5f                               |
| name                 | kubernetes-the-hard-way                                            |
| security_group_rules | {                                                                  |
|                      |      "remote_group_id": null,                                      |
|                      |      "direction": "ingress",                                       |
|                      |      "protocol": "icmp",                                           |
|                      |      "description": "allow-external",                              |
|                      |      "ethertype": "IPv4",                                          |
|                      |      "remote_ip_prefix": "0.0.0.0/0",                              |
|                      |      "port_range_max": null,                                       |
|                      |      "security_group_id": "f5c7a0f1-95c5-4cf6-b79c-c3eec080cb5f",  |
|                      |      "port_range_min": null,                                       |
|                      |      "tenant_id": "51e81a318003442a8c232592166f0e8b",              |
|                      |      "id": "1e8a081d-cd54-44c9-b559-9554a400eb3a"                  |
|                      | }                                                                  |
|                      | {                                                                  |
|                      |      "remote_group_id": null,                                      |
|                      |      "direction": "ingress",                                       |
|                      |      "protocol": "tcp",                                            |
|                      |      "description": "allow-external",                              |
|                      |      "ethertype": "IPv4",                                          |
|                      |      "remote_ip_prefix": "0.0.0.0/0",                              |
|                      |      "port_range_max": 6443,                                       |
|                      |      "security_group_id": "f5c7a0f1-95c5-4cf6-b79c-c3eec080cb5f",  |
|                      |      "port_range_min": 6443,                                       |
|                      |      "tenant_id": "51e81a318003442a8c232592166f0e8b",              |
|                      |      "id": "b4ce59c6-dce9-4748-8daa-d63e2d3672b8"                  |
|                      | }                                                                  |
```



## Provision Virtual Machines

All the VMs in this lab will be provisioned using Container Linux. 

### Fixed IPs

```
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.10 --name master0 --dns_name master0 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.11 --name master1 --dns_name master1 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.12 --name master2 --dns_name master2 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.20 --name minion0 --dns_name minino0 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.21 --name minion1 --dns_name minino1 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.22 --name minion2 --dns_name minino2 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.30 --name gateway --dns_name gateway $NETWORK
```

```
neutron port-list
```

```
+--------------------------------------+----------+-------------------+------------------------------------------------------------------------------------+
| id                                   | name     | mac_address       | fixed_ips                                                                          |
+--------------------------------------+----------+-------------------+------------------------------------------------------------------------------------+
| 67dc2530-841b-483c-9852-8311341f018c | master0  | fa:16:3e:9e:62:cf | {"subnet_id": "ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed", "ip_address": "10.180.0.10"} |
| 99bdf85e-d8d1-4eb5-b543-eb7f7b15299b | master1  | fa:16:3e:7b:01:34 | {"subnet_id": "ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed", "ip_address": "10.180.0.11"} |
| 83206176-8509-4d0d-8151-77b89b5135b7 | master2  | fa:16:3e:5c:05:19 | {"subnet_id": "ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed", "ip_address": "10.180.0.12"} |
| 3235e943-8e40-4b31-bbc3-ea11124a6cd1 | minion0  | fa:16:3e:ff:1b:f4 | {"subnet_id": "ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed", "ip_address": "10.180.0.20"} |
| e4d21b0a-2e5e-4f0a-a3ee-5bc3243348ae | minion1  | fa:16:3e:a1:22:27 | {"subnet_id": "ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed", "ip_address": "10.180.0.21"} |
| 9808735a-f0d2-4d05-9414-d541684e12a7 | minion2  | fa:16:3e:7a:c0:3f | {"subnet_id": "ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed", "ip_address": "10.180.0.22"} |
| 848396d3-5e18-4410-9a7f-949295428e3f | gateway  | fa:16:3e:4f:ea:7e | {"subnet_id": "83aab941-87f4-4372-9fbc-9f702092e3cf", "ip_address": "10.180.0.30"} |
+--------------------------------------+----------+-------------------+------------------------------------------------------------------------------------+
```

### Virtual Machines

#### Add ssh keypair
```
nova keypair-add --pub-key id_rsa.pub id_rsa
```
#### Kubernetes Masters 

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups default,kubernetes-the-hard-way --nic port-id=67dc2530-841b-483c-9852-8311341f018c master0
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups default,kubernetes-the-hard-way --nic port-id=99bdf85e-d8d1-4eb5-b543-eb7f7b15299b master1
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups default,kubernetes-the-hard-way --nic port-id=83206176-8509-4d0d-8151-77b89b5135b7 master2
```

#### Kubernetes Minions 

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups default,kubernetes-the-hard-way --nic port-id=3235e943-8e40-4b31-bbc3-ea11124a6cd1 minion0 
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups default,kubernetes-the-hard-way --nic port-id=e4d21b0a-2e5e-4f0a-a3ee-5bc3243348ae minion1
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups default,kubernetes-the-hard-way --nic port-id=9808735a-f0d2-4d05-9414-d541684e12a7 minion2
```

#### Gateway

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups kubernetes-the-hard-way --nic port-id=848396d3-5e18-4410-9a7f-949295428e3f gateway
```

We can now associate a floatingip with the gateway to access the kubenet
```
neutron floatingip-create --fixed-ip-address 10.180.0.30 --port-id=848396d3-5e18-4410-9a7f-949295428e3f $EXTERNAL_NETWORK
```
