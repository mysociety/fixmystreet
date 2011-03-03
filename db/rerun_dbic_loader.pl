#!/usr/bin/env perl

use strict;
use warnings;

# This script inspects the current state of the database and then ammends the
# FixMyStreet::DB::Result::* files to suit. After running the changes should be
# inspected before the code is commited.

use FixMyStreet;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;

# create a exclude statement that filters out the table that we are not
# interested in
my @tables_to_ignore = (
    'abuse',         'admin_log',       'alert',        'alert_sent',
    'alert_type',    'comment',         'contacts',     'contacts_history',
    'debugdate',     'flickr_imported', 'partial_user', 'problem',
    'questionnaire', 'secret',          'textmystreet',
);
my $exclude = '^(?:' . join( '|', @tables_to_ignore ) . ')$';

make_schema_at(
    'FixMyStreet::DB',
    {
        debug          => 0,               # switch on to be chatty
        dump_directory => './lib',         # edit files in place
        exclude        => qr{$exclude},    # ignore some tables
        generate_pod   => 0,               # no need for pod
        overwrite_modifications => 1,      # don't worry that the md5 is wrong
    },
    FixMyStreet->dbic_connect_info(),
);

