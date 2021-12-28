#!/usr/bin/env bash
# Copyright (c) Syncfusion Inc. All rights reserved.
#

while [ $# -gt 0 ]; do
  case "$1" in
    --apps=*)
      apps="${1#*=}"
      ;;
    --dev_tag=*)
      dev_tag="${1#*=}"
      ;;
	--prod_tag=*)
      prod_tag="${1#*=}"
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

IFS=',' read -r -a appnames <<< "$apps"


for app in "${appnames[@]}"
do

case $app in
"id-web")
docker tag gcr.io/boldbi-dev-296107/bold-identity:$dev_tag gcr.io/boldbi-294612/bold-identity:$prod_tag
docker push gcr.io/boldbi-294612/bold-identity:$prod_tag
;;
"id-api")
docker tag gcr.io/boldbi-dev-296107/bold-identity-api:$dev_tag gcr.io/boldbi-294612/bold-identity-api:$prod_tag
docker push gcr.io/boldbi-294612/bold-identity-api:$prod_tag
;;
"id-ums")
docker tag gcr.io/boldbi-dev-296107/bold-ums:$dev_tag gcr.io/boldbi-294612/bold-ums:$prod_tag
docker push gcr.io/boldbi-294612/bold-ums:$prod_tag
;;
"bi-web")
docker tag gcr.io/boldbi-dev-296107/boldbi-server:$dev_tag gcr.io/boldbi-294612/boldbi-server:$prod_tag
docker push gcr.io/boldbi-294612/boldbi-server:$prod_tag
;;
"bi-api")
docker tag gcr.io/boldbi-dev-296107/boldbi-server-api:$dev_tag gcr.io/boldbi-294612/boldbi-server-api:$prod_tag
docker push gcr.io/boldbi-294612/boldbi-server-api:$prod_tag
;;
"bi-jobs")
docker tag gcr.io/boldbi-dev-296107/boldbi-server-jobs:$dev_tag gcr.io/boldbi-294612/boldbi-server-jobs:$prod_tag
docker push gcr.io/boldbi-294612/boldbi-server-jobs:$prod_tag
;;
"bi-dataservice")
docker tag gcr.io/boldbi-dev-296107/boldbi-designer:$dev_tag gcr.io/boldbi-294612/boldbi-designer:$prod_tag
docker push gcr.io/boldbi-294612/boldbi-designer:$prod_tag
;;
esac

done
