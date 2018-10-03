---
layout: page
title: Database troubleshooting
---

# Database user access control

<p class="lead">
  These instructions are for Debian &mdash; do consult the PostgreSQL
  documentation if you are having trouble at this stage.
</p>

At this point you might need to configure PostgreSQL to allow password-based
access to the `fms` database as the user `fms` from using Unix-domain sockets.
Edit the file `/etc/postgresql/9.6/main/pg_hba.conf` (note that the version
number in this path will vary depending on the version of Debian you are
using) and add as the first line:

    local   fms     fms     md5

You will then need to restart PostgreSQL with:

    $ sudo service postgresql restart

If you want to access the database from the command line, you can add
the following line to `~/.pgpass`:

    localhost:*:fms:fms:somepassword

Then you should be able to access the database with:

    $ psql -U fms fms

## Configuration

When you've got everything working, you'll need to update the
[database config settings]({{ "/customising/config/#fms_db_host" | relative_url }}).
