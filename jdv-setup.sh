#!/bin/bash

###
#
# Installs and configures a jdv instance complete with dsb deployments
#
# Based on scripts from:
#
# * https://github.com/michaelepley/openshift-demo-jdv
# * https://github.com/cvanball/jdv-ose-demo
#
###

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

if [ ! -f 'config.sh' ]; then
    echo "No config file found .. exiting"
    exit 1
fi

#
# Source the configuration
#
. ./config.sh

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

#
# Check that we have a server keystore for https
#
if [ ! -f ${JDV_SERVER_KEYSTORE_DIR}/${JDV_SERVER_KEYSTORE_DEFAULT} ]; then
    echo -e '\n\n === HTTPS keystore has not been generated. ==='
    echo -e '\tNavigate to security/intermediate/ca.'
    echo -e '\tExecute ./create-certificate.sh -d <domain>'
    echo -e '\t\twhere domain is the name of the https route.'
    echo -e '\t\t\tThis is in the format "secure-dsb-openshift-dsb.rhel-cdk.x.x.x.x.xip.io"'
    echo -e '\t\t\twhere x.x.x.x is the ip address of the openshift instance, eg. 10.1.1.2'
    exit 1
fi

echo -e '\n\n=== Logging into oc tool as admin ==='
oc login https://${OS_HOST}:8443 -u admin -p admin
oc whoami 2>&1 > /dev/null || { echo "Cannot log in ... exiting" && exit 1; }

echo -e '\n\n=== Switching to the openshift project ==='
oc project openshift

echo -e '\n\n=== Creating the image stream for the OpenShift datavirt image ==='
oc get is ${DATAVIRT_IMG} || \
	oc import-image ${DATAVIRT_IMG} --from=${DATAVIRT_REG_IMG} --all --confirm || \
	{ echo "FAILED: Could not create datavirt 6.3 image stream" && exit 1; }
{ oc get is ${DATAVIRT_IMG} && \
	oc tag --source=istag ${DATAVIRT_IMG}:latest ${DATAVIRT_IMG}:1.1 ; } || \
	{ echo "FAILED: Could not tag the image to the correct version" && exit 1; }

echo -e '\n\n=== Creating the s2i quickstart template. This will live in the openshift namespace and be available to all projects ==='
oc get template ${OS_TEMPLATE} 2>&1 > /dev/null || \
	oc create -f ${OS_TEMPLATE}.json || \
	{ echo "FAILED: Could not create JDV application template" && exit 1; }

echo -e '\n\n=== logging into oc tool as openshift-dev ==='
oc login -u openshift-dev -p devel

echo "Switch to the new project, creating it if necessary"
{ oc get project ${OPENSHIFT_PROJECT} 2>&1 >/dev/null && \
	oc project ${OPENSHIFT_PROJECT}; } || \
	oc new-project ${OPENSHIFT_PROJECT} || \
	{ echo "FAILED: Could not use indicated project ${OPENSHIFT_PROJECT}" && exit 1; }

echo -e '\n\n=== Creating a service account and accompanying secret for use by the dsb application ==='
oc get serviceaccounts ${OPENSHIFT_SERVICE_ACCOUNT} 2>&1 > /dev/null || \
	echo '{"kind": "ServiceAccount", "apiVersion": "v1", "metadata": {"name": "'${OPENSHIFT_SERVICE_ACCOUNT}'"}}' | oc create -f - || \
	{ echo "FAILED: could not create dsb service account" && exit 1; }

echo -e '\n\n=== Creating secrets for the JDV server ==='
oc get secret ${OPENSHIFT_APP_SECRET} 2>&1 > /dev/null || \
	oc secrets new ${OPENSHIFT_APP_SECRET} ${JDV_SERVER_KEYSTORE_DIR}/${JDV_SERVER_KEYSTORE_DEFAULT} ${JDV_SERVER_KEYSTORE_DIR}/${JDV_SERVER_KEYSTORE_JGROUPS}

oc get sa/${OPENSHIFT_SERVICE_ACCOUNT} -o json | grep ${OPENSHIFT_APP_SECRET} 2>&1 > /dev/null || \
	oc secrets link ${OPENSHIFT_SERVICE_ACCOUNT} ${OPENSHIFT_APP_SECRET} || \
	{ echo "FAILED: could not link secret to service account" && exit 1; }

echo -e '\n\n=== Adding datasource properties ==='
oc get secret "${OPENSHIFT_APPLICATION_NAME}-config" 2>&1 > /dev/null || \
    oc secrets new "${OPENSHIFT_APPLICATION_NAME}-config" datasources.properties  || { echo "FAILED" && exit 1; }

echo -e '\n\n=== Deploying JDV quickstart template with default values ==='
oc get dc/${OPENSHIFT_APPLICATION_NAME} 2>&1 >/dev/null || \
	oc new-app ${OS_TEMPLATE} \
		--param=APPLICATION_NAME=${OPENSHIFT_APPLICATION_NAME} \
		--param=CONFIGURATION_NAME="${OPENSHIFT_APPLICATION_NAME}-config" \
		--param=SOURCE_REPOSITORY_URL=${SOURCE_REPOSITORY_URL} \
		--param=SOURCE_REPOSITORY_REF=${SOURCE_REPOSITORY_REF} \
		--param=SERVICE_ACCOUNT_NAME=${OPENSHIFT_SERVICE_ACCOUNT} \
		--param=HTTPS_SECRET=${OPENSHIFT_APP_SECRET} \
		--param=HTTPS_KEYSTORE=${JDV_SERVER_KEYSTORE_DEFAULT} \
		--param=HTTPS_NAME=${JDV_SERVER_KEYSTORE_DEFAULT_ALIAS} \
		--param=HTTPS_PASSWORD=${JDV_SERVER_KEYSTORE_DEFAULT_PASSWORD} \
		--param=TEIID_USERNAME=${TEIID_USERNAME} \
		--param=TEIID_PASSWORD=${TEIID_PASSWORD} \
		--param=JGROUPS_ENCRYPT_SECRET=${OPENSHIFT_APP_SECRET} \
		--param=JGROUPS_ENCRYPT_KEYSTORE=${JDV_SERVER_KEYSTORE_JGROUPS} \
		--param=JGROUPS_ENCRYPT_NAME=${JDV_SERVER_KEYSTORE_JGROUPS_ALIAS} \
		--param=JGROUPS_ENCRYPT_PASSWORD=${JDV_SERVER_KEYSTORE_JGROUPS_PASSWORD} \
        --param=CONTEXT_DIR=source \
		-l app=${OPENSHIFT_APPLICATION_NAME}

echo -e '\n\n=== verify the service is active'
#curl -sS -k -u '${TEIID_USERNAME}:${TEIID_PASSWORD}'" http://${OPENSHIFT_APPLICATION_NAME}-${OPENSHIFT_PROJECT}"'/odata4/country-ws/country/Countries?$format=json' | jq -c -e -M --tab '.' | grep Zimbabwe || { echo "WARNING: failed to validate the service is available" ; }

echo "==============================================="
echo -e '\n\n=== Example data service access'
echo -e '\n\n=== 	The following urls will allow you to access the vdbs (of which there are two) via OData2 and OData4:'
echo -e '\n\n=== 	by default, JDV secures odata sources with the standard teiid-security security domain.'
echo -e '\n\n=== 	if prompted for username/password: username = teiidUser password = redhat1!'
# reminder: for curl, use curl -u teiidUser:redhat1!
echo "==============================================="
echo "	--> Metadata for Country web service"
echo "		--> (odata 2) http://dsb-app-${OPENSHIFT_PROJECT}.${OPENSHIFT_PRIMARY_APPS}"'/odata/country-ws/$metadata'
echo "		--> (odata 4) http://dsb-app-${OPENSHIFT_PROJECT}.${OPENSHIFT_PRIMARY_APPS}"'/odata4/country-ws/country/$metadata'
echo "==============================================="

echo "Done."
