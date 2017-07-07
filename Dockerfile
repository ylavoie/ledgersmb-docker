FROM        ubuntu:trusty
MAINTAINER  Freelock john@freelock.com

RUN echo -n "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";\n" >> /etc/apt/apt.conf

# We need our repository for Trusty libpgobject*
RUN apt-get update && \
    apt-get -y install software-properties-common wget && \
    add-apt-repository ppa:ledgersmb/main

# Install Perl, Tex, Starman, psql client, and all dependencies
RUN DEBIAN_FRONTEND=noninteractive && \
  apt-get update && apt-get -y install \
  libcgi-emulate-psgi-perl libcgi-simple-perl libconfig-inifiles-perl \
  libdbd-pg-perl libdbi-perl libdatetime-perl \
  libdatetime-format-strptime-perl libdigest-md5-perl \
  libfile-mimeinfo-perl libjson-xs-perl libjson-perl \
  liblocale-maketext-perl liblocale-maketext-lexicon-perl \
  liblog-log4perl-perl libmime-base64-perl libmime-lite-perl \
  libmath-bigint-gmp-perl libmoose-perl libnumber-format-perl \
  libpgobject-perl libpgobject-simple-perl libpgobject-simple-role-perl \
  libpgobject-util-dbmethod-perl libplack-perl libtemplate-perl \
  libnamespace-autoclean-perl \
  libtemplate-plugin-latex-perl libtex-encode-perl \
  libmoosex-nonmoose-perl \
  texlive-latex-recommended \
  texlive-xetex \
  starman \
  libopenoffice-oodoc-perl \
  ssmtp \
  lsb-release && \
  rm -rf /var/lib/apt/lists/*

# Trusty builds for PostgreSQL higher than 9.1
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list && \
    wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

RUN apt-get update && apt-get -y install \
             libtap-parser-sourcehandler-pgtap-perl pgtap \
             libpq-dev \
             postgresql-client-9.3 postgresql-9.3-pgtap && \
    rm -rf /var/lib/apt/lists/*

# Build time variables
ENV LSMB_VERSION master
ENV NODE_PATH /usr/local/lib/node_modules
ENV DEBIAN_FRONTEND=noninteractive

ARG CACHEBUST

# Java & Nodejs for doing Dojo build
# Uglify needs to be installed right before 'make dojo'?!
RUN apt-get update && apt-get -y install \
             git make gcc libperl-dev npm curl && \
  rm -rf /var/lib/apt/lists/* && \
  update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100

WORKDIR /srv
RUN git clone --recursive -b $LSMB_VERSION https://github.com/ledgersmb/LedgerSMB.git ledgersmb

WORKDIR /srv/ledgersmb

# master requirements
RUN curl -L https://cpanmin.us | perl - App::cpanminus && \
  cpanm --quiet --notest \
  --with-feature=starman \
  --with-feature=latex-pdf-ps \
  --with-feature=openoffice \
  --with-feature=latex-pdf-images \
  --with-feature=latex-pdf-ps \
  --with-feature=xls \
  --installdeps .

# Uglify needs to be installed right before 'make dojo'?!
RUN npm install -g uglify-js@">=2.0 <3.0"
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

COPY start.sh /usr/local/bin/start.sh
COPY update_ssmtp.sh /usr/local/bin/update_ssmtp.sh

# Make sure www-data share the uid/gid of the container owner on the host
#RUN groupmod --gid $HOST_GID www-data
#RUN usermod --uid $HOST_UID --gid $HOST_GID www-data
RUN groupmod --gid 1000 www-data
RUN usermod --uid 1000 --gid 1000 www-data

RUN chown www-data /etc/ssmtp /etc/ssmtp/ssmtp.conf && \
  chmod +x /usr/local/bin/update_ssmtp.sh /usr/local/bin/start.sh && \
  mkdir -p /var/www && chown www-data:www-data /var/www

# Work around an aufs bug related to directory permissions:
RUN mkdir -p /tmp && \
  chmod 1777 /tmp

# Internal Port Expose
EXPOSE 5001

# Add sudo capability
RUN echo "www-data ALL=NOPASSWD: ALL" >>/etc/sudoers

RUN apt-get update && \
  apt install -y mc inotify-tools && \
  rm -rf /var/lib/apt/lists/*

# Fix Module::Runtime
RUN cpanm Moose MooseX::NonMoose Data::Printer

# Add temporary patches
COPY patch/patches.tar /tmp
RUN cd / && tar xvf /tmp/patches.tar && rm /tmp/patches.tar
ENV LANG=C.UTF-8

RUN cpanm --quiet --notest Data::Printer Devel::hdb && \
    rm -r ~/.cpanm

COPY ledgersmb.rebuild /var/www/ledgersmb.rebuild

USER www-data

CMD ["start.sh"]
