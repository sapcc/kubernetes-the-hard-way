terraform {
  backend "swift" {
    path = "kthw-tf-state"
	archive_container = "kthw-tf-state_old_versions"
  }
}