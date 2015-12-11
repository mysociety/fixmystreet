use strict;
use warnings;

use Test::More tests => 2;

use_ok 'FixMyStreet::App';

# GAZE_URL chosen as it is unlikely to change
is FixMyStreet::App->config->{GAZE_URL},    #
  'http://gaze.mysociety.org/gaze',         #
  "check that known config param is loaded";
