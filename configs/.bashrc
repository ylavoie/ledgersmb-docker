export COLUMNS=143
export LINES=39
export PATH=$PATH:/usr/lib/chromium-browser

source /opt/perlbrew/etc/bashrc

## Variables d'environnement requises
export PERLBREW_ROOT=/opt/perlbrew
export PERLBREW_HOME=/tmp/.perlbrew
source ${PERLBREW_ROOT}/etc/bashrc

## Utilisation de la version 5.18.4
perlbrew use 5.18.4
