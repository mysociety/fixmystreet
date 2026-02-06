package t::Mock::MyGovScotOIDC;

use JSON::MaybeXS;
use Web::Simple;
use DateTime;
use MIME::Base64 qw(encode_base64);
use MooX::Types::MooseLike::Base qw(:all);

has json => (
    is => 'lazy',
    default => sub { JSON->new->pretty->allow_blessed->convert_blessed },
);
has returns_email => ( is => 'rw', isa => Bool, default => 1 );
has returns_phone => ( is => 'rw', isa => Bool, default => 0 );
has host => ( is => 'rw', isa => Str, default => '' );

sub dispatch_request {
    my $self = shift;

    sub (GET + /oauth2/v2.0/authorize + ?*) {
        return [ 200, [ 'Content-Type' => 'text/html' ], [ 'MyGovScot OIDC login page' ] ];
    },
    sub (GET + /oauth2/v2.0/logout + ?*) {
        return [ 200, [ 'Content-Type' => 'text/html' ], [ 'MyGovScot OIDC logout page' ] ];
    },
    sub (POST + /oauth2/v2.0/token + ?*) {
        my ($self) = @_;
        my $now = DateTime->now->epoch;
        my $header = { typ => 'JWT', alg => 'RS256', kid => 'XXXfakeKEY1234' };
        my $payload = {
            exp => $now + 3600, nbf => $now, ver => '1.0',
            iss => 'https://login.example.org/12345/v2.0/',
            sub => 'mygov_user_id', aud => 'example_client_id',
            iat => $now, auth_time => $now, nonce => 'MyAwesomeRandomValue',
        };
        my $id_token = join('.',
            encode_base64($self->json->encode($header), ''),
            encode_base64($self->json->encode($payload), ''),
            encode_base64('dummy', ''),
        );
        my $data = {
            access_token => 'MyGovScotAccessToken',
            id_token => $id_token,
            token_type => 'Bearer',
            not_before => $now,
            id_token_expires_in => 3600,
            profile_info => encode_base64($self->json->encode({}), ''),
        };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $self->json->encode($data) ] ];
    },
    sub (GET + /userinfo + ?*) {
        my ($self) = @_;
        my $user = { fname => 'Simon', lname => 'Neil' };
        $user->{emailaddress} = 'simon.neil@example.org' if $self->returns_email;
        $user->{mobilenumber} = '+447700900000' if $self->returns_phone;
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $self->json->encode($user) ] ];
    },
}

__PACKAGE__->run_if_script;
