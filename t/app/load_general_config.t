use FixMyStreet::Test;

use_ok 'FixMyStreet';

is(FixMyStreet->config('GAZE_URL'),
  'https://gaze.mysociety.org/gaze',
  "check that known config param is loaded");

done_testing();
