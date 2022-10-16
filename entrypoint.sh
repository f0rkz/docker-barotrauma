#!/bin/bash

# This path has to exist
mkdir -p /home/steam/.local/share/Daedalic\ Entertainment\ GmbH/Barotrauma/

APPID=1026340
steamcmd.sh +quit
steamcmd.sh +force_install_dir /data/barotrauma \
            +login anonymous \
            +app_update $APPID validate \
            +quit

mkdir -p /home/steam/.steam/sdk64
ln -s /home/steam/steamcmd/linux64/steamclient.so /home/steam/.steam/sdk64/steamclient.so

envtmpl /home/steam/serversettings.xml.tmpl > /data/barotrauma/serversettings.xml
cd /data/barotrauma
