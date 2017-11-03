resource "null_resource" "cluster" {
  triggers {
    cluster_fip_address = "${openstack_compute_floatingip_v2.cluster_fip.address}"
  }

  provisioner "local-exec" "export_kube_pub_addr"{
    command = "export KUBERNETES_PUBLIC_ADDRESS=${openstack_compute_floatingip_v2.cluster_fip.address};echo $KUBERNETES_PUBLIC_ADDRESS > ipaddr.txt"
  }
}
resource "null_resource" "certificates"
{
	provisioner "local-exec" "install_cfssl"{
		command = "$PWD/cert_script.sh"
		# interpreter = ["/bin/sh", "-c"]
	}
}




