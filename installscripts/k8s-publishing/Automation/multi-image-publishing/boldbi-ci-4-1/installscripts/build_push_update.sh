#!/usr/bin/env bash
# Copyright (c) Syncfusion Inc. All rights reserved.
#

# apps=id-web,id-api,id-ums,bi-web,bi-api,bi-jobs,bi-dataservice

apps=$1
image_tag=$2
namespace=$3

if [ -z "$namespace" ]
then
	namespace="default"
fi

IFS=',' read -r -a appnames <<< "$apps"

for app in "${appnames[@]}"
do

case $app in
"id-web")
docker build -t gcr.io/boldbi-294612/boldbi-identity:$image_tag -f boldbi-identity.txt .
docker push gcr.io/boldbi-294612/boldbi-identity:$image_tag
kubectl set image deployment/id-web-deployment id-web-container=gcr.io/boldbi-294612/boldbi-identity:$image_tag --namespace=$namespace --record
;;
"id-api")
docker build -t gcr.io/boldbi-294612/boldbi-identity-api:$image_tag -f boldbi-identity-api.txt .
docker push gcr.io/boldbi-294612/boldbi-identity-api:$image_tag
kubectl set image deployment/id-api-deployment id-api-container=gcr.io/boldbi-294612/boldbi-identity-api:$image_tag --namespace=$namespace --record
;;
"id-ums")
docker build -t gcr.io/boldbi-294612/boldbi-ums:$image_tag -f boldbi-ums.txt .
docker push gcr.io/boldbi-294612/boldbi-ums:$image_tag
kubectl set image deployment/id-ums-deployment id-ums-container=gcr.io/boldbi-294612/boldbi-ums:$image_tag --namespace=$namespace --record
;;
"bi-web")
docker build -t gcr.io/boldbi-294612/boldbi-server:$image_tag -f boldbi-server.txt .
docker push gcr.io/boldbi-294612/boldbi-server:$image_tag
kubectl set image deployment/bi-web-deployment bi-web-container=gcr.io/boldbi-294612/boldbi-server:$image_tag --namespace=$namespace --record
;;
"bi-api")
docker build -t gcr.io/boldbi-294612/boldbi-server-api:$image_tag -f boldbi-server-api.txt .
docker push gcr.io/boldbi-294612/boldbi-server-api:$image_tag
kubectl set image deployment/bi-api-deployment bi-api-container=gcr.io/boldbi-294612/boldbi-server-api:$image_tag --namespace=$namespace --record
;;
"bi-jobs")
docker build -t gcr.io/boldbi-294612/boldbi-server-jobs:$image_tag -f boldbi-server-jobs.txt .
docker push gcr.io/boldbi-294612/boldbi-server-jobs:$image_tag
kubectl set image deployment/bi-jobs-deployment bi-jobs-container=gcr.io/boldbi-294612/boldbi-server-jobs:$image_tag --namespace=$namespace --record
;;
"bi-dataservice")
docker build -t gcr.io/boldbi-294612/boldbi-designer:$image_tag -f boldbi-designer.txt .
docker push gcr.io/boldbi-294612/boldbi-designer:$image_tag
kubectl set image deployment/bi-dataservice-deployment bi-dataservice-container=gcr.io/boldbi-294612/boldbi-designer:$image_tag --namespace=$namespace --record
;;
esac

done
