FROM        ubuntu:trusty
MAINTAINER  Freelock john@freelock.com

# Install Perl, Tex, Starman, psql client, and all dependencies
# Without libclass-c3-xs-perl, everything grinds to a halt;
# add it, because it's a 'recommends' it the dep tree, which
# we're skipping, normally

# 'master' and common dependency install:

RUN echo -n "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";\n" \
      >> /etc/apt/apt.conf && \
    echo 'options ndots:2' >>/etc/resolv.conf && \
    echo 'Acquire::http { Proxy "http://nameserver:3142"; };' >> /etc/apt/apt.conf.d/02proxy && \
  DEBIAN_FRONTEND=noninteractive apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install curl ca-certificates \
                                            gnupg2

# We need our repository for Trusty libpgobject*
RUN apt-get update && \
    apt-get -y install software-properties-common wget && \
    add-apt-repository ppa:ledgersmb/main

RUN \
  DEBIAN_FRONTEND=noninteractive apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
    libcgi-emulate-psgi-perl libconfig-inifiles-perl \
    libdbd-pg-perl libdbi-perl libdatetime-perl \
    libspreadsheet-writeexcel-perl \
    libdatetime-format-strptime-perl libfile-mimeinfo-perl \
    libhtml-parser-perl libio-stringy-perl libjson-maybexs-perl \
    libcpanel-json-xs-perl liblist-moreutils-perl \
    liblocale-maketext-perl liblocale-maketext-lexicon-perl \
    liblog-log4perl-perl libwww-perl libmime-lite-perl \
    libmodule-runtime-perl libmath-bigint-gmp-perl libmoose-perl \
    libmoosex-nonmoose-perl libnumber-format-perl \
    libole-storage-lite-perl libparse-recdescent-perl \
    libpgobject-perl libpgobject-simple-perl libpgobject-simple-role-perl \
    libpgobject-type-bytestring-perl \
    libpgobject-util-dbmethod-perl \
    libplack-perl libplack-middleware-reverseproxy-perl \
    libspreadsheet-writeexcel-perl libtemplate-perl \
    libtry-tiny-perl libtext-csv-perl libtext-csv-xs-perl libxml-simple-perl \
    libnamespace-autoclean-perl libdata-uuid-perl \
    libtemplate-plugin-latex-perl libtex-encode-perl \
    libmoosex-nonmoose-perl libclass-c3-xs-perl \
    texlive-latex-recommended \
    libx12-parser-perl \
    texlive-xetex \
    starman \
    libxml-twig-perl libopenoffice-oodoc-perl \
    postgresql-client libpq-dev \
    ssmtp \
    git cpanminus make gcc nodejs libperl-dev lsb-release libcarp-always-perl \
    gettext procps libtap-parser-sourcehandler-pgtap-perl \
    libtest-dependencies-perl libtest-exception-perl libtest-trap-perl \
    libperl-critic-perl libmodule-cpanfile-perl libfile-util-perl \
    libclass-trigger-perl libclass-accessor-lite-perl libtest-requires-perl \
    libmodule-install-perl nodejs \
    python-pip python-urllib3 python-six npm
#   libpgobject-type-bigfloat-perl libpgobject-type-datetime-perl
RUN pip install transifex-client || :
RUN npm install -g uglify-js@">=2.0 <3.0"

# Local development tools
RUN apt-get update && \
  apt-get install -qyy mc gettext sudo bzip2 bash-completion less meld xauth \
                   lynx dnsutils net-tools xz-utils \
  && DEBIAN_FRONTEND="noninteractive" apt-get -y autoremove \
  && DEBIAN_FRONTEND="noninteractive" apt-get -y autoclean \
  && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100

## See also https://github.com/Yelp/dumb-init
#RUN wget https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64.deb \
# && dpkg -i dumb-init_*.deb \
# && rm dumb-init_*.deb
#ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Add Tini
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

# Build time variables
ENV NODE_PATH /usr/local/lib/node_modules
ENV LSMB_VERSION master

# Install LedgerSMB
WORKDIR /srv
RUN git clone --recursive -b $LSMB_VERSION https://github.com/ledgersmb/LedgerSMB.git ledgersmb

ENV NODE_PATH /usr/local/lib/node_modules

WORKDIR /srv/ledgersmb

# Build dojo
RUN make dojo

# Configure outgoing mail to use host, other run time variable defaults

## sSMTP
ENV SSMTP_ROOT ar@example.com
ENV SSMTP_MAILHUB 172.17.0.1
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

WORKDIR /srv/ledgersmb

COPY cpanfile /srv/ledgersmb/cpanfile
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
    WebService::Validator::HTML::W3C && \
    npm install floatthead

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

COPY start.sh /usr/local/bin/start.sh
COPY update_ssmtp.sh /usr/local/bin/update_ssmtp.sh

RUN chown www-data /etc/ssmtp /etc/ssmtp/ssmtp.conf && \
  chmod +x /usr/local/bin/update_ssmtp.sh /usr/local/bin/start.sh && \
  mkdir -p /var/www && chown www-data:www-data /var/www

# Add sudo capability
RUN echo "www-data ALL=NOPASSWD: ALL" >>/etc/sudoers

# Bust the Docker cache based on a flag file,
# computed from the SHA of the head of git tree (when bind mounted)
COPY --chown=www-data:www-data ledgersmb.rebuild /var/www/ledgersmb.rebuild
COPY --chown=www-data:www-data git-colordiff.sh /var/www/git-colordiff.sh

# Add temporary patches
COPY patch/patches.tar /tmp
#RUN cd / && tar xvf /tmp/patches.tar && rm /tmp/patches.tar
ENV LANG=C.UTF-8

RUN mkdir -p /usr/share/sql-ledger/users
COPY sql-ledger/users/members /usr/share/sql-ledger/users/members

# install necessary stuff; avahi, and ssh such that we can log in and control avahi
RUN apt-get update -y \
  && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y avahi-daemon avahi-utils \
  && apt-get -qq -y autoclean \
  && apt-get -qq -y autoremove \
  && apt-get -qq -y clean

# Avahi
ADD avahi-daemon.conf /etc/avahi/avahi-daemon.conf

# workaround to get dbus working, required for avahi to talk to dbus. This will be mounted
RUN mkdir -p /var/run/dbus
VOLUME /var/run/dbus

USER www-data
WORKDIR /var/www
RUN xauth add ylaho3:0 MIT-MAGIC-COOKIE-1 083b320b62214727060c3468777f3333

COPY --chown=www-data:www-data mcthemes.tar.xz /var/www/mcthemes.tar.xz
COPY --chown=www-data:www-data .bashrc /var/www/.bashrc
COPY --chown=www-data:www-data .dataprinter /var/www/.dataprinter

RUN cd /var/www && \
  mkdir -p .config/mc && \
  touch .config/mc/ini && \
  tar Jxf mcthemes.tar.xz && \
  ./mcthemes/mc_change_theme.sh mcthemes/puthre.theme && \
  rm mcthemes.tar.xz

WORKDIR /srv/ledgersmb

CMD ["start.sh"]
