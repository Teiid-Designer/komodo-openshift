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

# OS settings
DATAVIRT_REG_IMG='registry.access.redhat.com/jboss-datavirt-6/datavirt63-openshift'
DATAVIRT_IMG='jboss-datavirt63-openshift'
OS_TEMPLATE='dsb-datavirt63-secure-s2i'

OPENSHIFT_PROJECT=dsb
OPENSHIFT_APPLICATION_NAME=dsb-openshift
OPENSHIFT_SERVICE_ACCOUNT=dsb-service-account
OPENSHIFT_APP_SECRET=dsb-app-secret

# source repository
SOURCE_REPOSITORY_URL=https://github.com/Teiid-Designer/komodo-openshift
SOURCE_REPOSITORY_REF=eap-6.4.x

# https keystore
JDV_SERVER_KEYSTORE_DIR=security
JDV_SERVER_KEYSTORE_DEFAULT=server.keystore
JDV_SERVER_KEYSTORE_DEFAULT_ALIAS=jboss
JDV_SERVER_KEYSTORE_DEFAULT_PASSWORD=raleigh

# jgroups cluster keystore
JDV_SERVER_KEYSTORE_JGROUPS=jgroups.jceks
JDV_SERVER_KEYSTORE_JGROUPS_ALIAS=secret-key
JDV_SERVER_KEYSTORE_JGROUPS_PASSWORD=password

# Teiid credentials
TEIID_USERNAME=user
TEIID_PASSWORD=user1234!

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
oc login https://$OS_HOST:8443 -u admin -p admin
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

#echo -e '\n\n=== Retrieving datasource properties (market data flat file and country list web service hosted on public internet) ==='
#{ [ -f datasources.properties ] || curl https://raw.githubusercontent.com/cvanball/jdv-ose-demo/master/extensions/datasources.properties -o datasources.properties ; } && { oc #secrets new dsb-app-config datasources.properties  || { echo "FAILED" && exit 1; } ; }

echo -e '\n\n=== Deploying JDV quickstart template with default values ==='
oc get dc/dsb-app 2>&1 >/dev/null || \
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
		--param=JGROUPS_ENCRYPT_KEYSTORE=${JDV_SERVER_KEYSTORE_JGROUPS_ALIAS} \
		--param=JGROUPS_ENCRYPT_PASSWORD=${JDV_SERVER_KEYSTORE_JGROUPS_PASSWORD} \
        --param=CONTEXT_DIR=upload \
		-l app=${OPENSHIFT_APPLICATION_NAME}

#[ `oc get dc/dsb-app --template='{{(index .spec.template.spec.containers 0).resources.limits.memory}}{{printf "\n"}}'` == "1Gi" ] || \
#	oc patch dc/dsb-app -p '{"spec" : { "template" : { "spec" : { "containers" : [ { "name" : "dsb-app", "resources" : { "limits" : { "cpu" : "1000m" , "memory" : "1024Mi" }, "requests" : { "cpu" : "500m"  , "memory" : "1024Mi" } } } ] } } } }' || \
#	{ echo "FAILED: Could not set application resource limits" && exit 1; }

echo -e '\n\n=== verify the service is active'
#curl -sS -k -u '${TEIID_USERNAME}:${TEIID_PASSWORD}'" http://dsb-app-${OPENSHIFT_PROJECT}"'/odata4/country-ws/country/Countries?$format=json' | jq -c -e -M --tab '.' | grep Zimbabwe || { echo "WARNING: failed to validate the service is available" ; }

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
