#!/bin/bash	
# Configuration

OPENSHIFT_PROJECT=dsb
OPENSHIFT_APPLICATION_NAME=dsb-openshift

#################
#
# Show help and exit
#
#################
function show_help {
	echo "Usage: $0 -h"
	echo "-h - ip|hostname of Openshift host"
  exit 1
}

#
# Determine the command line options
#
while getopts "h:" opt;
do
	case $opt in
	h) OS_HOST=$OPTARG ;;
	*) show_help ;;
	esac
done

if [ -z "$OS_HOST" ]; then
  echo "No Openshift host specified. Use -h <host|ip>"
  exit 1
fi

echo -e '\n\n=== Logging into oc tool as admin ==='
oc login https://$OS_HOST:8443 -u openshift-dev -p devel
oc whoami 2>&1 > /dev/null || { echo "Cannot log in ... exiting" && exit 1; }

echo "	--> delete all openshift resources"
oc delete template datavirt63-secure-s2i || { echo "WARNING: Could not delete old application template" ; }
oc delete is jboss-datagrid65-client-openshift  || { echo "WARNING: Could not delete old image" ; }
oc delete is jboss-datavirt63-openshift || { echo "WARNING: Could not delete old image" ; }
oc delete sa datavirt-service-account || { echo "WARNING: Could not delete old service account" ; }
oc delete secret datavirt-app-secret || { echo "WARNING: Could not delete old secrets" ; }
oc delete secret datavirt-app-config || { echo "WARNING: Could not delete old secrets" ; }
oc delete all -l app=${OPENSHIFT_APPLICATION_NAME}  || { echo "WARNING: Could not delete old application resources" ; }

echo "	--> delete project"
oc delete project ${OPENSHIFT_PROJECT}
oc whoami ||  echo `oc whoami` "still logged in; use 'oc logout' to logout of openshift"
echo "Done"
