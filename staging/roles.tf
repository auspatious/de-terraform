# Generic read/write role
module "service_account" {
  source = "../modules/service-account"

  name              = "public-bucket-writer"
  namespace         = "argo"
  oidc_provider_arn = module.resources.cluster_oidc_provider_arn
  write_bucket_names = [
    module.resources.public_bucket_name
  ]
  read_bucket_names = [
    "usgs-landsat",
    "copernicus-dem-30m",
    "e84-earth-search-sentinel-data",
    module.resources.public_bucket_name
  ]
  create_sa = true
}

module "public_bucket_reader" {
  source = "../modules/service-account"

  name              = "public-bucket-reader"
  namespace         = "argo"
  oidc_provider_arn = module.resources.cluster_oidc_provider_arn
  write_bucket_names = [
    "fake-bucket"
  ]
  read_bucket_names = [
    "usgs-landsat",
    "copernicus-dem-30m",
    "e84-earth-search-sentinel-data",
    module.resources.public_bucket_name
  ]
  create_sa = true
}
