use strict;
use warnings;

use FixMyStreet::DB;

use Test::More;

use_ok("FixMyStreet::SendReport::Angus");

my $u = FixMyStreet::DB->resultset('User')->new( { email => 'test@example.org', name => 'A User' } );

my $p = FixMyStreet::DB->resultset('Problem')->new( {
    latitude => 1,
    longitude => 1,
    title => 'title',
    detail => 'detail',
    user => $u,
    id => 1,
    name => 'A User',
    cobrand => 'fixmystreet',
} );

my $angus = FixMyStreet::SendReport::Angus->new();

subtest 'parses authentication token correctly' => sub {
    my $authxml = <<EOT;
    <AuthenticateResponse>

            <AuthenticateResult>
                TVRreUxqRTJPQzR5TlRVdU1qSjhNakF4Tmpvd01Ub3lNam94TlRvME16b3pPUT09VGhvdVNoYWx0Tm90UGFzcw==
            </AuthenticateResult>
            <success>
                    True
            </success>
            <message></message>

    </AuthenticateResponse>
EOT
;
    is $angus->get_auth_token($authxml), 'TVRreUxqRTJPQzR5TlRVdU1qSjhNakF4Tmpvd01Ub3lNam94TlRvME16b3pPUT09VGhvdVNoYWx0Tm90UGFzcw==', 'token correct';
};

subtest 'parses report external id correctly' => sub {
    my $respxml = <<EOT;
<CreateRequestResponse>

    <CreateRequestResult>
        <RequestId>7245</RequestId>
    </CreateRequestResult>

    <success>True</success>
    <message></message>

</CreateRequestResponse>
EOT
;
    is $angus->get_external_id($respxml), '7245', 'external id correct';
};


done_testing();
