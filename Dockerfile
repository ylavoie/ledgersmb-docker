FROM        ubuntu:trusty
MAINTAINER  Freelock john@freelock.com

# Install Perl, Tex, Starman, psql client, and all dependencies
#
# Without libclass-c3-xs-perl, everything grinds to a halt;
# add it, because it's a 'recommends' it the dep tree, which
# we're skipping, normally

# 'master' and common dependency install:

RUN echo "APT::Install-Recommends \"false\";\nAPT::Install-Suggests \"false\";" > /etc/apt/apt.conf.d/00recommends && \
    echo 'options ndots:2' >>/etc/resolv.conf && \
    echo 'Acquire::http { Proxy "http://nameserver:3142"; };' >> /etc/apt/apt.conf.d/02proxy && \
  DEBIAN_FRONTEND="noninteractive" apt-mark hold sensible-utils && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y update && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y upgrade && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y install \
    curl ca-certificates gnupg2

# We need our repository for Trusty libpgobject*
RUN apt-get update && \
    apt-get -y install software-properties-common wget && \
    add-apt-repository ppa:ledgersmb/main

RUN \
  DEBIAN_FRONTEND="noninteractive" apt-get update && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y install \
    libcgi-emulate-psgi-perl libconfig-inifiles-perl \
    libdbd-pg-perl libdbi-perl libdata-uuid-perl libdatetime-perl \
    libdatetime-format-strptime-perl libio-stringy-perl \
    libjson-xs-perl libcpanel-json-xs-perl liblist-moreutils-perl \
    liblocale-maketext-perl liblocale-maketext-lexicon-perl \
    liblog-log4perl-perl libmime-lite-perl libmime-types-perl \
    libmath-bigint-gmp-perl libmodule-runtime-perl libmoose-perl \
    libmoosex-nonmoose-perl libnumber-format-perl \
    libpgobject-perl libpgobject-simple-perl libpgobject-simple-role-perl \
    libpgobject-type-bytestring-perl libpgobject-util-dbmethod-perl \
    libpgobject-util-dbadmin-perl libplack-perl \
    libplack-middleware-reverseproxy-perl \
    libtemplate-perl libtext-csv-perl libtext-csv-xs-perl \
    libtext-markdown-perl libxml-simple-perl \
    libnamespace-autoclean-perl \
    libimage-size-perl \
    libtemplate-plugin-latex-perl libtex-encode-perl \
    libclass-c3-xs-perl \
    texlive-latex-recommended \
    texlive-xetex fonts-liberation \
    starman \
    libopenoffice-oodoc-perl \
    ssmtp \
    lsb-release \
    postgresql-client libpq-dev \
    libfile-mimeinfo-perl \
    libjson-maybexs-perl \
    libwww-perl \
    git cpanminus make gcc libperl-dev libcarp-always-perl \
    gettext procps libtap-parser-sourcehandler-pgtap-perl \
    libtest-dependencies-perl libtest-exception-perl libtest-trap-perl \
    libperl-critic-perl libmodule-cpanfile-perl libfile-util-perl \
    libclass-trigger-perl libclass-accessor-lite-perl libtest-requires-perl \
    libmodule-install-perl \
    python-pip python-urllib3 python-six
#   libpgobject-type-bigfloat-perl libpgobject-type-datetime-perl uglify
#    libxml-twig-perl \
#    libtry-tiny-perl libx12-parser-perl \
#    libhtml-parser-perl \
#    libspreadsheet-writeexcel-perl \
#    libole-storage-lite-perl libparse-recdescent-perl \
RUN pip install transifex-client || :
RUN wget --quiet -O - https://deb.nodesource.com/setup_10.x | bash -

# Local development tools
RUN apt-get update && \
  apt-get install -qyy mc gettext sudo bzip2 bash-completion less meld xauth \
                   lynx dnsutils net-tools xz-utils nodejs \
  && DEBIAN_FRONTEND="noninteractive" apt-get -y autoremove \
  && DEBIAN_FRONTEND="noninteractive" apt-get -y autoclean \
  && rm -rf /var/lib/apt/lists/*
#RUN update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100

# Add Tini
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

# Build time variables
ENV LSMB_VERSION master
ENV NODE_PATH /usr/local/lib/node_modules

# Install LedgerSMB
WORKDIR /srv
RUN git clone --recursive -b $LSMB_VERSION https://github.com/ledgersmb/LedgerSMB.git ledgersmb

WORKDIR /srv/ledgersmb

# Build dojo
RUN make dojo

# Configure outgoing mail to use host, other run time variable defaults

## sSMTP
ENV SSMTP_ROOT ylavoie@ylavoie.com
ENV SSMTP_MAILHUB 192.168.30.253:143
ENV SSMTP_HOSTNAME 172.17.0.1
#ENV SSMTP_USE_STARTTLS
#ENV SSMTP_AUTH_USER
#ENV SSMTP_AUTH_PASS
ENV SSMTP_FROMLINE_OVERRIDE YES
#ENV SSMTP_AUTH_METHOD

ENV POSTGRES_HOST postgres
ENV POSTGRES_PORT 5432
ENV DEFAULT_DB lsmb

# Make sure www-data share the uid/gid of the container owner on the host
#RUN groupmod --gid $HOST_GID www-data
#RUN usermod --uid $HOST_UID --gid $HOST_GID --shell /bin/bash www-data
RUN groupmod --gid 1000 www-data
RUN usermod --uid 1000 --gid 1000 --shell /bin/bash www-data

RUN \
  DEBIAN_FRONTEND=noninteractive apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
    libexpat-dev

WORKDIR /srv/ledgersmb

COPY configs/cpanfile /srv/ledgersmb/cpanfile
COPY patch/cpanm /usr/bin/cpanm
# master requirements
RUN cpanm --quiet --notest \
  --with-feature=starman \
  --with-feature=latex-pdf-ps \
  --with-feature=openoffice \
  --with-feature=latex-pdf-images \
  --with-feature=latex-pdf-ps \
  --with-feature=edi \
  --with-feature=xls \
  --with-feature=debug \
  --with-develop \
  --installdeps .

# Fix Module::Runtime of old distros
RUN cpanm --force Data::Printer Data::Dumper Smart::Comments \
    Devel::hdb \
    Devel::NYTProf \
    Plack::Middleware::Debug::Ajax \
    Plack::Middleware::Debug::DBIProfile \
    Plack::Middleware::Debug::DBITrace \
    Plack::Middleware::Debug::LazyLoadModules \
    Plack::Middleware::Debug::Log4perl \
    Plack::Middleware::Debug::Profiler::NYTProf \
    Plack::Middleware::Debug::TraceENV \
    Plack::Middleware::Debug::W3CValidate \
    Plack::Middleware::InteractiveDebugger \
    WebService::Validator::HTML::W3C

# Make sure that Moose doesn't stay around 2.1202 or you'll get
# `Invalid version format (version required) at ... /5.18.1/Module/Runtime.pm line 386.`
RUN cpanm Moose

# Work around an aufs bug related to directory permissions:
RUN mkdir -p /tmp && \
  chmod 1777 /tmp

# Internal Port Expose
EXPOSE 5001

RUN cpanm --quiet --notest --force \
    HTTP::Exception Module::Versions \
    MooseX::Constructor::AllErrors TryCatch \
    Text::PO::Parser Class::Std::Utils IO::File Devel::hdb Devel::Trepan \
    Test::Pod Test::Pod::Coverage && \
    rm -r ~/.cpanm

# Force upgrade to 2.0002 or better
RUN cpanm --quiet --notest --force PGObject::Simple::Role

RUN mkdir -p /var/www && chown www-data:www-data /var/www

# Add sudo capability
RUN echo "www-data ALL=NOPASSWD: ALL" >>/etc/sudoers

# install necessary stuff; avahi, and ssh such that we can log in and control avahi
RUN apt-get update -y \
  && DEBIAN_FRONTEND="noninteractive" \
     apt-get -qq install -y avahi-daemon avahi-discover avahi-utils libnss-mdns \
                            iputils-ping dnsutils tclsh expect \
                            tcpdump psmisc phantomjs wget unzip \
                            chromium-browser chromium-chromedriver \
  && apt-get -qq -y autoclean \
  && apt-get -qq -y autoremove \
  && apt-get -qq -y clean

#===========
# PhantomJS
#===========
ARG PHANTOM_JS=phantomjs-2.1.1-linux-x86_64
RUN apt-get update -qqy \
  && apt-get -qqy --no-install-recommends install \
            build-essential chrpath libssl-dev libxft-dev \
            libfreetype6 libfreetype6-dev \
            libfontconfig1 libfontconfig1-dev \
  && cd /var/www \
  && wget --no-verbose https://github.com/Medium/phantomjs/releases/download/v2.1.1/$PHANTOM_JS.tar.bz2 \
  && tar xjf $PHANTOM_JS.tar.bz2 \
  && mv $PHANTOM_JS /usr/local/share \
  && rm /usr/bin/phantomjs \
  && ln -sf /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/bin \
  && rm /var/www/$PHANTOM_JS.tar.bz2

# Chromedriver
RUN wget --no-verbose https://chromedriver.storage.googleapis.com/2.38/chromedriver_linux64.zip \
 && unzip chromedriver_linux64.zip \
 && sudo chmod +x chromedriver \
 && sudo mv chromedriver /usr/bin/ \
 && rm chromedriver_linux64.zip

# GeckoDriver
ARG GECKODRIVER_VERSION=0.20.0
RUN wget --no-verbose -O /tmp/geckodriver.tar.gz https://github.com/mozilla/geckodriver/releases/download/v$GECKODRIVER_VERSION/geckodriver-v$GECKODRIVER_VERSION-linux64.tar.gz \
  && rm -rf /opt/geckodriver \
  && tar -C /opt -zxf /tmp/geckodriver.tar.gz \
  && rm /tmp/geckodriver.tar.gz \
  && mv /opt/geckodriver /opt/geckodriver-$GECKODRIVER_VERSION \
  && chmod 755 /opt/geckodriver-$GECKODRIVER_VERSION \
  && ln -fs /opt/geckodriver-$GECKODRIVER_VERSION /usr/bin/geckodriver

# Firefox
RUN apt-get update -qqy \
  && apt-get -qqy --no-install-recommends install firefox \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
  && apt-get -y purge firefox \
  && rm -rf /opt/firefox

# Releases versions
# ARG FIREFOX_VERSION=59.0.2
# ENV FF_PATH https://download-installer.cdn.mozilla.net/pub/firefox/releases/$FIREFOX_VERSION/linux-x86_64/en-US/firefox-$FIREFOX_VERSION.tar.bz2
# Candidates versions
ARG FIREFOX_VERSION=60.0b10
ENV FF_PATH=https://download-installer.cdn.mozilla.net/pub/firefox/candidates/$FIREFOX_VERSION-candidates/build1/linux-x86_64/en-US/firefox-$FIREFOX_VERSION.tar.bz2
#
RUN wget --no-verbose -O /tmp/firefox.tar.bz2 $FF_PATH
RUN tar -C /opt -xjf /tmp/firefox.tar.bz2 \
  && rm /tmp/firefox.tar.bz2 \
  && mv /opt/firefox /opt/firefox-$FIREFOX_VERSION \
  && ln -fs /opt/firefox-$FIREFOX_VERSION/firefox /usr/bin/firefox

# Bust the Docker cache based on a flag file,
# computed from the SHA of the head of git tree (when bind mounted)
COPY --chown=www-data:www-data ledgersmb.rebuild /var/www/ledgersmb.rebuild
COPY --chown=www-data:www-data configs/git-colordiff.sh /var/www/git-colordiff.sh

ENV LANG=C.UTF-8

RUN mkdir -p /usr/share/sql-ledger/users
COPY sql-ledger/users/members /usr/share/sql-ledger/users/members

# Avahi
ADD configs/avahi.conf /etc/dbus-1/system.d/avahi.conf

# workaround to get dbus working, required for avahi to talk to dbus. This will be mounted
RUN mkdir -p /var/run/dbus
VOLUME /var/run/dbus

COPY start.sh /usr/local/bin/start.sh
COPY update_ssmtp.sh /usr/local/bin/update_ssmtp.sh

RUN chown www-data /etc/ssmtp /etc/ssmtp/ssmtp.conf && \
  chmod +x /usr/local/bin/update_ssmtp.sh /usr/local/bin/start.sh

# Add temporary patches
COPY patch/patches.tar.xz /tmp
RUN cd / && tar Jxf /tmp/patches.tar.xz && rm /tmp/patches.tar.xz

# React stuff
#TODO: Find cpanfile equivalent
ENV NODE_PATH=UI/node_modules
ENV NODE_ENV=development

#
USER www-data
WORKDIR /var/www
COPY package.json /var/www/package.json
RUN npm config set registry="http://registry.npmjs.org/"
RUN npm install --save-dev

RUN xauth add ylaho3:0 MIT-MAGIC-COOKIE-1 083b320b62214727060c3468777f3333

COPY --chown=www-data:www-data configs/mcthemes.tar.xz /var/www/mcthemes.tar.xz
COPY configs/.bashrc /root/.bashrc
COPY --chown=www-data:www-data configs/.bashrc /var/www/.bashrc
COPY --chown=www-data:www-data configs/.dataprinter /var/www/.dataprinter

RUN cd /var/www && \
  mkdir -p .config/mc && \
  touch .config/mc/ini && \
  tar Jxf mcthemes.tar.xz && \
  ./mcthemes/mc_change_theme.sh mcthemes/puthre.theme && \
  rm mcthemes.tar.xz

WORKDIR /srv/ledgersmb

CMD ["start.sh"]
