#!/bin/bash

MSSEQPATH="teiid-modeshape/sequencers"

MVN="mvn clean install -am -DskipTests -Dintegration.skipTests -pl "

MVN="${MVN}${MSSEQPATH}/teiid-modeshape-sequencer-dataservice," \
MVN="${MVN}${MSSEQPATH}/teiid-modeshape-sequencer-ddl," \
MVN="${MVN}${MSSEQPATH}/teiid-modeshape-sequencer-vdb," \
MVN="${MVN}komodo/server/komodo-rest," \
MVN="${MVN}vdb-bench/vdb-bench-war"

echo "Executing $MVN ..."

$MVN
