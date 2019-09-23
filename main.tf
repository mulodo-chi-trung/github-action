provider "google" {
  credentials = file("elastic-cluster-ce656e122e71.json")
  project = var.project
  region = var.region
}

resource "google_container_cluster" "gcp_kubernetes" {
  name = var.cluster_name
  location = var.zone
  initial_node_count = var.gcp_node_count
  master_auth {
    username = var.username
    password = var.password
  }

  node_config {
    machine_type = "n1-standard-2"
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = "dev-cluster"
    }

    tags = ["dev", "demo"]
  }
}

resource "kubernetes_service" "svc_kube_elastic_search" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name = "es-nodes"
    labels = {
      service = "elasticsearch"
    }
    namespace = "default"
  }
  spec {
    type = "NodePort"
    selector = {
      service = "elasticsearch"
    }
    port {
      name = "external"
      port = 9200
      protocol = "TCP"
      target_port = 9200
    }
    port {
      name = "internal"
      port = 9300
      protocol = "TCP"
      target_port = 9300
    }
  }
}

resource "kubernetes_stateful_set" "sfs_kube_elastic_search" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name = "elasticsearch"
    labels = {
      service = "elasticsearch"
    }
  }
  spec {
    service_name = "es-nodes"
    replicas = 3
    selector {
      match_labels = {
        service = "elasticsearch"
      }
    }
    template {
      metadata {
        labels = {
          service = "elasticsearch"
        }
      }
      spec {
        termination_grace_period_seconds = 300
        init_container {
          name = "ulimit"
          image = "busybox"
          command = ["sh", "-c", "ulimit", "-n", "65536"]
          security_context {
            privileged = "true"
          }
        }
        init_container {
          name = "vm-max-map-count"
          image = "busybox"
          command = ["sysctl", "-w", "vm.max_map_count=262144"]
          security_context {
            privileged = "true"
          }
        }
        init_container {
          name = "volume-permission"
          image = "busybox"
          command = ["chown", "-R", "1000:1000", "/usr/share/elasticsearch/data"]
          security_context {
            privileged = "true"
          }
          volume_mount {
            name = "data"
            mount_path = "/usr/share/elasticsearch/data"
          }
        }
        container {
          name = "elasticsearch"
          image = "docker.elastic.co/elasticsearch/elasticsearch:6.4.3"
          port {
            container_port = 9200
            name = "http"
          }
          port {
            container_port = 9300
            name = "tcp"
          }
          resources {
            requests {
              memory = "400Mi"
            }
            limits {
              memory = "1Gi"
            }
          }
          env {
            name = "cluster.name"
            value = "elasticsearch-cluster"
          }
          env {
            name = "node.name"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }   
            } 
          }
          env {
            name = "discovery.zen.ping.unicast.hosts"
            value = "elasticsearch-0.es-nodes.default.svc.cluster.local,elasticsearch-1.es-nodes.default.svc.cluster.local,elasticsearch-2.es-nodes.default.svc.cluster.local"
          }
          env {
            name = "ES_JAVA_OPTS"
            value = "-Xms512m -Xmx512m"
          }
          volume_mount {
            name = "data"
            mount_path = "/usr/share/elasticsearch/data"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        storage_class_name = "standard"
        resources {
          requests = {
            storage = "5Gi"
          }
        }
      }
    }
  } 
}

resource "kubernetes_service" "svc_kube_kibana" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name = "kibana"
    labels = {
      service = "kibana"
    }
    namespace = "default"
  }
  spec {
    type = "LoadBalancer"
    selector = {
      run = "kibana"
    }
    port {
      port = 8081
      target_port = 5601
    }
  }
}

resource "kubernetes_deployment" "depl_kube_kibana" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name = "kibana"
    namespace = "default"
  }
  spec {
    selector {
      match_labels = {
        run = "kibana"
      }
    }

    template {
      metadata {
        labels = {
          run = "kibana"
        }
      }

      spec {
        container {
          name = "kibana"
          image = "docker.elastic.co/kibana/kibana-oss:6.4.3"
          resources {
            limits {
              cpu = "1000m"
            }
            requests {
              cpu = "100m"
            }
          }
          env {
            name = "ELASTICSEARCH_URL"
            value = "http://es-nodes:9200"
          }
          port {
            container_port = 5601
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account" "svc_account" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name = "fluentd"
  }
}

resource "kubernetes_cluster_role" "cluster_role" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name = "fluentd"
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "cluster_role_binding" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name = "fluentd"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "fluentd"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "fluentd"
    namespace = "default"
  }
}

resource "kubernetes_daemonset" "deamon_fluent" {
  depends_on = [google_container_cluster.gcp_kubernetes]
  metadata {
    name      = "fluentd"
    namespace = "default"
    labels = {
      k8s-app = "fluentd-logging"
      version =  "v1"
      "kubernetes.io/cluster-service" = "true"
    }
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "fluentd-logging"
        version =  "v1"
        "kubernetes.io/cluster-service" = "true"
      }
    }
    template {

      metadata {
        labels = {
          k8s-app = "fluentd-logging"
          version =  "v1"
          "kubernetes.io/cluster-service" = "true"
        }
      }

      spec {
        service_account_name = "fluentd"
        toleration {
          key = "node-role.kubernetes.io/master"
          effect = "NoSchedule"
        }
        automount_service_account_token = "true"
        container {
          image = "fluent/fluentd-kubernetes-daemonset:v1.3-debian-elasticsearch"
          name  = "fluentd"
          env {
            name = "FLUENT_ELASTICSEARCH_HOST"
            value = "es-nodes"
          }
          env {
            name = "FLUENT_ELASTICSEARCH_PORT"
            value = "9200"
          }
          env {
            name = "FLUENT_ELASTICSEARCH_SCHEME"
            value = "http"
          }
          env {
            name = "FLUENT_UID"
            value = "0"
          }
          resources {
            limits {
              memory = "200Mi"
            }
            requests {
              cpu    = "100m"
              memory = "200Mi"
            }
          }
          volume_mount {
            name = "varlog"
            mount_path = "/var/log"
          }
          volume_mount {
            name = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only = "true"
          }
        }
        termination_grace_period_seconds = 30
        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }
        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
      }
    }
  }
}