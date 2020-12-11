#!/bin/bash

IOCHEMBD_URL=$(jetpack config IOCHEMBD_URL)

CMD=$(sudo docker ps  -a | grep iochem-bd-docker) | exit 0
if [[ -z ${CMD} ]]; then
   sudo /usr/bin/docker run --restart=always -d --ulimit nofile=20000:65535 --name iochem-bd-with-data --add-host ${IOCHEMBD_URL}:127.0.0.1 -p 8443:8443 --hostname test.iochem-bd.org iochembd/iochem-bd-docker:latest-with-data
fi 


