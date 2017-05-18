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

We're going to be using the following network ranges:
VMs: 10.180.0.0/24
Services: 10.180.1.0/24
Pods: 10.180.128.0/17

Create a custom network:

```
neutron net-create kthw-net
```

Create a subnet for the Kubernetes cluster:

```
neutron subnet-create --name kthw-subnet kthw-net 10.180.0.0/24
```

Create a router for the kubernetes network:
```
neutron router-create kthw-router
neutron router-interface-add kthw-router subnet=kthw-subnet
```

Connect it to the gateway of the external network:
```
neutron router-gateway-set kthw-router FloatingIP-external-monsoon3
```

### Create the Kubernetes Public Address

Create a public IP address that will be used by remote clients to connect to the Kubernetes control plane:

```
neutron floatingip-create FloatingIP-external-monsoon3
export KUBERNETES_PUBLIC_ADDRESS=10.47.40.96
```

### Create Firewall Rules

```
neutron security-group-create kthw-secgroup
```

Allow TCP/UDP/ICMP between instances on the private network:
```
neutron security-group-rule-create --description allow-internal --direction ingress --protocol tcp --remote-ip-prefix 10.180.0.0/24 kthw-secgroup
neutron security-group-rule-create --description allow-internal --direction ingress --protocol udp --remote-ip-prefix 10.180.0.0/24 kthw-secgroup
neutron security-group-rule-create --description allow-internal --direction ingress --protocol icmp --remote-ip-prefix 10.180.0.0/24 kthw-secgroup
```

Allow TCP/UDP/ICMP between containers on the pod network:
```
neutron security-group-rule-create --description allow-internal --direction ingress --protocol tcp --remote-ip-prefix 10.180.128.0/17 kthw-secgroup
neutron security-group-rule-create --description allow-internal --direction ingress --protocol udp --remote-ip-prefix 10.180.128.0/17 kthw-secgroup
neutron security-group-rule-create --description allow-internal --direction ingress --protocol icmp --remote-ip-prefix 10.180.128.0/17 kthw-secgroup
```

Allow external traffic:
```
neutron security-group-rule-create --description allow-external --direction ingress --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 kthw-secgroup
neutron security-group-rule-create --description allow-external --direction ingress --protocol tcp --port-range-min 6443 --port-range-max 6443 --remote-ip-prefix 0.0.0.0/0 kthw-secgroup
neutron security-group-rule-create --description allow-external --direction ingress --protocol icmp --remote-ip-prefix 0.0.0.0/0 kthw-secgroup
```

### Validate rules

```
neutron security-group-show kthw-secgroup
```

```
+----------------------+--------------------------------------------------------------------+
| Field                | Value                                                              |
+----------------------+--------------------------------------------------------------------+
| description          |                                                                    |
| id                   | f5c7a0f1-95c5-4cf6-b79c-c3eec080cb5f                               |
| name                 | kthw-secgroup                                                      |
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
neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.100 --name master0 --dns-name master0 kthw-net
neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.101 --name master1 --dns-name master1 kthw-net
neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.102 --name master2 --dns-name master2 kthw-net
neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.200 --name minion0 --dns-name minion0 kthw-net
neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.201 --name minion1 --dns-name minion1 kthw-net
neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.202 --name minion2 --dns-name minion2 kthw-net
neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.99  --name gateway --dns-name gateway kthw-net
```

```
neutron port-list
```

```
+--------------------------------------+---------+-------------------+-------------------------------------------------------------------------------------+
| id                                   | name    | mac_address       | fixed_ips                                                                           |
+--------------------------------------+---------+-------------------+-------------------------------------------------------------------------------------+
| 1c4df28e-69ee-43bd-9f4d-202406a3fcd1 |         | fa:16:3e:5f:0b:c8 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.5"}   |
| 30398f39-2a0c-450a-a11a-f387190c1ca7 | master2 | fa:16:3e:6a:15:4b | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.102"} |
| 374eb1bd-c612-4e36-a2c9-8476f7fae12a | master0 | fa:16:3e:fd:b5:58 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.100"} |
| 773cb1aa-d2d9-4f5c-87bd-6d799892a53e |         | fa:16:3e:d8:18:d3 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.2"}   |
| 848e0e6b-67f9-4a88-b956-e68806ce5dd6 | master1 | fa:16:3e:c5:a9:22 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.101"} |
| 877abc10-1b3e-4224-96c0-d34067c6e2a1 | minion1 | fa:16:3e:2f:0f:36 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.201"} |
| 904dc7cd-c4ba-4857-b6e5-9971532262f9 |         | fa:16:3e:e3:24:3b | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.4"}   |
| a92c2bfe-d757-43f4-9550-6514c8f41189 | minion2 | fa:16:3e:2f:0f:13 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.202"} |
| b013b962-8cd0-4fe8-ba49-bbe06276b7b1 |         | fa:16:3e:55:5a:5f | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.1"}   |
| c8fead6f-7d4e-4607-b113-2e07460d0a7b | minion0 | fa:16:3e:e6:62:2c | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.200"} |
| d9537e69-7e29-4fdc-bd4b-9e56b8b90765 | gateway | fa:16:3e:12:39:83 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.99"}  |
| df42584a-e323-4cd4-aa3e-d7a93481fd9d |         | fa:16:3e:9f:d6:e3 | {"subnet_id": "b279046b-baaa-490b-a8be-f23a917c6766", "ip_address": "10.180.0.3"}   |
+--------------------------------------+---------+-------------------+-------------------------------------------------------------------------------------+
```

Note: You will see a few extra infrastructure ports. 

### Virtual Machines

#### Add ssh keypair
```
nova keypair-add --pub-key id_rsa.pub id_rsa
```
#### Kubernetes Masters 

This requires to look up the port-id in the `port-list`. Names don't work here.
Be careful not to confuse names/ports.

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --nic port-id=374eb1bd-c612-4e36-a2c9-8476f7fae12a master0
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --nic port-id=848e0e6b-67f9-4a88-b956-e68806ce5dd6 master1
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --nic port-id=30398f39-2a0c-450a-a11a-f387190c1ca7 master2
```

#### Kubernetes Minions 

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --nic port-id=c8fead6f-7d4e-4607-b113-2e07460d0a7b minion0 
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --nic port-id=877abc10-1b3e-4224-96c0-d34067c6e2a1 minion1
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --nic port-id=a92c2bfe-d757-43f4-9550-6514c8f41189 minion2
```

#### Gateway

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-stable-amd64 --security-groups default,kthw-secgroup --nic port-id=d9537e69-7e29-4fdc-bd4b-9e56b8b90765 gateway
```

We can now associate a floatingip with the gateway to access the kubenet
```
neutron floatingip-create --fixed-ip-address 10.180.0.99 --port-id=d9537e69-7e29-4fdc-bd4b-9e56b8b90765 FloatingIP-external-monsoon3
```

#### Add instances to the Security Group

```
nova add-secgroup master0 kthw-secgroup
nova add-secgroup master1 kthw-secgroup
nova add-secgroup master2 kthw-secgroup
nova add-secgroup minion0 kthw-secgroup
nova add-secgroup minion1 kthw-secgroup
nova add-secgroup minion2 kthw-secgroup
nova add-secgroup gateway kthw-secgroup
```
