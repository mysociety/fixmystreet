#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 8;

use_ok 'FixMyStreet::App';

# GAZE_URL chosen as it is unlikely to change
is FixMyStreet::App->get_conf->{GAZE_URL},    #
  'http://gaze.mysociety.org/gaze',         #
  "check that known config param is loaded";

my $conf = FixMyStreet::App->model('DB::Config')->find( { key => 'DOESNOTEXIST' } );
$conf->delete() if $conf;

ok !defined( FixMyStreet::App->get_conf('DOESNOTEXIST') ), 'missing config is undef';

ok FixMyStreet::App->model('DB::Config')->new( { key => 'DOESNOTEXIST', value => 'VALUE' } )->insert, 'created key';

my $value = FixMyStreet::App->get_conf('DOESNOTEXIST');

is $value, 'VALUE', 'config created';
