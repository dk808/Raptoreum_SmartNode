#!/bin/bash

DIR='/raptoreum/.raptoreumcore'
BOOTSTRAP_TAR='http://185.252.234.154/boot/rtm-bootstrap.tar.gz'

if [ ! -d $DIR ]; then
  mkdir -p $DIR
  curl -L $BOOTSTRAP_TAR | tar xz -C $DIR
else
  echo "Datadir has been detected so bootstrap will not be used..."
fi
