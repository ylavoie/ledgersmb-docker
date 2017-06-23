#!/bin/bash

# Fix www-data uid & gid to host mounted volume owner
USER=www-data
VOLUME=/srv/ledgersmb

stat $VOLUME

_UID="$(stat -c '%u' $VOLUME)" && \
_GID="$(stat -c '%g' $VOLUME)" && \
usermod --uid "$_UID" --gid "$_GID" "$USER" && \
ls -l "$VOLUME" && \
exec gosu "$USER" "$@"