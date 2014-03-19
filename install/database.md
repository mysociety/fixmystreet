---
layout: page
title: Database troubleshooting
---

# Database user access control

These instructions are for Debian; do consult the PostgreSQL documentation
if you are having trouble at this stage.

At this point you might need to configure PostgreSQL to allow password-based
access to the fms database as the user fms from using Unix-domain sockets.
Edit the file `/etc/postgresql/8.4/main/pg_hba.conf` and add as the
first line:

    local   fms     fms     md5

You will then need to restart PostgreSQL with:

    $ sudo /etc/init.d/postgresql restart

If you want to access the database from the command line, you can add
the following line to `~/.pgpass`:

    localhost:*:fms:fms:somepassword

Then you should be able to access the database with:

    $ psql -U fms fms

