use strict;
use warnings;

use Test::More tests => 4;

use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

my $mech = Test::WWW::Mechanize::Catalyst->new;

# homepage ok
$mech->get_ok('/');

# get 404 page
my $path_to_404 = '/bad/path/page_error_404_not_found';
my $res         = $mech->get($path_to_404);
ok !$res->is_success(), "want a bad response";
is $res->code, 404, "got 404";
$mech->content_contains($path_to_404);
