variable "user_name" { default = "i072278" }
variable "project_name" { default = "consulting_dev" }
# variable "domain_name" { default = "monsoon3" }
variable "auth_url"    { default ="https://identity-3.eu-de-1.cloud.sap:443/v3" }
variable "region" { default = "eu-de-1" }
variable "image" { default = "coreos-stable-amd64" }
variable "key_pair" { default = "Corporate_Key" }
variable "flavor" { default = "22" } # m1.xsmall
variable "security_group" { default = "default" }
variable "fip_pool" { default = "FloatingIP-external-monsoon3-03" } # os network list
variable "cluster_ip" { default = "" }
variable "cluster_dns" { default = "" }
variable "ssh_user_name" { default = "core" }
variable "ssh_key_path" { default = "~/.ssh/id_rsa" }
variable "az" { default = "eu-de-1b" } 

# Provider section
provider "openstack"
{
  user_name   = "${var.user_name}"
  tenant_name = "${var.project_name}"
  #domain_name = "${var.domain_name}"
  auth_url    = "${var.auth_url}"
  # availability_zone = "${var.az}"
}

# neutron net-create kthw-net
resource "openstack_networking_network_v2" "kthw-net" {
  name           = "kthw-net"
  admin_state_up = "true"
}

# neutron subnet-create --name kthw-subnet kthw-net 10.180.0.0/24
resource "openstack_networking_subnet_v2" "kthw-subnet" {
  name       = "kthw-subnet"
  network_id = "${openstack_networking_network_v2.kthw-net.id}"
  cidr       = "10.180.0.0/24"
  enable_dhcp = "false"
  ip_version = 4
}

# neutron router-create kthw-router
resource "openstack_networking_router_v2" "kthw-router" {
  name             = "kthw-router"
  external_gateway = "ca82acc6-22d0-4b9f-86fd-5f2c0df22e04"
}

# neutron router-interface-add kthw-router subnet=kthw-subnet
resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = "${openstack_networking_router_v2.kthw-router.id}"
  subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}"
}

# neutron floatingip-create FloatingIP-external-monsoon3
resource "openstack_compute_floatingip_v2" "cluster_fip" {
  pool = "${var.fip_pool}"
}



# neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.100 --name master0 --dns-name master0 kthw-net
resource "openstack_networking_port_v2" "master0_port" {
  name           = "master0"
  network_id     = "${openstack_networking_network_v2.kthw-net.id}"
  fixed_ip {
        subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}",
        ip_address = "10.180.0.100"
  }
  admin_state_up = "true"
}

# neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.101 --name master1 --dns-name master1 kthw-net
resource "openstack_networking_port_v2" "master1_port" {
  name           = "master1"
  network_id     = "${openstack_networking_network_v2.kthw-net.id}"
  fixed_ip {
        subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}",
        ip_address = "10.180.0.101"
  }
  admin_state_up = "true"
}
# neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.102 --name master2 --dns-name master2 kthw-net
resource "openstack_networking_port_v2" "master2_port" {
  name           = "master2"
  network_id     = "${openstack_networking_network_v2.kthw-net.id}"
  fixed_ip {
        subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}",
        ip_address = "10.180.0.102"
  }
  admin_state_up = "true"
}

# neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.200 --name minion0 --dns-name minion0 kthw-net
resource "openstack_networking_port_v2" "minion0_port" {
  name           = "minion0"
  network_id     = "${openstack_networking_network_v2.kthw-net.id}"
  fixed_ip {
        subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}",
        ip_address = "10.180.0.200"
  }
  admin_state_up = "true"
}

# neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.201 --name minion1 --dns-name minion1 kthw-net
resource "openstack_networking_port_v2" "minion1_port" {
  name           = "minion1"
  network_id     = "${openstack_networking_network_v2.kthw-net.id}"
  fixed_ip {
        subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}",
        ip_address = "10.180.0.201"
  }
  admin_state_up = "true"
}

# neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.202 --name minion2 --dns-name minion2 kthw-net
resource "openstack_networking_port_v2" "minion2_port" {
  name           = "minion2"
  network_id     = "${openstack_networking_network_v2.kthw-net.id}"
  fixed_ip {
        subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}",
        ip_address = "10.180.0.202"
  }
  admin_state_up = "true"
}

# neutron port-create --fixed-ip subnet_id=kthw-subnet,ip_address=10.180.0.99  --name gateway --dns-name gateway kthw-net
resource "openstack_networking_port_v2" "gateway_port" {
  name           = "gateway"
  network_id     = "${openstack_networking_network_v2.kthw-net.id}"
  fixed_ip {
        subnet_id = "${openstack_networking_subnet_v2.kthw-subnet.id}",
        ip_address = "10.180.0.99"
  }
  admin_state_up = "true"
}

resource "openstack_networking_secgroup_v2" "kthw-secgroup" {
  name        = "kthw-secgroup"
  description = "Kubernetes the hard way secgroup"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_ingress_22" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_ingress_6443" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_ingress_all_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}


resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_all_TCP_10_180_0_0" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "10.180.0.0/24"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_all_UDP_10_180_0_0" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  remote_ip_prefix  = "10.180.0.0/24"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_all_ICMP_10_180_0_0" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "10.180.0.0/24"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_all_TCP_10_180_128_0" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "10.180.128.0/17"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_all_UDP_10_180_128_0" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  remote_ip_prefix  = "10.180.128.0/17"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_all_ICMP_10_180_128_0" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "10.180.128.0/17"
  security_group_id = "${openstack_networking_secgroup_v2.kthw-secgroup.id}"
}


resource "openstack_compute_instance_v2" "master0" {
  name            = "master0"
  image_name      = "${var.image}"
  availability_zone = "${var.az}"
  flavor_id       = "${var.flavor}"
  key_pair        = "${var.key_pair}"
  security_groups = ["${openstack_networking_secgroup_v2.kthw-secgroup.name}"]

  metadata {
    type = "master"
  }
  network {
    port = "${openstack_networking_port_v2.master0_port.id}"
  }
}

resource "openstack_compute_instance_v2" "master1" {
  name            = "master1"
  image_name      = "${var.image}"
  availability_zone = "${var.az}"
  flavor_id       = "${var.flavor}"
  key_pair        = "${var.key_pair}"
  security_groups = ["${openstack_networking_secgroup_v2.kthw-secgroup.name}"]

  metadata {
    type = "master"
  }
  network {
    port = "${openstack_networking_port_v2.master1_port.id}"
  }
}

resource "openstack_compute_instance_v2" "master2" {
  name            = "master2"
  image_name      = "${var.image}"
  availability_zone = "${var.az}"
  flavor_id       = "${var.flavor}"
  key_pair        = "${var.key_pair}"
  security_groups = ["${openstack_networking_secgroup_v2.kthw-secgroup.name}"]

  metadata {
    type = "master"
  }
  network {
    port = "${openstack_networking_port_v2.master2_port.id}"
  }
}

resource "openstack_compute_instance_v2" "minion0" {
  name            = "minion0"
  image_name      = "${var.image}"
  availability_zone = "${var.az}"
  flavor_id       = "${var.flavor}"
  key_pair        = "${var.key_pair}"
  security_groups = ["${openstack_networking_secgroup_v2.kthw-secgroup.name}"]

  metadata {
    type = "minion"
  }
  network {
    port = "${openstack_networking_port_v2.minion0_port.id}"
  }
}

resource "openstack_compute_instance_v2" "minion1" {
  name            = "minion1"
  image_name      = "${var.image}"
  availability_zone = "${var.az}"
  flavor_id       = "${var.flavor}"
  key_pair        = "${var.key_pair}"
  security_groups = ["${openstack_networking_secgroup_v2.kthw-secgroup.name}"]

  metadata {
    type = "minion"
  }
  network {
    port = "${openstack_networking_port_v2.minion1_port.id}"
  }
}

resource "openstack_compute_instance_v2" "minion2" {
  name            = "minion2"
  image_name      = "${var.image}"
  availability_zone = "${var.az}"
  flavor_id       = "${var.flavor}"
  key_pair        = "${var.key_pair}"
  security_groups = ["${openstack_networking_secgroup_v2.kthw-secgroup.name}"]

  metadata {
    type = "minion"
  }
  network {
    port = "${openstack_networking_port_v2.minion2_port.id}"
  }
}

resource "openstack_compute_instance_v2" "gateway" {
  name            = "gateway-KUB"
  image_name      = "${var.image}"
  availability_zone = "${var.az}"
  flavor_id       = "${var.flavor}"
  key_pair        = "${var.key_pair}"
  security_groups = ["${openstack_networking_secgroup_v2.kthw-secgroup.name}"]

  metadata {
    type = "gateway"
  }
  network {
    port = "${openstack_networking_port_v2.gateway_port.id}"
  }
}

resource "openstack_compute_floatingip_associate_v2" "fip_1" {
 floating_ip = "${openstack_compute_floatingip_v2.cluster_fip.address}"
 instance_id = "${openstack_compute_instance_v2.gateway.id}"
}

