FROM jgoerzen/debian-base-standard:stretch
MAINTAINER bettercities@mysociety.org

ARG DEBIAN_FRONTEND=noninteractive
ARG REPOSITORY_URL_OVERRIDE=git://github.com/mysociety/fixmystreet.git
ARG BRANCH_OVERRIDE=docker

RUN apt-get -qq update && apt-get -qq -y install --no-install-recommends apt-utils && apt-get -qq -y install git locales

RUN wget -O install-site.sh --no-verbose https://raw.githubusercontent.com/mysociety/commonlib/docker/bin/install-site.sh && chmod +x /install-site.sh

RUN \
  /install-site.sh --docker fixmystreet fms 127.0.0.1.xip.io \
  \
  && apt-get purge -y --auto-remove \
    make \
    g++ \
    libexpat1-dev \
    libssl-dev \
    zlib1g-dev \
    postgresql-server-dev-all \
  && rm -fr /home/fms/.cpanm/*

RUN cp /var/www/fixmystreet/fixmystreet/bin/docker.preinit /usr/local/preinit/99-fixmystreet && chmod +x /usr/local/preinit/99-fixmystreet

EXPOSE 9000
CMD ["/usr/local/bin/boot-debian-base"]
