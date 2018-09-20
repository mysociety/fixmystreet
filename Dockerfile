FROM jgoerzen/debian-base-standard:stretch
MAINTAINER bettercities@mysociety.org

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -qq update && apt-get -qq -y install --no-install-recommends apt-utils && apt-get -qq -y install git locales

RUN wget -O install-site.sh --no-verbose https://raw.githubusercontent.com/mysociety/commonlib/docker/bin/install-site.sh && chmod +x /install-site.sh

RUN \
  REPOSITORY_URL_OVERRIDE=git://github.com/sagepe/fixmystreet.git \
  BRANCH_OVERRIDE=docker \
  /install-site.sh --docker fixmystreet fms 127.0.0.1.xip.io \
  \
  && apt-get purge -y --auto-remove \
    make \
    g++ \
    libexpat1-dev \
    libssl-dev \
    zlib1g-dev \
    postgresql-server-dev-all


COPY ./bin/docker.preinit /usr/local/preinit/99-fixmystreet
RUN chmod +x /usr/local/preinit/99-fixmystreet

EXPOSE 9000
CMD ["/usr/local/bin/boot-debian-base"]
