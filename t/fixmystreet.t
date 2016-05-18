use strict;
use warnings;
use Path::Class;

use Test::More;
use Test::Exception;

use_ok 'FixMyStreet';

# check that the path_to works
my $file_path    = file(__FILE__)->absolute->stringify;
my $path_to_path = FixMyStreet->path_to('t/fixmystreet.t');

isa_ok $path_to_path, 'Path::Class::File';
ok $path_to_path->is_absolute, "path is absolute";
is "$path_to_path", $file_path, "got $file_path";

# check that the config gets loaded and is immutable
my $config = FixMyStreet->config;
isa_ok $config, 'HASH';
is $config->{GAZE_URL}, 'https://gaze.mysociety.org/gaze',
  "got GAZE_URL correctly";
throws_ok(
    sub { $config->{GAZE_URL} = 'some other value'; },
    qr/Modification of a read-only value attempted/,
    'attempt to change config caught'
);
is $config->{GAZE_URL}, 'https://gaze.mysociety.org/gaze', "GAZE_URL unchanged";

# check that we can get the value by key as well
is FixMyStreet->config('GAZE_URL'), 'https://gaze.mysociety.org/gaze',
  "GAZE_URL correct when got by key";
is FixMyStreet->config('BAD_KEY_DOES_NOT_EXIST'), undef, "config miss is undef";

# all done
done_testing();

