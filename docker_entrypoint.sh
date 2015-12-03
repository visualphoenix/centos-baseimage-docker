#!/bin/bash

if [ "$1" = 'build' ] ; then
    cd /runit-rpm
    bash build.sh 1>&2
    cd /root/rpmbuild/RPMS/x86_64/
    tar czf - . | cat
    exit
fi
exec "$@"
