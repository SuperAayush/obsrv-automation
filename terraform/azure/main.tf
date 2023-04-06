terraform {
  backend "azurerm" {
    resource_group_name  = "obsrv-terraform-rg"
    storage_account_name = "obsrvterraformstorage"
    container_name       = "obsrv-dev-terraform-state"
    key                  = "dev.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    local = {
      source = "hashicorp/local"
      version  = "~> 2.0"
    }
    helm = {
      source = "hashicorp/helm"
      version  = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "network" {
  source          = "../modules/azure/network"
  env             = "test"
  building_block  = "keshav"
}

module "aks" {
  source              = "../modules/azure/aks"
  env                 = "test"
  building_block      = "keshav"
  resource_group_name = module.network.resource_group_name
}

module "storage" {
  source              = "../modules/azure/storage"
  env                 = "test"
  building_block      = "keshav"
  resource_group_name = module.network.resource_group_name
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kubernetes_host
    client_certificate     = module.aks.client_certificate
    client_key             = module.aks.client_key
    cluster_ca_certificate = module.aks.cluster_ca_certificate
  }
}

module "promtail" {
  source                    = "../modules/helm/promtail"
  env                       = "test"
  building_block            = "keshav"
  promtail_chart_depends_on = [module.loki]
}

module "loki" {
  source         = "../modules/helm/loki"
  env            = "test"
  building_block = "keshav"
}

module "monitoring" {
  source         = "../modules/helm/monitoring"
  env            = "test"
  building_block = "keshav"
}

module "superset" {
  source                            = "../modules/helm/superset"
  env                               = "test"
  building_block                    = "keshav"
  postgresql_admin_username         = module.postgresql.postgresql_admin_username
  postgresql_admin_password         = module.postgresql.postgresql_admin_password
  postgresql_superset_user_password = module.postgresql.postgresql_superset_user_password
  superset_image_tag                = var.superset_image_tag
  superset_chart_depends_on         = [module.postgresql]
}

module "grafana_configs" {
  source                           = "../modules/helm/grafana_configs"
  env                              = "test"
  building_block                   = "keshav"
  grafana_configs_chart_depends_on = [module.monitoring]
}

module "postgresql" {
  source               = "../modules/helm/postgresql"
  env                  = "test"
  building_block       = "keshav"
  postgresql_image_tag = var.postgresql_image_tag
}

module "kafka" {
  source         = "../modules/helm/kafka"
  env            = "test"
  building_block = "keshav"
}

module "flink" {
  source                         = "../modules/helm/flink"
  env                            = "test"
  building_block                 = "keshav"
  flink_image_tag                = var.flink_image_tag
  azure_storage_account_name     = module.storage.azurerm_storage_account_name
  azure_storage_account_key      = module.storage.azurerm_storage_account_key
  flink_checkpoint_store_type    = var.flink_checkpoint_store_type
  flink_chart_depends_on         = [module.kafka]
  postgresql_flink_user_password = module.postgresql.postgresql_flink_user_password
}

module "druid_raw_cluster" {
  source                             = "../modules/helm/druid_raw_cluster"
  env                                = "test"
  building_block                     = "keshav"
  azure_storage_account_name         = module.storage.azurerm_storage_account_name
  azure_storage_account_key          = module.storage.azurerm_storage_account_key
  azure_storage_container            = module.storage.azurerm_storage_container
  druid_deepstorage_type             = var.druid_deepstorage_type
  druid_raw_cluster_chart_depends_on = [module.postgresql, module.druid_operator]
  kubernetes_storage_class           = var.kubernetes_storage_class
  druid_raw_user_password            = module.postgresql.postgresql_druid_raw_user_password
}

module "druid_operator" {
  source         = "../modules/helm/druid_operator"
  env            = "test"
  building_block = "keshav"
}

module "kafka_exporter" {
  source                          = "../modules/helm/kafka_exporter"
  env                             = "test"
  building_block                  = "keshav"
  kafka_exporter_chart_depends_on = [module.kafka, module.monitoring]
}

module "postgresql_exporter" {
  source                               = "../modules/helm/postgresql_exporter"
  env                                  = "test"
  building_block                       = "keshav"
  postgresql_exporter_chart_depends_on = [module.postgresql, module.monitoring]
}

module "druid_exporter" {
  source                          = "../modules/helm/druid_exporter"
  env                             = "test"
  building_block                  = "keshav"
  druid_exporter_chart_depends_on = [module.druid_raw_cluster, module.monitoring]
}

module "dataset_api" {
  source                             = "../modules/helm/dataset_api"
  env                                = "test"
  building_block                     = "keshav"
  dataset_api_postgres_user_password = module.postgresql.postgresql_dataset_api_user_password
  dataset_api_chart_depends_on       = [module.postgresql, module.kafka]
}

module "secor" {
  source                 = "../modules/helm/secor"
  env                    = "test"
  building_block         = "keshav"
  secor_chart_depends_on = [module.kafka]
}

module "submit_ingestion" {
  source                            = "../modules/helm/submit_ingestion"
  env                               = "test"
  building_block                    = "keshav"
  submit_ingestion_chart_depends_on = [module.kafka, module.druid_raw_cluster]
}