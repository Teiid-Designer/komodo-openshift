#!/bin/bash

set -x

source /usr/local/s2i/install-common.sh

injected_dir=$1


install_deployments ${injected_dir}/vdb-builder.war

#chmod -R ugo+rX ${injected_dir}/modules
#install_modules ${injected_dir}/modules

#configure_drivers ${injected_dir}/install.properties

#configure_translators ${injected_dir}/install.properties
