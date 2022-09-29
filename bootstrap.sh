#!/bin/bash

DIR='/raptoreum/.raptoreumcore'
BOOTSTRAP_TAR='https://bootstrap.raptoreum.com/bootstraps_for_v1.3.17.00/bootstrap.tar.xz'

if [ ! -d $DIR ]; then
  mkdir -p $DIR
  curl -L $BOOTSTRAP_TAR | tar xJ -C $DIR
else
  echo "Datadir has been detected so bootstrap will not be used..."
fi
