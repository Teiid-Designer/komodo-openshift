#!/bin/bash

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

# Mysql Datasource
DS1_DATABASE=usstates
DS1_USERNAME=admin
DS1_PASSWORD=admin
