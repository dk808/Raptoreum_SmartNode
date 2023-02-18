#!/bin/bash

DIR='/raptoreum/.raptoreumcore'
BOOTSTRAP_TAR='https://bootstrap.raptoreum.com/bootstraps/bootstrap.tar.xz'
POWCACHE='https://github.com/dk808/Raptoreum_SmartNode/releases/download/v1.0.0/powcache.dat'

if [ ! -d $DIR ]; then
  mkdir -p $DIR
  curl -L $BOOTSTRAP_TAR | tar xJ -C $DIR
  curl -L $POWCACHE > $DIR//powcache.dat
else
  echo "Datadir has been detected so bootstrap will not be used..."
fi
