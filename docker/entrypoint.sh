#!/bin/bash

set -e

cd "$(dirname "$0")/.."

if [ ! -f conf/general.yml ]; then
    sed -r \
        -e "s,^( *FMS_DB_HOST:).*,\\1 'postgres.svc'," \
        -e "s,^( *FMS_DB_NAME:).*,\\1 'fixmystreet'," \
        -e "s,^( *FMS_DB_USER:).*,\\1 'postgres'," \
        -e "s,^( *FMS_DB_PASS:).*,\\1 'password'," \
        -e "s,^( *BASE_URL:).*,\\1 'http://127.0.0.1.nip.io:3000'," \
        -e "s,^( *MAPIT_URL:).*,\\1 'http://localhost:3000/fakemapit/'," \
        -e "s,^( *MEMCACHED_HOST:).*,\\1 'memcached.svc'," \
        -e "s,^( *SMTP_SMARTHOST:).*,\\1 'email.svc'," \
        -e "s,^( *SMTP_PORT:).*,\\1 '1025'," \
        conf/general.yml-example > conf/general.yml
fi

script/update --development
bin/update-all-reports

script/server ${SERVER_ARGUMENTS}
