export namespace="boldbi"

container_image_repo="gcr.io/boldbi-294612"
image_tag="4.1.1"
resources_requests_cpu="250m"
resources_requests_memory="750Mi"
application_base_url=""
install_optional_libs=""

hpa_min_replicas=1
hpa_max_replicas=20

dns_host=""
enable_ssl="false"
ssl_cert_path=""
ssl_key_path=""

cluster_environment=""

gke_file_share_name=""
gke_file_share_ip_address=""

eks_efs_file_system_id=""

aks_base64_azurestorageaccountname=""
aks_base64_azurestorageaccountkey=""
aks_file_share_name=""

onpremise_hostPath="/run/desktop/mnt/host/<local_directory>"

deploy_nginx_ingress_controller="true"

./deploy.sh