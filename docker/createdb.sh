#!/bin/sh

createdb -T template0 -E UTF-8 template_utf8
psql <<- EOSQL
  UPDATE pg_database
  SET datistemplate=true, datallowconn=false
  WHERE datname='template_utf8';
EOSQL

createdb -T template_utf8 fixmystreet
