use strict;
use warnings;
use Test::More;


use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::App::Controller::My;

ok( request('/my')->is_success, 'Request should succeed' );
done_testing();
