#!/bin/bash

DIR='/raptoreum/.raptoreumcore'
BOOTSTRAP_TAR='https://www.dropbox.com/s/y885aysstdmro4n/rtm-bootstrap.tar.gz'

if [ ! -d $DIR ]; then
  mkdir -p $DIR
  curl -L $BOOTSTRAP_TAR | tar xz -C $DIR
else
  echo "Datadir has been detected so bootstrap will not be used..."
fi
