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
old_install_dir="/var/www/boldbi-embedded"
install_dir="/var/www/bold-services"
backup_folder="/var/www"
dotnet_dir="$install_dir/dotnet"
services_dir="$install_dir/services"
system_dir="/etc/systemd/system"
boldbi_product_json_location="$install_dir/application/app_data/configuration/product.json"
boldbi_config_xml_location="$install_dir/application/app_data/configuration/config.xml"
user=""
host_url=""
server=""
distribution=""
VER=""
move_idp=false
common_idp_fresh=false
common_idp_upgrade=false
services_array=("bold-id-web" "bold-id-api" "bold-ums-web" "bold-bi-web" "bold-bi-api" "bold-bi-jobs" "bold-bi-designer")
installation_type=""
run_custom_widgets_utility=false
is_bing_map_enabled=false
bing_map_api_key=""

while [ $# -ne 0 ]
do
    name="$1"
    case "$name" in
        -d|--install-dir|-[Ii]nstall[Dd]ir)
            shift
            install_dir="$1"
            ;;
			
		-i|--install|-[Ii]nstall)
            shift
            installation_type="$1"
            ;;
			
		-u|--user|-User)
            shift
            user="$1"
            ;;
			
		-h|--host|-[Hh]ost)
            shift
            host_url="$1"
            ;;
			
		-n|--nginx|-[Nn]ginx)
            shift
			if $1; then
				server="nginx"
			fi
            ;;
			
		-s|--server|-[Ss]erver)
            shift
			server="$1"	
            ;;

		-distro|--distribution|-[Dd]istro)
            shift
			distribution="$1"	
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
    printf "%b\n" "${yellow:-}boldbi_install: Warning: $1${normal:-}" >&3
}

say_err() {
    printf "%b\n" "${red:-}boldbi_install: Error: $1${normal:-}" >&2
}

say() {
    # using stream 3 (defined in the beginning) to not interfere with stdout of functions
    # which may be used as return value
    printf "%b\n" "${cyan:-}boldbi-install:${normal:-} $1" >&3
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

check_distribution() {
	eval $invocation

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		OS=$ID
		VER=$VERSION_ID
	elif type lsb_release >/dev/null 2>&1; then
		OS=$(lsb_release -si)
		VER=$(lsb_release -sr)
	elif [ -f /etc/lsb-release ]; then
		. /etc/lsb-release
		OS=$DISTRIB_ID
		VER=$DISTRIB_RELEASE
	elif [ -f /etc/debian_version ]; then
		OS="debian"
		VER=$(cat /etc/debian_version)
	elif [ -f /etc/redhat-release ]; then
		# Older Red Hat, CentOS, etc.
		OS="centos"
	else
		OS=$(uname -s)
		VER=$(uname -r)
	fi
	
	OS=$(to_lowercase $OS)
	
	if [[ $OS = "centos" || $OS = "rhel" ]]; then
		distribution="centos"
	else
		distribution="ubuntu"
	fi	
	
	say "Distribution: $distribution"
	say "Distribution Version: $VER"
}

check_min_reqs() {
    # local hasMinimum=false
    # if machine_has "curl"; then
        # hasMinimum=true
    # elif machine_has "wget"; then
        # hasMinimum=true
    # fi

    # if [ "$hasMinimum" = "false" ]; then
        # say_err "curl or wget are required to download Bold BI. Install missing prerequisite to proceed."
        # return 1
    # fi
	
	local hasZip=false
	if machine_has "zip"; then
        hasZip=true
    fi
	
	if [ "$hasZip" = "false" ]; then
        say_err "Zip is required to extract the Bold BI Linux package. Install missing prerequisite to proceed."
        return 1
    fi
	
	if [ "$server" = "nginx" ]; then
		local hasNginx=false		
		if machine_has "nginx"; then
			hasNginx=true
		fi			
		if [ "$hasNginx" = "false" ]; then
			say_err "Nginx is required to host the Bold BI application. Install missing prerequisite to proceed."
			return 1
		fi		
	    return 0
	elif [ "$server" = "apache" ]; then
		local hasApache=false
		if [ "$distribution" = "ubuntu" ]; then	
			if machine_has "apache2"; then
				hasApache=true
			fi
		else
			if machine_has "httpd"; then
				hasApache=true
			fi
		fi			
		if [ "$hasApache" = "false" ]; then
			say_err "apache is required to host the Bold BI application. Install missing prerequisite to proceed."
			return 1
		fi		
		return 0
	fi
}

# args:
# input - $1
to_lowercase() {
    #eval $invocation

    echo "$1" | tr '[:upper:]' '[:lower:]'
    return 0
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

read_user() {
	# eval $invocation

	# Read user from existing service file
	read_user="$(grep -F -m 1 'User=' $system_dir/bold-id-web.service)"
	IFS='='
	read -ra user_arr <<< "$read_user"
	user="${user_arr[1]%%[[:cntrl:]]}"
	# user="${user%%[[:cntrl:]]}"
}

read_host_url() {
	# eval $invocation

	# Read Host URL from existing product.json file
	if [ -d "$install_dir" ]; then
		read_url="$(grep -F -m 1 '<Idp>' $boldbi_config_xml_location)"
	else
		read_url="$(grep -F -m 1 '<Idp>' $old_install_dir/boldbi/app_data/configuration/config.xml)"
	fi
    IFS='>'
    read -ra url_arr1 <<< "$read_url"
    temp_url="${url_arr1[1]%%[[:cntrl:]]}"
    IFS='<'
    read -ra url_arr2 <<< "$temp_url"
    host_url="${url_arr2[0]%%[[:cntrl:]]}"
}

enable_boldbi_services() {
	eval $invocation

	for t in ${services_array[@]}; do
		if $common_idp_fresh; then
			if [ $t = "bold-id-web" ] || [ $t = "bold-id-api" ] || [ $t = "bold-ums-web" ]; then
				continue
			fi
		fi
		say "Enabling service - $t"
		systemctl enable $t
	done
}

copy_files_to_installation_folder() {
	eval $invocation
	
	cp -a application/. $install_dir/application/
	cp -a clientlibrary/. $install_dir/clientlibrary/
	cp -a dotnet/. $install_dir/dotnet/
	cp -a services/. $install_dir/services/
	cp -a Infrastructure/. $install_dir/Infrastructure/
}

start_boldbi_services() {
	eval $invocation
	
	for t in ${services_array[@]}; do
		if $common_idp_fresh; then
			if [ $t = "bold-id-web" ] || [ $t = "bold-id-api" ] || [ $t = "bold-ums-web" ]; then
				continue
			fi
		fi
		say "Starting service - $t"
		systemctl start $t

		if ! ( $common_idp_fresh || $common_idp_upgrade ); then
			if [ $t = "bold-id-web" ]; then
				say "Initializing $t"
				sleep 5
			fi
		fi
	done
}

status_boldbi_services() {
	eval $invocation

	systemctl --type=service | grep bold-id-*
	systemctl --type=service | grep bold-ums-web
	systemctl --type=service | grep bold-bi-*
}

stop_boldbi_services() {
	eval $invocation
	for t in ${services_array[@]}; do
		say "Stoping service - $t"
		systemctl stop $t
	done
}

restart_boldbi_services() {
	eval $invocation
	for t in ${services_array[@]}; do
		say "Restarting service - $t"
		systemctl restart $t

		if [ $t = "bold-id-web" ]; then
			sleep 5
		fi
	done
}

check_config_file_generated() {
	eval $invocation
	if [ ! -f "$boldbi_config_xml_location" ]; then
		say "Generating configuration files..."
		restart_boldbi_services
	fi
}

update_url_in_product_json() {
	eval $invocation
	old_url="http:\/\/localhost\/"
	new_url="$(remove_trailing_slash "$host_url")"

	idp_url="$new_url"
	say "IDP URL - $idp_url"
	
	bi_url="$new_url/bi"
	say "BI URL - $bi_url"
	
	bi_designer_url="$new_url/bi/designer"
	say "BI Designer URL - $bi_designer_url"
	
	sed -i $boldbi_product_json_location -e "s|\"Idp\":.*\",|\"Idp\":\"$idp_url\",|g" -e "s|\"Bi\":.*\",|\"Bi\":\"$bi_url\",|g" -e "s|\"BiDesigner\":.*\",|\"BiDesigner\":\"$bi_designer_url\",|g"
	
	say "Product.json file URLs updated."
}
	
copy_service_files () {
	eval $invocation
	
	cp -a "$1" "$2"
}

configure_nginx () {
	eval $invocation

	if [ "$distribution" = "centos" ]; then
		centos_nginx_dir="/etc/nginx/conf.d"
		[ ! -d "$centos_nginx_dir" ] && mkdir -p "$centos_nginx_dir"
		say "Copying Bold BI Nginx config file"
		cp boldbi-nginx-config $centos_nginx_dir/boldbi-nginx-config
		mv $centos_nginx_dir/boldbi-nginx-config $centos_nginx_dir/boldbi-nginx-config.conf

		if [ $VER == "8" ]; then
			sed -i "s|80 default_server|8080 default_server|g" "/etc/nginx/nginx.conf"
			sed -i "s|[::]:80 default_server|[::]:8080 default_server|g" "/etc/nginx/nginx.conf"
		fi

	else
		nginx_sites_available_dir="/etc/nginx/sites-available"
		nginx_sites_enabled_dir="/etc/nginx/sites-enabled"
		
		[ ! -d "$nginx_sites_available_dir" ] && mkdir -p "$nginx_sites_available_dir"
		[ ! -d "$nginx_sites_enabled_dir" ] && mkdir -p "$nginx_sites_enabled_dir"
		
		say "Copying Bold BI Nginx config file"
		cp boldbi-nginx-config $nginx_sites_available_dir/boldbi-nginx-config
		
		nginx_default_file=$nginx_sites_available_dir/default
		if [ -f "$nginx_default_file" ]; then
			say "Taking backup of default nginx file"
			mv $nginx_default_file $nginx_sites_available_dir/default_backup
			say "Removing the default Nginx file"
			rm $nginx_sites_enabled_dir/default
		fi
		
		say "Creating symbolic links from these files to the sites-enabled directory"
		ln -s $nginx_sites_available_dir/boldbi-nginx-config $nginx_sites_enabled_dir/
	fi

	if [ ! -e /var/run/nginx.pid ]; then
		systemctl start nginx
	fi
	
	validate_nginx_config
}

configure_apache () {
	eval $invocation

	apachectl_path=$(which apachectl)
	say "Starting apache server"
	$apachectl_path start

	if [ "$distribution" = "centos" ]; then
		apache_sites_available_dir="/etc/httpd/sites-available"
		apache_sites_enabled_dir="/etc/httpd/sites-enabled"
		httpd_conf_file_path="/etc/httpd/conf/httpd.conf"
		sed -i "s|Protocols h2 http/1.1|# Protocols h2 http/1.1|g" boldbi-apache-config.conf
		sed -i "s|RequestHeader set|# RequestHeader set|g" boldbi-apache-config.conf
		grep -qxF 'IncludeOptional sites-enabled/*.conf' "$httpd_conf_file_path" || echo 'IncludeOptional sites-enabled/*.conf' >> "$httpd_conf_file_path"
	else
		apache_sites_available_dir="/etc/apache2/sites-available"
		apache_sites_enabled_dir="/etc/apache2/sites-enabled"
	fi
	
	[ ! -d "$apache_sites_available_dir" ] && mkdir -p "$apache_sites_available_dir"
	[ ! -d "$apache_sites_enabled_dir" ] && mkdir -p "$apache_sites_enabled_dir"
	
	say "Copying Bold BI apache config file"
	cp boldbi-apache-config.conf $apache_sites_available_dir/boldbi-apache-config.conf
	
	if [ "$distribution" = "ubuntu" ]; then
		apache_default_file=$apache_sites_available_dir/000-default.conf
		if [ -f "$apache_default_file" ]; then
			say "Taking backup of default apache file"
			mv $apache_default_file $apache_sites_available_dir/000-default-backup.conf
			say "Removing the default apache file"
			rm $apache_sites_enabled_dir/000-default.conf
		fi
	fi

	port=""
	server_name=($(echo $host_url | cut -d'/' -f3))
	
	if [[ $host_url == *"localhost"* ]]; then
		port=($(echo $host_url | cut -d':' -f3))
		port=($(echo $port | cut -d'/' -f1))
		say "Port: $port"
		if [ "$distribution" = "ubuntu" ]; then
			echo "Listen $port"  >> /etc/apache2/ports.conf
			echo "#The above is the port included by Bold BI" >> /etc/apache2/ports.conf
		else
			echo "Listen $port"  >> /etc/httpd/conf.d/ports.conf
			echo "#The above is the port included by Bold BI" >> /etc/httpd/conf.d/ports.conf
		fi
	else
		say "ServerName: $server_name"
		sed -i "s|ServerName localhost|ServerName $server_name|g" $apache_sites_available_dir/boldbi-apache-config.conf
		#sed -i "s|Redirect / localhost|Redirect / $host_url/|g" $apache_sites_available_dir/boldbi-apache-config.conf
	fi
	
	say "Enabling required modules for apache server"
	if [ "$distribution" = "ubuntu" ]; then
		a2enmod proxy
		a2enmod proxy_http
		a2enmod proxy_wstunnel
		a2enmod rewrite
		a2enmod headers
		a2enmod ssl
	else
		grep -qxF 'LoadModule proxy_module modules/mod_proxy.so' "$httpd_conf_file_path" || echo 'LoadModule proxy_module modules/mod_proxy.so' >> "$httpd_conf_file_path"
		grep -qxF 'LoadModule proxy_http_module modules/mod_proxy_http.so' "$httpd_conf_file_path" || echo 'LoadModule proxy_http_module modules/mod_proxy_http.so' >> "$httpd_conf_file_path"
		grep -qxF 'LoadModule proxy_wstunnel_module modules/mod_proxy_wstunnel.so' "$httpd_conf_file_path" || echo 'LoadModule proxy_wstunnel_module modules/mod_proxy_wstunnel.so' >> "$httpd_conf_file_path"
		grep -qxF 'LoadModule rewrite_module modules/mod_rewrite.so' "$httpd_conf_file_path" || echo 'LoadModule rewrite_module modules/mod_rewrite.so' >> "$httpd_conf_file_path"
		grep -qxF 'LoadModule headers_module modules/mod_headers.so' "$httpd_conf_file_path" || echo 'LoadModule headers_module modules/mod_headers.so' >> "$httpd_conf_file_path"
	fi
	$apachectl_path restart
	
	say "Creating symbolic links from these files to the sites-enabled directory"	
    ln -s $apache_sites_available_dir/boldbi-apache-config.conf $apache_sites_enabled_dir/
	say "Validating the apache configuration"
	$apachectl_path configtest
	say "Restarting the apache to apply the changes"
	$apachectl_path restart
}

install_client_libraries () {
	eval $invocation
	mkdir -p $install_dir/clientlibrary/temp
	bash $install_dir/clientlibrary/install-optional.libs.sh install-optional-libs npgsql,mongodb,influxdb,snowflake,mysql,oracle
}

install_phanthomjs () {
	eval $invocation
	mkdir -p $install_dir/application/app_data/bi/dataservice
	mkdir -p $install_dir/clientlibrary/temp
	bash $install_dir/clientlibrary/install-optional.libs.sh install-optional-libs phantomjs
}

is_boldreports_already_installed() {
	systemctl list-unit-files | grep "bold-reports-*" > /dev/null 2>&1
	return $?
}

is_boldbi_already_installed() {
	systemctl list-unit-files | grep "bold-bi-*" > /dev/null 2>&1
	return $?
}

taking_backup(){
	eval $invocation
	say "Started creating backup . . ."
	timestamp="$(date +"%T")"
	backup_file_location=""

    if [ ! -d "$install_dir" ]; then
		backup_file_location=$backup_folder/boldbi-embedded_backup_$timestamp.zip
	    zip -qr $backup_file_location $old_install_dir
	else
	    backup_file_location=$backup_folder/bold_services_backup_$timestamp.zip
	    zip -qr $backup_file_location $install_dir
	fi
	
	say "Backup file name:$backup_file_location"
	say "Backup process completed . . ."
	return $?
	
}

removing_old_files(){
	eval $invocation
	rm -rf $install_dir/application/bi
	rm -rf $install_dir/application/idp
	rm -rf $install_dir/clientlibrary
	rm -rf $install_dir/dotnet
	rm -rf $install_dir/services
	rm -rf $install_dir/Infrastructure
}
	
validate_user() {
	eval $invocation
	if [[ $# -eq 0 ]]; then
		say_err "Please specify the user that manages the service."
		return 1
	fi	
	
	# if grep -q "^$1:" /etc/passwd ;then
		# return 0
	# else
		# say_err "User $1 is not valid"
		# return 1
	# fi
	
	return 0
}

validate_host_url() {
	eval $invocation
	if [[ $# -eq 0 ]]; then
		say_err "Please specify the host URL."
		return 1
	fi	
	
	url_regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
	if [[ $1 =~ $url_regex ]]; then 
		return 0
	else
		say_err "Please specify the valid host URL."
		return 1
	fi
}
	
validate_installation_type() {
	eval $invocation
	if  [[ $# -eq 0 ]]; then
		say_err "Please specify the installation type (new or upgrade)."
		return 1
	fi	

	if  [ "$(to_lowercase $1)" != "new" ] && [ "$(to_lowercase $1)" != "upgrade" ]; then
		say_err "Please specify the valid installation type."
		return 1
	fi

	return 0	
}

validate_nginx_config() {
	eval $invocation
	say "Validating the Nginx configuration"
	nginx -t
	say "Restarting the Nginx to apply the changes"
	systemctl restart nginx
}

migrate_custom_widgets() {
	# eval $invocation

	custom_widget_source="$install_dir/application/bi/dataservice/CustomWidgets"
	custom_widget_dest="$install_dir/application/app_data/bi/dataservice/"

	if [ -d "$custom_widget_source" ]; then
	    [ ! -d "$custom_widget_dest" ] && mkdir -p "$custom_widget_dest"
		cp -a "$custom_widget_source" "$custom_widget_dest"
		run_custom_widgets_utility=true
	fi
}

get_bing_map_config() {
    bi_appsettings_path="$install_dir/application/bi/dataservice/appsettings.json"
    if [ -f "$bi_appsettings_path" ]; then
		if grep -qF "widget:bing_map:enable" $bi_appsettings_path; then
			# script for getting bing map enabled value is true or false
			is_bing_map_enabled1="$(grep -F -m 1 'widget:bing_map:enable' $bi_appsettings_path)"
			IFS=' '
			read -ra bingmap_enable_arr1 <<< "$is_bing_map_enabled1"
			is_bing_map_enabled2="${bingmap_enable_arr1[1]%%[[:cntrl:]]}"
			IFS=','
			read -ra bingmap_enable_arr2 <<< "$is_bing_map_enabled2"
			is_bing_map_enabled="${bingmap_enable_arr2[0]%%[[:cntrl:]]}"
			
			# script for getting bing map api key	
			bing_map_api_key1="$(grep -F -m 1 'widget:bing_map:api_key' $bi_appsettings_path)"
			IFS=' '
			read -ra bing_map_api_key_arr1 <<< "$bing_map_api_key1"
			bing_map_api_key2="${bing_map_api_key_arr1[1]%%[[:cntrl:]]}"
			IFS=','
			read -ra bing_map_api_key_arr2 <<< "$bing_map_api_key2"
			bing_map_api_key="${bing_map_api_key_arr2[0]%%[[:cntrl:]]}"
		fi
	fi
}

bing_map_migration() {
	if ! grep -qF "<Designer>" $boldbi_config_xml_location; then
		eval $invocation

		"$install_dir/dotnet/dotnet" "$install_dir/application/utilities/installutils/installutils.dll" bing_map_config_migration $is_bing_map_enabled $bing_map_api_key
	fi
}

update_oauth_fix() {
	# eval $invocation

	nginx_path="/etc/nginx"
	nginx_conf_path=""
	nginx_conf_name=""

	if $common_idp_upgrade || $common_idp_fresh; then
		nginx_conf_name="boldreports-nginx-config"
	else
		nginx_conf_name="boldbi-nginx-config"
	fi

	if [ "$distribution" = "ubuntu" ]; then
		nginx_conf_path="$nginx_path/sites-available/$nginx_conf_name"
	elif [ "$distribution" = "centos" ]; then
		nginx_conf_path="$nginx_path/conf.d/$nginx_conf_name.conf"
	fi
	
	if ! grep -qF "large_client_header_buffers" $nginx_conf_path; then
		sed -n '/proxy_buffer_size/,/large_client_header_buffers/p' boldbi-nginx-config > "update_oauth_fix.txt"
		sed -i '/client_max_body_size/r update_oauth_fix.txt' $nginx_conf_path
		rm -rf "update_oauth_fix.txt"
	fi
}

check_boldbi_directory_structure() {
	# eval $invocation
	
	if [ "$1" = "rename_installed_directory" ]; then
		if [ ! -d "$install_dir" ]; then
			say "Changing Bold BI directory structure."
			mv "$old_install_dir" "$install_dir"
			mv "$install_dir/boldbi" "$install_dir/application"
		fi
	elif [ "$1" = "remove_services" ]; then
		if grep -qF "/boldbi-embedded/boldbi/" "$system_dir/bold-bi-web.service"; then
			say "Removing old service files."
			rm -rf $system_dir/bold-*
			systemctl daemon-reload
			find "$services_dir" -type f -name "*.service" -print0 | xargs -0 sed -i "s|www-data|$user|g"
			if [ "$distribution" = "centos" ]; then
			find "$services_dir" -type f -name "bold-*" -print0 | xargs -0 sed -i '/DOTNET_PRINT_TELEMETRY_MESSAGE/a Environment=LD_LIBRARY_PATH=/usr/local/lib'
			find "$services_dir" -type f -name "bold-*" -print0 | xargs -0 sed -i '/LD_LIBRARY_PATH/a Environment=export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1'
			fi
			copy_service_files "$services_dir/." "$system_dir"		
			enable_boldbi_services
		fi
	elif [ "$1" = "check_nginx_config" ]; then
		nginx_config_path=""

		if [ "$distribution" = "ubuntu" ]; then
			nginx_dir="/etc/nginx/sites-available"
			nginx_config_path="/etc/nginx/sites-available/boldbi-nginx-config"
		elif [ "$distribution" = "centos" ]; then
			nginx_dir="/etc/nginx/conf.d"
			nginx_config_path="/etc/nginx/conf.d/boldbi-nginx-config.conf"
		fi
		
		if [[ -d "$nginx_dir" || -f "$nginx_config_path" ]]; then
			if grep -qF "/boldbi-embedded/boldbi/" "$nginx_config_path"; then
				sed -i "s|/boldbi-embedded/boldbi/|/bold-services/application/|g" "$nginx_config_path"
			fi
			
			if ! grep -qF "[::]:80 default_server;" "$nginx_config_path"; then
				sed -i '/80 default_server/a\\t\tlisten       [::]:80 default_server;' "$nginx_config_path"
			fi
		fi
		
		update_oauth_fix
		validate_nginx_config
	fi
}

common_idp_integration() {
	eval $invocation

	Extracted_Dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
	cp -a "$Extracted_Dir/application/utilities/installutils" "$install_dir/application/utilities/"	
	say "Modifying product.json"
	"$install_dir/dotnet/dotnet" "$install_dir/application/utilities/installutils/installutils.dll" common_idp_setup $Extracted_Dir
	
	if [ -f "$Extracted_Dir/idp-Version-check.txt" ]; then
		move_idp=($(cat "$Extracted_Dir/idp-Version-check.txt"))
	fi
	
	say "Moving Bold BI files to Bold Reports installed directory."
	cp -a "$Extracted_Dir/application/bi" "$install_dir/application/"
	chown -R "$user" "$install_dir/application/bi"
	chmod +rwx "$install_dir/application/bi"
	cp -a "$Extracted_Dir/Infrastructure/License Agreement/BoldBI_License.pdf" "$install_dir/Infrastructure/License Agreement/"

	if $move_idp; then
		say "Moving Bold ID files to Bold Reports installed directory."
		rm -r $install_dir/application/idp
		rm -r $install_dir/application/utilities/adminutils
		cp -a "$Extracted_Dir/application/idp" "$install_dir/application/"
		cp -a "$Extracted_Dir/application/utilities/adminutils" "$install_dir/application/utilities/"
		chown -R "$user" "$install_dir/application/idp"
		chmod +rwx "$install_dir/application/idp"
	fi
	
	rm -r $install_dir/application/utilities/installutils
	if [ -f "$Extracted_Dir/idp-Version-check.txt" ]; then
		rm -r "$Extracted_Dir/idp-Version-check.txt"
	fi
	
	if ! $common_idp_upgrade; then
		find "services" -type f -name "*.service" -print0 | xargs -0 sed -i "s|www-data|$user|g"
		if [ "$distribution" = "centos" ]; then
		find "$services_dir" -type f -name "bold-*" -print0 | xargs -0 sed -i '/DOTNET_PRINT_TELEMETRY_MESSAGE/a Environment=LD_LIBRARY_PATH=/usr/local/lib'
		find "$services_dir" -type f -name "bold-*" -print0 | xargs -0 sed -i '/LD_LIBRARY_PATH/a Environment=export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1'
		fi
		
		say "Moving BoldBI service files"
		cp -a services/bold-bi-* "$services_dir"
		cp -a services/bold-bi-* "$system_dir"

		reports_nginx_conf_path="";
		nginx_path="/etc/nginx"

		if [ "$distribution" = "ubuntu" ]; then
			reports_nginx_conf_path="/etc/nginx/sites-available"
			reports_sites_enabled_path="/etc/nginx/sites-enabled"
		elif [ "$distribution" = "centos" ]; then
			reports_nginx_conf_path="/etc/nginx/conf.d"
		fi

		if [ "$server" = "nginx" ]; then
			if [ ! -f "$reports_nginx_conf_path/boldbi-nginx-config" ] ; then
				say "Modifying Nginx config"
					
				if [ "$distribution" = "ubuntu" ]; then
					sed -n '/# Start of bi locations/,/# End of bi locations/p' boldbi-nginx-config > "$reports_nginx_conf_path/boldbi-nginx-config"
					sed -i '$i'"$(echo 'include /etc/nginx/sites-available/boldbi-nginx-config;')" "$reports_nginx_conf_path/boldreports-nginx-config"
				elif [ "$distribution" = "centos" ]; then
					[ ! -d "$nginx_path/boldbi" ] && mkdir -p "$nginx_path/boldbi"
					sed -n '/# Start of bi locations/,/# End of bi locations/p' boldbi-nginx-config > "$nginx_path/boldbi/boldbi-nginx-config"
					sed -i '$i'"$(echo 'include /etc/nginx/boldbi/boldbi-nginx-config;')" "$reports_nginx_conf_path/boldreports-nginx-config.conf"
				fi
			fi
		fi
	fi

	update_oauth_fix
	validate_nginx_config
	
	if $common_idp_upgrade; then bing_map_migration; fi
	
	if $common_idp_fresh; then enable_boldbi_services; fi
	start_boldbi_services
	systemctl  restart bold-*
	status_boldbi_services
	
	if $common_idp_upgrade && $run_custom_widgets_utility; then
		cd "$install_dir/application/utilities/customwidgetupgrader"
		"$install_dir/dotnet/dotnet" CustomWidgetUpgrader.dll true
	fi
}

install_boldbi() {
	eval $invocation
    local download_failed=false
    local asset_name=''
    local asset_relative_path=''
	if [[ -z "$distribution" ]]; then check_distribution; fi
	
	check_min_reqs
	if [[ "$?" != "0" ]]; then
		return 1
	fi
	
	validate_installation_type $installation_type
	if [[ "$?" != "0" ]]; then
		return 1
	fi

	if [ -z "$user" ] && [ "$installation_type" = "upgrade" ]; then read_user; fi

	validate_user $user
	if [[ "$?" != "0" ]]; then
		return 1
	fi

	if [ -z "$host_url" ] && [ "$installation_type" = "upgrade" ]; then read_host_url; fi

	validate_host_url $host_url
	if [[ "$?" != "0" ]]; then
		return 1
	fi

	if is_boldreports_already_installed && is_boldbi_already_installed ; then
		####### Combination build already exists. Need to update Bold BI ######
		
		if [ "$(to_lowercase $installation_type)" = "new" ]; then
			say_err "Bold BI already present in this machine. Terminating the installation process..."
			return 1
		fi
			
		say "Bold BI already present in this machine."
		common_idp_upgrade=true
		stop_boldbi_services
		sleep 5
		check_boldbi_directory_structure "rename_installed_directory"
	
		if taking_backup; then
			migrate_custom_widgets
			get_bing_map_config
			rm -r $install_dir/application/bi
			common_idp_integration
			say "Bold BI upgraded successfully!!!"
			return 0
		else
			return 1
		fi

	elif is_boldreports_already_installed ; then
		####### Combination build setup ######
		common_idp_fresh=true
		if [ "$installation_type" = "upgrade" ]; then
			say_err "Bold BI is not present in this machine. Terminating the installation process..."
			say_err "Please do a fresh install."
			return 1
		fi
			
		while true; do
			say "Bold Reports is already installed in this machine."
			read -p "Do you wish to configure Bold BI on top of Bold Reports? [yes / no]:  " yn
			case $yn in
				[Yy]* ) common_idp_integration; break;;
				[Nn]* ) exit;;
				* ) echo "Please answer yes or no.";;
			esac
		done
		
		say "Bold BI installation completed!!!"
		return 0

	else		
		if is_boldbi_already_installed; then
			####### Bold BI Upgrade Install######
			
			if [ "$(to_lowercase $installation_type)" = "new" ]; then
				say_err "Bold BI already present in this machine. Terminating the installation process..."
				return 1
			fi
		
			say "Bold BI already present in this machine."
			
			if taking_backup; then
			
                stop_boldbi_services
			
			    sleep 5
				
				check_boldbi_directory_structure "rename_installed_directory"
				
				migrate_custom_widgets
				
                get_bing_map_config

				removing_old_files
				
				copy_files_to_installation_folder
				
				chown -R "$user" "$install_dir"
			
				chmod +rwx "$dotnet_dir/dotnet"
				
				"$install_dir/dotnet/dotnet" "$install_dir/application/utilities/installutils/installutils.dll" upgrade_version linux
				
				update_url_in_product_json
				
				check_boldbi_directory_structure "remove_services"
				
				bing_map_migration
				
				start_boldbi_services
				
				sleep 5
				
				status_boldbi_services

				check_boldbi_directory_structure "check_nginx_config"
				
				if $run_custom_widgets_utility; then
					cd "$install_dir/application/utilities/customwidgetupgrader"
					"$install_dir/dotnet/dotnet" CustomWidgetUpgrader.dll true
				fi
				
				say "Bold BI upgraded successfully!!!"
				
				return 0
			else
				return 1
			fi
		else
			####### Bold BI Fresh Install######
		
			if [ "$installation_type" = "upgrade" ]; then
				say_err "Bold BI is not present in this machine. Terminating the installation process..."
				say_err "Please do a fresh install."
				return 1
			fi
		
			mkdir -p "$install_dir"
			
			if [ ! -d "$backup_folder/.dotnet" ]; then
				mkdir -p "$backup_folder/.dotnet"
			fi
			
			chown -R "$user" "$backup_folder/.dotnet"
			chmod +rwx "$backup_folder/.dotnet"
			
			copy_files_to_installation_folder
			update_url_in_product_json
			find "$services_dir" -type f -name "*.service" -print0 | xargs -0 sed -i "s|www-data|$user|g"
			if [ "$distribution" = "centos" ]; then
				find "$services_dir" -type f -name "bold-*" -print0 | xargs -0 sed -i '/DOTNET_PRINT_TELEMETRY_MESSAGE/a Environment=LD_LIBRARY_PATH=/usr/local/lib'
				find "$services_dir" -type f -name "bold-*" -print0 | xargs -0 sed -i '/LD_LIBRARY_PATH/a Environment=export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1'
			fi
			copy_service_files "$services_dir/." "$system_dir"
			#install_client_libraries
			#install_phanthomjs
			
			chown -R "$user" "$install_dir"
		
			chmod +x "$dotnet_dir/dotnet"
			
			sleep 5
			
			enable_boldbi_services
			start_boldbi_services
			
			sleep 5
		
			check_config_file_generated			
			status_boldbi_services
			
			if [ "$server" = "nginx" ]; then
				configure_nginx
			elif [ "$server" = "apache" ]; then
				configure_apache
			fi

			say "Bold BI installation completed!!!"
			return 0
		fi
	fi
	
	#zip_path="$(mktemp "$temporary_file_template")"
    #say_verbose "Zip path: $zip_path"
	
	# Failures are normal in the non-legacy case for ultimately legacy downloads.
    # Do not output to stderr, since output to stderr is considered an error.
    #say "Downloading primary link $download_link"
	
	# The download function will set variables $http_code and $download_error_msg in case of failure.
    #http_code=""; download_error_msg=""
    #download "$download_link" "$zip_path" 2>&1 || download_failed=true
    #primary_path_http_code="$http_code"; primary_path_download_error_msg="$download_error_msg"
	
	#say "Extracting zip from $download_link"
	
	#extract_boldbi_package "$zip_path" "$install_dir" || return 1
}

install_boldbi
