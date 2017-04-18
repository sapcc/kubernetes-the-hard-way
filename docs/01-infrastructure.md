# Cloud Infrastructure Provisioning - Openstack 

This lab will walk you through provisioning the compute instances required for running a H/A Kubernetes cluster. A total of 6 virtual machines will be created.

After completing this guide you should have the following compute instances:

```
nova list
```

````
+--------------------------------------+---------+--------+------------+-------------+-------------------------+
| ID                                   | Name    | Status | Task State | Power State | Networks                |
+--------------------------------------+---------+--------+------------+-------------+-------------------------+
| 9e957363-98cf-45bd-9170-11865c7a2c20 | master0 | ACTIVE | -          | Running     | lab_private=10.180.0.10 |
| 9e957363-98cf-45bd-9170-11865c7a2c20 | master1 | ACTIVE | -          | Running     | lab_private=10.180.0.11 |
| 9e957363-98cf-45bd-9170-11865c7a2c20 | master2 | ACTIVE | -          | Running     | lab_private=10.180.0.12 |
| 9e957363-98cf-45bd-9170-11865c7a2c20 | minion0 | ACTIVE | -          | Running     | lab_private=10.180.0.20 |
| 9e957363-98cf-45bd-9170-11865c7a2c20 | minion1 | ACTIVE | -          | Running     | lab_private=10.180.0.21 |
| 9e957363-98cf-45bd-9170-11865c7a2c20 | minion2 | ACTIVE | -          | Running     | lab_private=10.180.0.22 |
+--------------------------------------+---------+--------+------------+-------------+-------------------------+
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
docker run -ti --env-file lab_rc --volume (pwd):/config hub.global.cloud.sap/monsoon/cc-openstack-cli:latest -- bash
```

## Setup Networking


Create a custom network:

```
neutron network-create kthw-net
export NETWORK=ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed
```

Create a subnet for the Kubernetes cluster:

```
neutron subnet-create --name khw-subnet $NETWORK 10.180.0.0/16
export SUBNET=ce4fde76-1db9-4dbf-a1ba-1ae261bbcfed
```

### Create Firewall Rules

```
neutron secgroup-create --name kubernetes-the-hard-way ...
```

```
neutron secgroup-add-rule allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 10.240.0.0/24,10.200.0.0/16
```

```
neutron secgroup-add-rule allow-external \
  --allow tcp:22,tcp:3389,tcp:6443,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 0.0.0.0/0
```

```
neutron secgroup-add-rule allow-healthz \
  --allow tcp:8080 \
  --network kubernetes-the-hard-way \
  --source-ranges 130.211.0.0/22
```


```
nova secgroup-list-rules 5258bad2-3704-4a33-92c8-57766d5c6ce5
```

```
+-------------+-----------+---------+-----------+-------------------------+
| IP Protocol | From Port | To Port | IP Range  | Source Group            |
+-------------+-----------+---------+-----------+-------------------------+
| tcp         | 22        | 22      | 0.0.0.0/0 | kubernetes-the-hard-way |
| tcp         | 3389      | 3389    | 0.0.0.0/0 | kubernetes-the-hard-way |
| tcp         | 6443      | 6443    | 0.0.0.0/0 | kubernetes-the-hard-way |
| ICMP        |           |         | 0.0.0.0/0 | kubernetes-the-hard-way |
+-------------+-----------+---------+-----------+-------------------------+
```

### Create the Kubernetes Public Address

Create a public IP address that will be used by remote clients to connect to the Kubernetes control plane:

```
nova floating-ip-create ...
```

```
nova floating-ip-list
```

```
+--------------------------------------+-------------+--------------------------------------+-------------+------------------------------+
| Id                                   | IP          | Server Id                            | Fixed IP    | Pool                         |
+--------------------------------------+-------------+--------------------------------------+-------------+------------------------------+
| c3e383e7-4678-45a7-aa5a-ad594c9f92d9 | 10.47.40.90 | -                                    | -           | FloatingIP-external-monsoon3 |
+--------------------------------------+-------------+--------------------------------------+-------------+------------------------------+
```

## Provision Virtual Machines

All the VMs in this lab will be provisioned using Container Linux. 

### Fixed IPs

```
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.10 --name master0 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.11 --name master1 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.12 --name master2 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.20 --name minion0 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.21 --name minion1 $NETWORK
neutron port-create --fixed-ip subnet_id=$SUBNET,ip_address=10.180.0.22 --name minion2 $NETWORK
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
+--------------------------------------+----------+-------------------+------------------------------------------------------------------------------------+
```

### Virtual Machines

#### Kubernetes Masters 

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-amd64-alpha --security-groups default --nic port-id=67dc2530-841b-483c-9852-8311341f018c master0
nova boot --flavor m1.small --key-name id_rsa --image coreos-amd64-alpha --security-groups default --nic port-id=99bdf85e-d8d1-4eb5-b543-eb7f7b15299b master1
nova boot --flavor m1.small --key-name id_rsa --image coreos-amd64-alpha --security-groups default --nic port-id=83206176-8509-4d0d-8151-77b89b5135b7 master2
```

#### Kubernetes Minions 

```
nova boot --flavor m1.small --key-name id_rsa --image coreos-amd64-alpha --security-groups default --nic port-id=3235e943-8e40-4b31-bbc3-ea11124a6cd1 minion0 
nova boot --flavor m1.small --key-name id_rsa --image coreos-amd64-alpha --security-groups default --nic port-id=e4d21b0a-2e5e-4f0a-a3ee-5bc3243348ae minion1
nova boot --flavor m1.small --key-name id_rsa --image coreos-amd64-alpha --security-groups default --nic port-id=9808735a-f0d2-4d05-9414-d541684e12a7 minion2
```
