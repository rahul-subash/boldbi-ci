#!/bin/bash

echo "Checking whether product.json exists in app_data folder."
if [ ! -f /application/app_data/configuration/product.json ]; then

export IDPURL=$APP_URL
jq --arg IDPURL "$IDPURL" '.InternalAppUrl.Idp=$IDPURL' product.json > out1.json

export BIURL=$APP_URL"/bi"
jq --arg BIURL "$BIURL" '.InternalAppUrl.Bi=$BIURL' out1.json > out2.json

export DESIGNERURL=$APP_URL"/bi/designer"
jq --arg DESIGNERURL "$DESIGNERURL" '.InternalAppUrl.BiDesigner=$DESIGNERURL' out2.json > out3.json

mkdir -p /application/app_data/configuration/ && cp -rf out3.json /application/app_data/configuration/product.json
rm out1.json out2.json out3.json

echo "Updated product.json with APP_URL and moved to app_data folder."
fi

cd /application/idp/web/
nohup dotnet Syncfusion.Server.IdentityProvider.Core.dll --urls=http://localhost:6500 &>/dev/null &
echo "Started IDP web application."

sleep 15s

cd /application/idp/api/
nohup dotnet Syncfusion.Server.IdentityProvider.API.Core.dll --urls=http://localhost:6501 &>/dev/null &
echo "Started IDP API application."

cd /application/idp/ums/
nohup dotnet Syncfusion.TenantManagement.Core.dll --urls=http://localhost:6502 &>/dev/null &
echo "Started UMS application."

cd /application/bi/web/
nohup dotnet Syncfusion.Server.Dashboards.dll --urls=http://localhost:6504 &>/dev/null &
echo "Started BI web application."

cd /application/bi/api/
nohup dotnet Syncfusion.Server.API.dll --urls=http://localhost:6505 &>/dev/null &
echo "Started BI API application."

cd /application/bi/jobs/
nohup dotnet Syncfusion.Server.Jobs.dll --urls=http://localhost:6506 &>/dev/null &
echo "Started BI jobs application."

cd /application/bi/dataservice/
nohup dotnet Syncfusion.Dashboard.Designer.Web.Service.dll --urls=http://localhost:6507 &>/dev/null &
echo "Started BI designer application."


echo "Configuring nginx web server."
cd /application

if [ "$OS_ENV" != "alpine" ]; then
	nginx_sites_available_dir="/etc/nginx/sites-available" 
	nginx_sites_enabled_dir="/etc/nginx/sites-enabled"

	if [ ! -f $nginx_sites_available_dir/boldbi-nginx-config ]; then

	[ ! -d "$nginx_sites_available_dir" ] && mkdir -p "$nginx_sites_available_dir"
	[ ! -d "$nginx_sites_enabled_dir" ] && mkdir -p "$nginx_sites_enabled_dir"

	cp boldbi-nginx-config $nginx_sites_available_dir/boldbi-nginx-config

	fi

	ln -s $nginx_sites_available_dir/boldbi-nginx-config $nginx_sites_enabled_dir/
	rm $nginx_sites_enabled_dir/default
else
	echo "include /etc/nginx/sites-available/boldbi-nginx-config;" > /etc/nginx/http.d/default.conf
	nginx_sites_available_dir="/etc/nginx/sites-available"

	if [ ! -f $nginx_sites_available_dir/boldbi-nginx-config ]; then

	[ ! -d "$nginx_sites_available_dir" ] && mkdir -p "$nginx_sites_available_dir"

	cp boldbi-nginx-config $nginx_sites_available_dir/boldbi-nginx-config

	fi
fi

nginx -c /etc/nginx/nginx.conf
echo "Started nginx web server."

bash /application/clientlibrary/install-optional.libs.sh $OPTIONAL_LIBS

while sleep 60; do
  ps aux |grep Syncfusion.Server.IdentityProvider.Core.dll |grep -q -v grep
  PROCESS_1_STATUS=$?
  
  ps aux |grep Syncfusion.Server.IdentityProvider.API.Core.dll |grep -q -v grep
  PROCESS_2_STATUS=$?
  
  ps aux |grep Syncfusion.TenantManagement.Core.dll |grep -q -v grep
  PROCESS_3_STATUS=$?
  
  ps aux |grep Syncfusion.Server.Dashboards.dll |grep -q -v grep
  PROCESS_4_STATUS=$?
  
  ps aux |grep Syncfusion.Server.API.dll |grep -q -v grep
  PROCESS_5_STATUS=$?
  
  ps aux |grep Syncfusion.Server.Jobs.dll |grep -q -v grep
  PROCESS_6_STATUS=$?
  
  ps aux |grep Syncfusion.Dashboard.Designer.Web.Service.dll |grep -q -v grep
  PROCESS_7_STATUS=$?
  
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 -o $PROCESS_3_STATUS -ne 0 -o $PROCESS_4_STATUS -ne 0	-o $PROCESS_5_STATUS -ne 0 -o $PROCESS_6_STATUS -ne 0 -o $PROCESS_7_STATUS -ne 0 ]; then
    echo "One of the application has exited."
    exit 1
  fi
done