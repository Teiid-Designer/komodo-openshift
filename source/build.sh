#!/bin/bash

MS_GROUP_ID="org.jboss.teiid.modeshape"

MVN="mvn clean install -Popenshift -am -DskipTests -Dintegration.skipTests -pl "

MVN="${MVN}${MS_GROUP_ID}:teiid-modeshape-sequencer-dataservice," \
MVN="${MVN}${MS_GROUP_ID}:teiid-modeshape-sequencer-ddl," \
MVN="${MVN}${MS_GROUP_ID}:teiid-modeshape-sequencer-vdb," \
MVN="${MVN}org.komodo:komodo-rest," \
MVN="${MVN}org.komodo.openshift:build"

#MVN="${MVN}vdb-bench/vdb-bench-war" \

echo "Executing $MVN ..."

$MVN
