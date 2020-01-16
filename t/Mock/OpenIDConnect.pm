package t::Mock::OpenIDConnect;

use JSON::MaybeXS;
use Web::Simple;
use DateTime;
use MIME::Base64 qw(encode_base64);
use MooX::Types::MooseLike::Base qw(:all);

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

has returns_email => (
    is => 'rw',
    isa => Bool,
    default => 1,
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /oauth2/v2.0/authorize + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'text/html' ], [ 'OpenID Connect login page' ] ];
    },

    sub (GET + /oauth2/v2.0/logout + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'text/html' ], [ 'OpenID Connect logout page' ] ];
    },

    sub (POST + /oauth2/v2.0/token + ?*) {
        my ($self) = @_;
        my $header = {
            typ => "JWT",
            alg => "RS256",
            kid => "XXXfakeKEY1234",
        };
        my $now = DateTime->now->epoch;
        my $payload = {
            exp => $now + 3600,
            nbf => $now,
            ver => "1.0",
            iss => "https://login.example.org/12345-6789-4321-abcd-12309812309/v2.0/",
            sub => "my_cool_user_id",
            aud => "example_client_id",
            iat => $now,
            auth_time => $now,
            given_name => "Andy",
            family_name => "Dwyer",
            tfp => "B2C_1_default",
            extension_CrmContactId => "1c304134-ef12-c128-9212-123908123901",
            nonce => 'MyAwesomeRandomValue',
        };
        $payload->{emails} = ['pkg-tappcontrollerauth_socialt-oidc@example.org'] if $self->returns_email;
        my $signature = "dummy";
        my $id_token = join(".", (
            encode_base64($self->json->encode($header), ''),
            encode_base64($self->json->encode($payload), ''),
            encode_base64($signature, '')
        ));
        my $data = {
            id_token => $id_token,
            token_type => "Bearer",
            not_before => $now,
            id_token_expires_in => 3600,
            profile_info => encode_base64($self->json->encode({}), ''),
        };
        my $json = $self->json->encode($data);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

__PACKAGE__->run_if_script;
