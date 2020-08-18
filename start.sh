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
sudo /etc/init.d/dbus start
sudo /etc/init.d/avahi-daemon start

# Some logging
echo
echo 'lsmb is up and running. You should be able to access'
echo "it under: http://${MDNS_HOSTNAME}.local"

update_ssmtp.sh

cd /srv/ledgersmb
sudo cp utils/TAP/Filter/MyFilter.pm /usr/local/share/perl/`perl -e 'print substr($^V, 1)'`/TAP/Filter/

ln -s ~/node_modules node_modules

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

# Ensure english by default
export LC_ALL=en_US.UTF-8
export LC_TIME=en_DK.UTF-8

if [[ ! -v DEVELOPMENT || "$DEVELOPMENT" == "" ]]; then
  #SERVER=Starman
  #SERVER=Starlight
  #SERVER=Thrall
  SERVER=HTTP::Server::PSGI
  PSGI=bin/ledgersmb-server.psgi
  OPT="-I lib -I old/lib"
elif [[ "$DEVELOPMENT" == "1" ]]; then
  SERVER=HTTP::Server::PSGI
  PSGI=utils/devel/ledgersmb-server-development.psgi
  OPT="-I lib -I old/lib --workers 1 --env development"
else
  export PERL5OPT=-d:NYTProf
  export NYTPROF=addpid=1:trace=2:start=no:file=/tmp/nytprof.null.out
  SERVER=Starman
  PSGI=utils/devel/ledgersmb-server-development.psgi
  OPT="-I lib -I old/lib --env development"
fi

set -x

# start ledgersmb
exec plackup --port 5762 --server $SERVER $PSGI $OPT \
      --Reload lib,old,xt/lib,t,xt,/usr/local/share/perl,/usr/share/perl,/usr/share/perl5

./test2.sh
npm run build >& tee x.x

#PERL5OPT=-d:vscode PERLDB_OPTS='RemotePort=ylaho3:5002' plackup --port 5001 --server $SERVER $PSGI $OPT \
#      --Reload lib,old,xt/lib,t,xt,/usr/local/share/perl,/usr/share/perl,/usr/share/perl5
