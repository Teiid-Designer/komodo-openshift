#!/bin/bash

BRANCH="dv-6.4.x"
MODULES=(teiid-modeshape komodo vdb-bench)

git submodule update --init
git submodule foreach \
  git submodule update --init;

ROOT=${PWD}
for var in "${MODULES[@]}"
do
  echo "${var}"
  cd ${ROOT}/${var}
  
  if [ `git branch --list ${BRANCH}` ]; then
    git checkout ${BRANCH}
  else
    git checkout -b ${BRANCH} origin/${BRANCH}
  fi

  cd ${ROOT}
done


