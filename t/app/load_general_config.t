#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 8;

use_ok 'FixMyStreet::App';

# GAZE_URL chosen as it is unlikely to change
is FixMyStreet::App->config->{GAZE_URL},    #
  'http://gaze.mysociety.org/gaze',         #
  "check that known config param is loaded";

my $conf = FixMyStreet::App->model('DB::Config')->find( { key => 'DOESNOTEXIST' } );
$conf->delete() if $conf;

ok !defined( FixMyStreet->config('DOESNOTEXIST') ), 'missing config is undef';

ok FixMyStreet::App->model('DB::Config')->new( { key => 'DOESNOTEXIST', value => 'VALUE' } )->insert, 'created key';

my $value = FixMyStreet->config('DOESNOTEXIST');

is $value, 'VALUE', 'config created';

ok FixMyStreet::App->model('DB::Config')->find_or_create( { key => 'GAZE_URL', value => 'http://example.com/gaze' } )->insert, 'created gaze key';

my $c = FixMyStreet::App->model('DB::Config')->find( { key => 'GAZE_URL' } );
is $c->value, 'http://example.com/gaze', 'config in db';

$value = FixMyStreet->config('GAZE_URL');
is $value, 'http://gaze.mysociety.org/gaze', 'uses value from file';

