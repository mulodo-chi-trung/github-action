variable "project" {
  type = "string"
  description = "project id"
  default = "terraform-250704"
}

variable "region" {
  type = "string"
  description = "region of cluster - Jurong West Singapore"
  default = "asia-southeast1"
}

variable "zone" {
  type = "string"
  description = "zone of region"
  default = "us-east1-c"
}

variable "additional_zones" {
  type = "list"
  description = "list additional zones of region"
  default = ["us-east1-b", "us-east1-d"]
}

variable "username" {
  type = "string"
  description = "User name for authentication to the Kubernetes linux agent virtual machines in the cluster."
}

variable "password" {
  type = "string"
  description = "The password for the Linux admin account."
}

variable "gcp_node_count" {
  type = "string"
  description = "The number of nodes to create in this cluster's default node pool."
}

variable "cluster_name" {
  type = "string"
  description = "Cluster name for the GCP Cluster."
}

variable "machine_type" {
  type = "string"
  description = "Customize to select cores, memory and GPUs"
  default = "n1-standard-1"
}