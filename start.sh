#!/bin/bash

# Avahi
# Fallback to *lsmb* if nothing is specified
if [ -z "${MDNS_HOSTNAME}" ]; then
    export MDNS_HOSTNAME='lsmb'
fi

# Setup the hostname on the avahi config
# (We use the HOSTNAME environment variable for this)
sudo sed "s/\(host-name=\).*/\1${MDNS_HOSTNAME}/g" \
    -i /etc/avahi/avahi-daemon.conf

# Required services for mDNS to work on debian
sudo /etc/init.d/dbus restart
sudo /etc/init.d/avahi-daemon restart

# Some logging
echo
echo 'lsmb is up and running. You should be able to access'
echo "it under: http://${MDNS_HOSTNAME}.local"

update_ssmtp.sh
ln -s /var/www/node_modules /srv/ledgersmb/UI/node_modules

cd /srv/ledgersmb

#TODO: Why?
ln -s umd/react.development.js UI/node_modules/react/react.js
ln -s umd/react-dom.development.js UI/node_modules/react-dom/react-dom.js

if [[ ! -f ledgersmb.conf ]]; then
  cp conf/ledgersmb.conf.default ledgersmb.conf
  sed -i \
    -e "s/\(cache_templates = \).*\$/cache_templates = 1/g" \
    -e "s/\(host = \).*\$/\1$POSTGRES_HOST/g" \
    -e "s/\(port = \).*\$/\1$POSTGRES_PORT/g" \
    -e "s/\(default_db = \).*\$/\1$DEFAULT_DB/g" \
    -e "s%\(sendmail   = \).*%\1/usr/sbin/ssmtp%g" \
    /srv/ledgersmb/ledgersmb.conf
fi

# Currently unmaintained/untested
# if [ ! -z ${CREATE_DATABASE+x} ]; then
#   perl tools/dbsetup.pl --company $CREATE_DATABASE \
#   --host $POSTGRES_HOST \
#   --postgres_password "$POSTGRES_PASS"
#fi

# Patch Docker ndots:0 sickness
sudo chmod 666 /etc/resolv.conf
echo "options ndots:1" >>/etc/resolv.conf
sudo chmod 644 /etc/resolv.conf

export QT_QPA_PLATFORM=phantom
export PATH=$PATH:/usr/lib/chromium-browser

if [[ ! -v DEVELOPMENT || "$DEVELOPMENT" != "1" ]]; then
  #SERVER=Starman
  SERVER=HTTP::Server::PSGI
  PSGI=bin/ledgersmb-server.psgi
else
  SERVER=HTTP::Server::PSGI
  PSGI=utils/devel/ledgersmb-server-development.psgi
  OPT="--workers 1 --env development"
fi

set -x
# start ledgersmb
exec plackup --port 5001 --server $SERVER $PSGI $OPT \
      --Reload "lib, old/lib, xt/lib, t, xt, /usr/local/share/perl, /usr/share/perl, /usr/share/perl5"
