#!/usr/bin/perl
#
# Utils.pm:
# Various generic utilities for FixMyStreet.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Utils.pm,v 1.1 2008-10-09 14:20:54 matthew Exp $
#

package Utils;

use strict;
use mySociety::DBHandle qw(dbh);

sub workaround_pg_bytea {
    my ($st, $img_idx, @elements) = @_;
    my $s = dbh()->prepare($st);
    for (my $i=1; $i<=@elements; $i++) {
        if ($i == $img_idx) {
            $s->bind_param($i, $elements[$i-1], { pg_type => DBD::Pg::PG_BYTEA });
        } else {
            $s->bind_param($i, $elements[$i-1]);
        }
    }
    $s->execute();
}

1;
