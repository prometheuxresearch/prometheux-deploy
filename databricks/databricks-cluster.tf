# Databricks Cluster Configuration for Spark Connect

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">=1.25.0"
    }
  }
}

# Variables for cluster configuration
variable "databricks_host" {
  description = "Databricks workspace URL"
  type        = string
}

variable "databricks_token" {
  description = "Databricks personal access token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Databricks cluster"
  type        = string
  default     = "prometheux-spark-connect"
}

variable "authentication_mode" {
  description = "Authentication mode: 'pat' for Personal Access Token or 'oauth' for OAuth"
  type        = string
  default     = "pat"
  validation {
    condition     = contains(["pat", "oauth"], var.authentication_mode)
    error_message = "Authentication mode must be either 'pat' or 'oauth'."
  }
}

variable "service_principal_id" {
  description = "Service Principal ID for OAuth authentication (required if authentication_mode is 'oauth')"
  type        = string
  default     = ""
}

variable "spark_version" {
  description = "Spark runtime version"
  type        = string
  default     = "17.1.x-scala2.13"
}

variable "node_type_id" {
  description = "AWS instance type for cluster nodes"
  type        = string
  default     = "i3.xlarge"
}

variable "driver_node_type_id" {
  description = "AWS instance type for driver node"
  type        = string
  default     = "i3.xlarge"
}

variable "min_workers" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_workers" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}


# Provider configuration
provider "databricks" {
  host  = var.databricks_host
  token = var.databricks_token
}

# Databricks cluster resource for Spark Connect
resource "databricks_cluster" "spark_connect_cluster" {
  cluster_name            = var.cluster_name
  spark_version           = var.spark_version
  node_type_id           = var.node_type_id
  driver_node_type_id    = var.driver_node_type_id
  
  # Dynamic authentication configuration based on mode
  single_user_name       = var.authentication_mode == "oauth" ? var.service_principal_id : null
  data_security_mode     = "SINGLE_USER"
  
  
  autoscale {
    min_workers = var.min_workers
    max_workers = var.max_workers
  }

  # Enable auto-termination after 30 minutes of inactivity
  autotermination_minutes = 30

  # Spark configuration optimized for Spark Connect
  spark_conf = {
    # Unity Catalog support
    "spark.databricks.unity.catalog.enabled"           = "true"
    "spark.databricks.unityCatalog.volumes.enabled"    = "true"
    
    # Performance optimizations
    "spark.databricks.delta.optimizeWrite.enabled"     = "true"
    "spark.databricks.delta.autoCompact.enabled"       = "true"
    "spark.sql.adaptive.coalescePartitions.enabled"    = "true"
    "spark.sql.execution.arrow.pyspark.enabled"        = "true"
    
    
    # Spark Connect configurations
    "spark.connect.grpc.binding.port"                  = "15002"
    "spark.plugins"                                     = "org.apache.spark.sql.connect.SparkConnectPlugin"
  }

  # Custom tags for resource management
  custom_tags = {
    "Environment"     = "development"
    "Project"         = "prometheux"
    "Purpose"         = "spark-connect-testing"
    "Team"           = "prometheux-team"
    "Architecture"   = "spark-connect"
  }

  # Wait for cluster to be ready
  depends_on = []
}

# Output cluster information
output "cluster_id" {
  description = "ID of the created Databricks cluster"
  value       = databricks_cluster.spark_connect_cluster.id
}

output "cluster_url" {
  description = "URL to access the cluster in Databricks workspace"
  value       = "${var.databricks_host}/#/setting/clusters/${databricks_cluster.spark_connect_cluster.id}/configuration"
}

output "cluster_info" {
  description = "Spark Connect cluster information"
  value = {
    cluster_id = databricks_cluster.spark_connect_cluster.id
    cluster_name = databricks_cluster.spark_connect_cluster.cluster_name
    spark_version = databricks_cluster.spark_connect_cluster.spark_version
    spark_connect_enabled = true
  }
}

output "spark_connect_url" {
  description = "Spark Connect URL for Java client connections"
  value       = "sc://${replace(var.databricks_host, "https://", "")}:443/;token=${var.databricks_token};x-databricks-cluster-id=${databricks_cluster.spark_connect_cluster.id}"
  sensitive   = true
}
