#!/usr/bin/env bash
# Copyright (c) Syncfusion Inc. All rights reserved.
#

# Stop script on NZEC
set -e
# Stop script if unbound variable found (use ${var:-} if intentional)
set -u
# By default cmd1 | cmd2 returns exit code of cmd2 regardless of cmd1 success
# This is causing it to fail
set -o pipefail

# Use in the the functions: eval $invocation
invocation='say_verbose "Calling: ${yellow:-}${FUNCNAME[0]} ${green:-}$*${normal:-}"'

# standard output may be used as a return value in the functions
# we need a way to write text on the screen in the functions so that
# it won't interfere with the return value.
# Exposing stream 3 as a pipe to standard output of the script itself
exec 3>&1

verbose=true
args=("$@")
services="id-web,id-api,id-ums,bi-web,bi-api,bi-jobs,bi-dataservice"
tag=""
namespace="default"
base="ubuntu"
actions="build,push,update"
registry="development"
image_repo=""
package=""
version="4.2.x"
build_context_path=""
package_file_name=""
unzip_output=""
cluster=""
kube_config=""
work_dir=""
ci_proj_4_1="boldbi-ci-4-1"
ci_proj_4_2="boldbi-ci-4-2"
appdatafiles_4_2="/output/installutils"
appdatafiles_4_1="/output/MoveSharedFiles"
shell_scripts_4_2="/installutils/installutils/shell_scripts"
shell_scripts_4_1="/MoveSharedFiles/MoveSharedFiles/shell_scripts"
product_json=""

while [ $# -ne 0 ]
do
    name="$1"
    case "$name" in
        -s|--services)
            shift
            services="$1"
            ;;
			
		-t|--tag)
            shift
            tag="$1"
            ;;
			
		-n|--namespace)
            shift
            namespace="$1"
            ;;
			
		-b|--base)
            shift
            base="$1"
            ;;
			
		-a|--actions)
            shift
			actions="$1"
            ;;
			
		-r|--registry)
            shift
			registry="$1"	
            ;;

		-p|--package)
            shift
			package="$1"	
            ;;
			
		-v|--version)
            shift
			version="$1"	
            ;;
		
		-c|--cluster)
            shift
			cluster="$1"	
            ;;
        
        -?|--?|--help|-[Hh]elp)
            script_name="$(basename "$0")"
            echo "Bold BI Installer"
            echo "Usage: $script_name [-u|--user <USER>]"
            echo "       $script_name |-?|--help"
            echo ""
            exit 0
            ;;
        *)
            say_err "Unknown argument \`$name\`"
            exit 1
            ;;
    esac

    shift
done

# Setup some colors to use. These need to work in fairly limited shells, like the Ubuntu Docker container where there are only 8 colors.
# See if stdout is a terminal
if [ -t 1 ] && command -v tput > /dev/null; then
    # see if it supports colors
    ncolors=$(tput colors)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        bold="$(tput bold       || echo)"
        normal="$(tput sgr0     || echo)"
        black="$(tput setaf 0   || echo)"
        red="$(tput setaf 1     || echo)"
        green="$(tput setaf 2   || echo)"
        yellow="$(tput setaf 3  || echo)"
        blue="$(tput setaf 4    || echo)"
        magenta="$(tput setaf 5 || echo)"
        cyan="$(tput setaf 6    || echo)"
        white="$(tput setaf 7   || echo)"
    fi
fi

say_warning() {
    printf "%b\n" "${yellow:-}multi-image-publish automation: Warning: $1${normal:-}" >&3
}

say_err() {
    printf "%b\n" "${red:-}multi-image-publish automation: Error: $1${normal:-}" >&2
}

say_success() {
    printf "%b\n" "${green:-}multi-image-publish automation: Success: $1${normal:-}" >&2
}

say() {
    # using stream 3 (defined in the beginning) to not interfere with stdout of functions
    # which may be used as return value
    printf "%b\n" "${cyan:-}multi-image-publish automation:${normal:-} $1" >&3
}

say_verbose() {
    if [ "$verbose" = true ]; then
        say "$1"
    fi
}

machine_has() {
    eval $invocation

    hash "$1" > /dev/null 2>&1
    return $?
}

# args:
# input - $1
remove_trailing_slash() {
    #eval $invocation

    local input="${1:-}"
    echo "${input%/}"
    return 0
}

# args:
# input - $1
remove_beginning_slash() {
    #eval $invocation

    local input="${1:-}"
    echo "${input#/}"
    return 0
}

check_min_req() {
    eval $invocation
	
    [ -n "$tag" ] || read -p 'Enter the image tag to build: ' tag
	
	if [ "$registry" = "development" ]; then	
		image_repo="boldbi-dev-296107"				
	elif [ "$registry" = "production" ]; then	
		image_repo="boldbi-294612"
	fi	

	if [[ "$version" == *"4.2"* ]]
	then
	    package_file_name="../4-2_packages/BoldBIEnterpriseEdition_Linux_$version.zip"
	    unzip_output="../4-2_packages/BoldBIEnterpriseEdition_Linux_$version"
	    build_context_path="$unzip_output/BoldBIEnterpriseEdition-Linux/"	
		
	    if [ $base = "ubuntu" ]; then
	        base="$unzip_output/BoldBIEnterpriseEdition-Linux/4-2_dockerfiles/ubuntu"
	    elif [ $base = "debian" ]; then
	        base="$unzip_output/BoldBIEnterpriseEdition-Linux/4-2_dockerfiles/debian"
	    fi
	elif [[ "$version" == *"4.1"* ]]
	then
	    package_file_name="../4-1_packages/BoldBIEnterpriseEdition_Linux_$version.zip"
		unzip_output="../4-1_packages/BoldBIEnterpriseEdition_Linux_$version"
	    build_context_path="$unzip_output/BoldBIEnterpriseEdition-Linux/"
		
	    if [ $base = "ubuntu" ]; then
	        base="$unzip_output/BoldBIEnterpriseEdition-Linux/4-1_dockerfiles/ubuntu"
	    elif [ $base = "debian" ]; then
	        base="$unzip_output/BoldBIEnterpriseEdition-Linux/4-1_dockerfiles/debian"
	    fi
	fi
}

download_package() {
    eval $invocation
	if [ -f $package_file_name ]; then
	    say_warning "Package already exist. Skipping download..."
	else
	    wget -O $package_file_name $package
	fi
}

unzip_package() {
    eval $invocation
	unzip $package_file_name -d $unzip_output
}

move_shared_files() {
    eval $invocation
	
	if [[ "$version" == *"4.2"* ]]
	then
	    work_dir="$unzip_output/BoldBIEnterpriseEdition-Linux/application"
        package_appdatafiles="$work_dir/idp/web/appdatafiles"
	    appdatafiles="$ci_proj_4_2$appdatafiles_4_2"
	    shell_scripts="$ci_proj_4_2$shell_scripts_4_2"
		product_json="$package_appdatafiles/installutils/app_data"	
		if [ ! -d "$build_context_path/4-2_dockerfiles" ]; then cp -a "4-2_dockerfiles" $build_context_path; fi
	elif [[ "$version" == *"4.1"* ]]
	then
	    work_dir="$unzip_output/BoldBIEnterpriseEdition-Linux/boldbi/"
		package_appdatafiles="$work_dir/idp/web/appdatafiles"
	    appdatafiles="$ci_proj_4_1$appdatafiles_4_1"
	    shell_scripts="$ci_proj_4_1$shell_scripts_4_1"
		product_json="$package_appdatafiles/MoveSharedFiles/app_data"
		if [ ! -d "$build_context_path/4-1_dockerfiles" ]; then cp -a "4-1_dockerfiles" $build_context_path; fi
	fi
	
	if [ ! -d $package_appdatafiles ]; then
	    mkdir $package_appdatafiles	 
        say "Copying appdatafiles to $package_appdatafiles"
        cp -a $appdatafiles $package_appdatafiles
	fi

	if [ ! -f "$work_dir/idp/web/entrypoint.sh" ]; then
	    say "Copying idp scripts to $work_dir/idp/web/"
	    cp -a "$shell_scripts/id_web/entrypoint.sh" "$work_dir/idp/web/"
	fi
	
	if [ ! -f "$work_dir/bi/dataservice/entrypoint.sh" ]; then
	    say "Copying designer scripts to $work_dir/bi/designer/"
	    cp -a "$shell_scripts/designer/entrypoint.sh" "$work_dir/bi/dataservice/"
	fi
	
	if [ ! -f "$work_dir/bi/dataservice/install-optional.libs.sh" ]; then
        cp -a "$shell_scripts/designer/install-optional.libs.sh" "$work_dir/bi/dataservice/"
	fi
	
	if [ ! -f "$product_json/configuration/product.json" ]; then
	    say "Copying product.json file to $product_json/configuration"
	    cp -a "$work_dir/app_data/configuration" $product_json
	fi
	
	if [ ! -f "$product_json/optional-libs/MongoDB.Driver.dll" ]; then
	    say "Un-zipping clientlibrary.zip to $product_json/optional-libs/"
	    unzip "$unzip_output/BoldBIEnterpriseEdition-Linux/clientlibrary/clientlibrary.zip" -d "$product_json/optional-libs/"
	fi
}

login_to_image_repo() {
    eval $invocation
	
	if [ $registry == "development" ]; then
		gcloud auth activate-service-account boldreports@boldbi-dev-296107.iam.gserviceaccount.com --key-file='D:\Confidential\gcr-access-cred\boldreports-service-account.json'
	elif [ $registry == "production" ]; then
		gcloud auth activate-service-account kubernetes@boldbi-294612.iam.gserviceaccount.com --key-file=/mnt/e/Confidential/gcr-access-cred/boldbi-294612-87f2999e6132.json
	fi
	
	say_success "Login successful for $image_repo account"
}

build_push_update() {
    eval $invocation
	
	check_min_req
	
	# if [ ! -z $package ]; then
	    # download_package
	# fi
	
	# if [ ! -d $unzip_output ]; then unzip_package; fi
	
	move_shared_files
	
	# if [[ "$actions" == *"push"* ]]; then login_to_image_repo; fi
	
	IFS=',' read -r -a buildactions <<< "$actions"
    IFS=',' read -r -a appnames <<< "$services"
	
	for act in "${buildactions[@]}"
	do

	case $act in
	"build")

	for app in "${appnames[@]}"
	do

	case $app in
	"id-web")
	docker build -t gcr.io/$image_repo/bold-identity:$tag -f $base/boldbi-identity.txt $build_context_path
	;;
	"id-api")
	docker build -t gcr.io/$image_repo/bold-identity-api:$tag -f $base/boldbi-identity-api.txt $build_context_path
	;;
	"id-ums")
	docker build -t gcr.io/$image_repo/bold-ums:$tag -f $base/boldbi-ums.txt $build_context_path
	;;
	"bi-web")
	docker build -t gcr.io/$image_repo/boldbi-server:$tag -f $base/boldbi-server.txt $build_context_path
	;;
	"bi-api")
	docker build -t gcr.io/$image_repo/boldbi-server-api:$tag -f $base/boldbi-server-api.txt $build_context_path
	;;
	"bi-jobs")
	docker build -t gcr.io/$image_repo/boldbi-server-jobs:$tag -f $base/boldbi-server-jobs.txt $build_context_path
	;;
	"bi-dataservice")
	docker build -t gcr.io/$image_repo/boldbi-designer:$tag -f $base/boldbi-designer.txt $build_context_path
	;;
	esac
	
    say_success "$app image Created Successfully"
	
	done

	;;
	"push")
	
	for app in "${appnames[@]}"
	do

	case $app in
	"id-web")
	docker push gcr.io/$image_repo/bold-identity:$tag
	;;
	"id-api")
	docker push gcr.io/$image_repo/bold-identity-api:$tag
	;;
	"id-ums")
	docker push gcr.io/$image_repo/bold-ums:$tag
	;;
	"bi-web")
	docker push gcr.io/$image_repo/boldbi-server:$tag
	;;
	"bi-api")
	docker push gcr.io/$image_repo/boldbi-server-api:$tag
	;;
	"bi-jobs")
	docker push gcr.io/$image_repo/boldbi-server-jobs:$tag
	;;
	"bi-dataservice")
	docker push gcr.io/$image_repo/boldbi-designer:$tag
	;;
	esac

    say_success "$app image pushed to $image_repo registry Successfully"

	done

	;;
	"update")

    if [ -z $cluster ]; then
	    $kube_config="kubectl"
	elif [ $cluster == "aks" ]; then
	    $kube_config="kubectl --kubeconfig='D:\Confidential\cluster_config\k8s-yokogawa-test.config'"
	fi

	for app in "${appnames[@]}"
	do

	case $app in
	"id-web")
	$kube_config set image deployment/id-web-deployment id-web-container=gcr.io/$image_repo/bold-identity:$tag --namespace=$namespace --record
	;;
	"id-api")
	$kube_config set image deployment/id-api-deployment id-api-container=gcr.io/$image_repo/bold-identity-api:$tag --namespace=$namespace --record
	;;
	"id-ums")
	$kube_config set image deployment/id-ums-deployment id-ums-container=gcr.io/$image_repo/bold-ums:$tag --namespace=$namespace --record
	;;
	"bi-web")
	$kube_config set image deployment/bi-web-deployment bi-web-container=gcr.io/$image_repo/boldbi-server:$tag --namespace=$namespace --record
	;;
	"bi-api")
	$kube_config set image deployment/bi-api-deployment bi-api-container=gcr.io/$image_repo/boldbi-server-api:$tag --namespace=$namespace --record
	;;
	"bi-jobs")
	$kube_config set image deployment/bi-jobs-deployment bi-jobs-container=gcr.io/$image_repo/boldbi-server-jobs:$tag --namespace=$namespace --record
	;;
	"bi-dataservice")
	$kube_config set image deployment/bi-dataservice-deployment bi-dataservice-container=gcr.io/$image_repo/boldbi-designer:$tag --namespace=$namespace --record
	;;
	esac

	done

	;;
	esac

	done
}

build_push_update
