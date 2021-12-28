# namespace changes
sed -i "s/<namespace>/$namespace/g" namespace.yaml
sed -i "s/<namespace>/$namespace/g" deployment.yaml
sed -i "s/<namespace>/$namespace/g" hpa.yaml
sed -i "s/<namespace>/$namespace/g" service.yaml
sed -i "s/<namespace>/$namespace/g" ingress.yaml

# deployment.yaml changes
sed -i "s/<container_image_repo>/$container_image_repo/g" deployment.yaml
sed -i "s/<image_tag>/$image_tag/g" deployment.yaml
sed -i "s/<resources_requests_cpu>/$resources_requests_cpu/g" deployment.yaml
sed -i "s/<resources_requests_memory>/$resources_requests_memory/g" deployment.yaml
sed -i "s/<application_base_url>/$application_base_url/g" deployment.yaml
sed -i "s/<install_optional_libs>/$install_optional_libs/g" deployment.yaml

# HPA changes
if [ $cluster_environment == "$gke" ];
then

sed -i "s/<hpa_min_replicas>/$hpa_min_replicas/g" hpa_gke.yaml
sed -i "s/<hpa_max_replicas>/$hpa_max_replicas/g" hpa_gke.yaml

else

sed -i "s/<hpa_min_replicas>/$hpa_min_replicas/g" hpa.yaml
sed -i "s/<hpa_max_replicas>/$hpa_max_replicas/g" hpa.yaml

fi

if [ $deploy_nginx_ingress_controller == "true" ];
then

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.41.2/deploy/static/provider/cloud/deploy.yaml

fi

# ingress.yaml file changes
if [ $enable_ssl != "false" ];
then

sed -i "s/<dns_host>/$dns_host/g" ingress.yaml

sed -i "439,442 s/##*//" ingress.yaml
sed -i "444 s/##*//" ingress.yaml

kubectl create secret tls boldbi-tls --key $ssl_key_path --cert $ssl_cert_path

fi


kubectl apply -f ingress.yaml

# Get ingress IP

# pvclaim file changes
if [ $cluster_environment == "gke" ]
then
sed -i "s/<namespace>/$namespace/g" hpa_gke.yaml
sed -i "s/<namespace>/$namespace/g" pvclaim_gke.yaml

sed -i "s/<file_share_name>/$gke_file_share_name/g" pvclaim_gke.yaml
sed -i "s/<file_share_ip_address>/$gke_file_share_ip_address/g" pvclaim_gke.yaml

kubectl apply -f pvclaim_gke.yaml

elif [ $cluster_environment == "$eks" ];
then
sed -i "s/<efs_file_system_id>/$eks_efs_file_system_id/g" pvclaim_eks.yaml

kubectl apply -f pvclaim_eks.yaml

elif [ $cluster_environment == "$aks" ];
then
sed -i "s/<base64_azurestorageaccountname>/$aks_base64_azurestorageaccountname/g" pvclaim_aks.yaml
sed -i "s/<base64_azurestorageaccountkey>/$aks_base64_azurestorageaccountkey/g" pvclaim_aks.yaml
sed -i "s/<file_share_name>/$aks_file_share_name/g" pvclaim_aks.yaml

kubectl apply -f pvclaim_aks.yaml

elif [ $cluster_environment == "$onpremise" ];
then
sed -i "s/<onpremise_hostPath>/$onpremise_hostPath/g" pvclaim_onpremise.yaml

kubectl apply -f pvclaim_onpremise.yaml

fi

kubectl apply -f deployment.yaml
kubectl apply -f hpa_gke.yaml
kubectl apply -f service.yaml