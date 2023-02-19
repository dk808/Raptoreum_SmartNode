#!/bin/bash

DIR='/raptoreum/.raptoreumcore'
BOOTSTRAP_TAR='https://bootstrap.raptoreum.com/bootstraps/bootstrap.tar.xz'

if [ ! -d $DIR ]; then
  mkdir -p $DIR
  curl -L $BOOTSTRAP_TAR | tar xJ -C $DIR
else
  echo "Datadir has been detected so bootstrap will not be used..."
fi
