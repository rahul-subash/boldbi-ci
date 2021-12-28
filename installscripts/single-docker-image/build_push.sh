#!/usr/bin/env bash
# Copyright (c) Syncfusion Inc. All rights reserved.
#

work_dir="../application"

while [ $# -gt 0 ]; do
  case "$1" in
    --tag=*)
      tag="${1#*=}"
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

if [ -z "$registry" ]
then
	registry="development"
fi

if [ -z "$base" ]
then
	base="debian"
fi

if [ -z "$actions" ]
then
	actions="move-files,build,push"
fi

if [ "$registry" = "development" ]; then	
	registry="gcr.io/boldbi-dev-296107/boldbi-docker"			
elif [ "$registry" = "production" ]; then	
	registry="gcr.io/boldbi-294612/boldbi"
elif [ "$registry" = "dockerhub" ]; then
    registry="syncfusion/boldbi"
fi

if [ "$base" = "debian" ]; then
	base="boldbi-debian"
elif [ "$base" = "arm64" ]; then
	base="boldbi-debian-arm64"
elif [ "$base" = "alpine" ]; then
	base="boldbi-alpine"
elif [ "$base" = "focal" ]; then
	base="boldbi-ubuntu"
fi

IFS=',' read -r -a buildactions <<< "$actions"

for act in "${buildactions[@]}"
do

case $act in
"move-files")
### Move shared files
echo "moving shared files"
if [ ! -d "$work_dir/clientlibrary" ]; then cp -a "boldbi/clientlibrary" $work_dir; fi
if [ ! -f "$work_dir/boldbi-nginx-config" ]; then cp -a "boldbi/boldbi-nginx-config" $work_dir; fi
if [ ! -f "$work_dir/entrypoint.sh" ]; then cp -a "boldbi/entrypoint.sh" $work_dir; fi
if [ ! -f "$work_dir/product.json" ]; then cp -a "$work_dir/app_data/configuration/product.json" $work_dir; fi
if [ -f "$work_dir/product.json" ]; then
	if ! grep -qF "host.docker.internal" $work_dir/product.json; then
		sed -i 's|localhost:51894|localhost|g' $work_dir/product.json
	fi
fi
if [ ! -f "$work_dir/clientlibrary/MongoDB.Driver.dll" ]; then unzip "../clientlibrary/clientlibrary.zip" -d "$work_dir/clientlibrary/"; fi
if [ -d "$work_dir/app_data" ]; then rm -rf "$work_dir/app_data"; fi
###
;;

"build")
docker build -t $registry:$tag -f dockerfiles/$base.txt ../
;;

"push")
docker push $registry:$tag
;;

esac
done
