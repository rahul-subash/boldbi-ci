#!/usr/bin/env bash
# Copyright (c) Syncfusion Inc. All rights reserved.
#

while [ $# -gt 0 ]; do
  case "$1" in
    --apps=*)
      apps="${1#*=}"
      ;;
    --tag=*)
      tag="${1#*=}"
      ;;
    --namespace=*)
      namespace="${1#*=}"
      ;;
    --base=*)
      base="${1#*=}"
      ;;
    --actions=*)
      actions="${1#*=}"
      ;;
	--registry=*)
      registry="${1#*=}"
      ;;

    *)
  esac
  shift
done

[ -n "$tag" ] || read -p 'Enter the image tag to build: ' tag

if [ -z "$apps" ]
then
	apps="id-web,id-api,id-ums,bi-web,bi-api,bi-jobs,bi-dataservice"
fi

if [ -z "$namespace" ]
then
	namespace="default"
fi

if [ -z "$registry" ]
then
	registry="development"
fi

if [ "$registry" = "development" ]; then	
	registry="boldbi-dev-296107"				
elif [ "$registry" = "production" ]; then	
	registry="boldbi-294612"
fi	

if [ -z "$base" ]
then
	base="ubuntu"
fi

if [ -z "$actions" ]
then
	actions="build,push,update"
fi

IFS=',' read -r -a buildactions <<< "$actions"
IFS=',' read -r -a appnames <<< "$apps"

for act in "${buildactions[@]}"
do

case $act in
"build")

for app in "${appnames[@]}"
do

case $app in
"id-web")
docker build -t gcr.io/$registry/bold-identity:$tag -f $base/boldbi-identity.txt ../
;;
"id-api")
docker build -t gcr.io/$registry/bold-identity-api:$tag -f $base/boldbi-identity-api.txt ../
;;
"id-ums")
docker build -t gcr.io/$registry/bold-ums:$tag -f $base/boldbi-ums.txt ../
;;
"bi-web")
docker build -t gcr.io/$registry/boldbi-server:$tag -f $base/boldbi-server.txt ../
;;
"bi-api")
docker build -t gcr.io/$registry/boldbi-server-api:$tag -f $base/boldbi-server-api.txt ../
;;
"bi-jobs")
docker build -t gcr.io/$registry/boldbi-server-jobs:$tag -f $base/boldbi-server-jobs.txt ../
;;
"bi-dataservice")
docker build -t gcr.io/$registry/boldbi-designer:$tag -f $base/boldbi-designer.txt ../
;;
esac

done

;;
"push")

for app in "${appnames[@]}"
do

case $app in
"id-web")
docker push gcr.io/$registry/bold-identity:$tag
;;
"id-api")
docker push gcr.io/$registry/bold-identity-api:$tag
;;
"id-ums")
docker push gcr.io/$registry/bold-ums:$tag
;;
"bi-web")
docker push gcr.io/$registry/boldbi-server:$tag
;;
"bi-api")
docker push gcr.io/$registry/boldbi-server-api:$tag
;;
"bi-jobs")
docker push gcr.io/$registry/boldbi-server-jobs:$tag
;;
"bi-dataservice")
docker push gcr.io/$registry/boldbi-designer:$tag
;;
esac

done

;;
"update")

for app in "${appnames[@]}"
do

case $app in
"id-web")
kubectl set image deployment/id-web-deployment id-web-container=gcr.io/$registry/bold-identity:$tag --namespace=$namespace --record
;;
"id-api")
kubectl set image deployment/id-api-deployment id-api-container=gcr.io/$registry/bold-identity-api:$tag --namespace=$namespace --record
;;
"id-ums")
kubectl set image deployment/id-ums-deployment id-ums-container=gcr.io/$registry/bold-ums:$tag --namespace=$namespace --record
;;
"bi-web")
kubectl set image deployment/bi-web-deployment bi-web-container=gcr.io/$registry/boldbi-server:$tag --namespace=$namespace --record
;;
"bi-api")
kubectl set image deployment/bi-api-deployment bi-api-container=gcr.io/$registry/boldbi-server-api:$tag --namespace=$namespace --record
;;
"bi-jobs")
kubectl set image deployment/bi-jobs-deployment bi-jobs-container=gcr.io/$registry/boldbi-server-jobs:$tag --namespace=$namespace --record
;;
"bi-dataservice")
kubectl set image deployment/bi-dataservice-deployment bi-dataservice-container=gcr.io/$registry/boldbi-designer:$tag --namespace=$namespace --record
;;
esac

done

;;
esac

done
