use strict;
use warnings;

use Test::More tests => 2;

use_ok 'FixMyStreet';

is FixMyStreet->config('GAZE_URL'),
  'https://gaze.mysociety.org/gaze',
  "check that known config param is loaded";
