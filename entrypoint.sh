#!/bin/bash

APPID=1026340
steamcmd.sh +quit
steamcmd.sh +force_install_dir /data/barotrauma \
            +login anonymous \
            +app_update $APPID validate \
            +quit

mkdir -p /root/.steam/sdk64
ln -s /opt/steamcmd/linux64/steamclient.so /root/.steam/sdk64/steamclient.so

# We are generating this kube
if [ "$SETTINGS_ENVTPL" == "true" ]
then
    envtmpl /opt/configuration/serversettings.xml.tmpl > /data/barotrauma/serversettings.xml
    cp /opt/configuration/clientpermissions.xml /data/barotrauma/Data/clientpermissions.xml
fi

cd /data/barotrauma
./DedicatedServer
