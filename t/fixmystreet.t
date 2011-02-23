use strict;
use warnings;
use Path::Class;

use Test::More tests => 4;

use_ok 'FixMyStreet';

# check that the path_to works
my $file_path    = file(__FILE__)->absolute->stringify;
my $path_to_path = FixMyStreet->path_to('t/fixmystreet.t');

isa_ok $path_to_path, 'Path::Class::File';
ok $path_to_path->is_absolute, "path is absolute";
is "$path_to_path", $file_path, "got $file_path";

