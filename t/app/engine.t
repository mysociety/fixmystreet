use FixMyStreet::Test;

use Catalyst::Test 'FixMyStreet::App';

my $res = request("/?_override_foo=bar");

like $res->headers->header('Set-Cookie'), qr/SameSite=Lax/;

done_testing;
