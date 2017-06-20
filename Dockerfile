FROM        ubuntu:trusty
MAINTAINER  Freelock john@freelock.com

RUN echo -n "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";\n" >> /etc/apt/apt.conf

RUN apt-get update && \
    apt-get -y install software-properties-common && \
    add-apt-repository ppa:ledgersmb/main


# Install Perl, Tex, Starman, psql client, and all dependencies
RUN DEBIAN_FRONTENT=noninteractive && \
  apt-get update && apt-get -y install \
  libcgi-emulate-psgi-perl libcgi-simple-perl libconfig-inifiles-perl \
  libdbd-pg-perl libdbi-perl libdatetime-perl \
  libdatetime-format-strptime-perl libdigest-md5-perl \
  libfile-mimeinfo-perl libjson-xs-perl libjson-perl \
  liblocale-maketext-perl liblocale-maketext-lexicon-perl \
  liblog-log4perl-perl libmime-base64-perl libmime-lite-perl \
  libmath-bigint-gmp-perl libmoose-perl libnumber-format-perl \
  libpgobject-perl libpgobject-simple-perl libpgobject-simple-role-perl \
  libplack-perl libtemplate-perl \
  libnamespace-autoclean-perl \
  libtemplate-plugin-latex-perl libtex-encode-perl \
  libmoosex-nonmoose-perl \
  texlive-latex-recommended \
  texlive-xetex \
  starman \
  libopenoffice-oodoc-perl \
  postgresql-client \
  ssmtp \
  git cpanminus make gcc libperl-dev lsb-release

# libpgobject-util-dbmethod-perl? Not available on Trusty

# Java & Nodejs for doing Dojo build
#RUN DEBIAN_FRONTENT=noninteractive && apt-get install -y openjdk-7-jre-headless
RUN DEBIAN_FRONTENT=noninteractive && \
  apt-get -y install postgresql-server-dev-all liblocal-lib-perl pgtap

RUN apt-get install -y npm
RUN update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100

# Build time variables
ENV LSMB_VERSION master
ARG CACHEBUST

# Install LedgerSMB
RUN cd /srv && \
  git clone --recursive -b $LSMB_VERSION https://github.com/ledgersmb/LedgerSMB.git ledgersmb

WORKDIR /srv/ledgersmb

# master requirements
RUN cpanm --quiet --notest \
  --with-develop \
  --with-feature=starman \
  --with-feature=latex-pdf-ps \
  --with-feature=openoffice \
  --installdeps .

# Uglify needs to be installed right before 'make dojo'?!
RUN npm install -g uglify-js@">=2.0 <3.0"
ENV NODE_PATH /usr/local/lib/node_modules

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

COPY start.sh /usr/local/bin/start.sh
COPY update_ssmtp.sh /usr/local/bin/update_ssmtp.sh

RUN chown www-data /etc/ssmtp /etc/ssmtp/ssmtp.conf && \
  chmod +x /usr/local/bin/update_ssmtp.sh /usr/local/bin/start.sh && \
  mkdir -p /var/www && chown www-data /var/www

# Work around an aufs bug related to directory permissions:
RUN mkdir -p /tmp && \
  chmod 1777 /tmp

# Internal Port Expose
EXPOSE 5762

# Add sudo capability
RUN echo "www-data ALL=NOPASSWD: ALL" >>/etc/sudoers

# If ledgersmb.conf does not exist, www-data user needs to be able to create it.
RUN chown www-data /srv/ledgersmb
USER www-data

RUN cpanm --local-lib=/var/www/perl5 local::lib && eval $(perl -I /var/www/perl5/lib/perl5/ -Mlocal::lib)

ENV HOME /var/www
ENV PHANTOMJS phantomjs-2.1.1-linux-x86_64
ENV PATH /var/www/phantomjs-2.1.1-linux-x86_64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN sudo apt-get install -y mc wget
RUN mkdir -p $HOME/phantomjs
RUN wget -q https://efficito.com/phantomjs/$PHANTOMJS.tar.bz2 -O $HOME/$PHANTOMJS.tar.bz2
RUN tar -xvf $HOME/$PHANTOMJS.tar.bz2 -C $HOME
RUN rm $HOME/$PHANTOMJS.tar.bz2

CMD ["start.sh"]
