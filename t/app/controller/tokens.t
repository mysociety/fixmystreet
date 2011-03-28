use strict;
use warnings;
use Test::More;


use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::App::Controller::Tokens;

ok( request('/tokens')->is_success, 'Request should succeed' );
done_testing();
