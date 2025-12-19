package FixMyStreet::Roles::MyGovScotOIDC;
use Moo::Role;

use JSON::MaybeXS;
use LWP::UserAgent;

=head1 NAME

FixMyStreet::Roles::MyGovScotOIDC - role for enabling mygov.scot OIDC SSO

=cut

=item * Single sign on is enabled from the cobrand feature 'oidc_login'

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * Extract the user's details from the OIDC token

=cut

sub user_from_oidc {
    my ($self, $payload, $access_token) = @_;

    my $name = '';
    my $email = '';

    # Payload doesn't include user's name so fetch it from
    # the OIDC userinfo endpoint.
    my $cfg = $self->feature('oidc_login');
    if ($access_token && $cfg->{userinfo_uri}) {
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get(
            $cfg->{userinfo_uri},
            Authorization => 'Bearer ' . $access_token,
        );
        my $user = decode_json($response->decoded_content);
        if ($user->{fname} && $user->{lname}) {
            $name = join(" ", $user->{fname}, $user->{lname});
        }
        if ($user->{emailaddress}) {
            $email = $user->{emailaddress};
        }
    }

    # In case we didn't get email from the claims above, default to value
    # present in payload. NB name is not available in this manner.
    $email ||= $payload->{sub} ? lc($payload->{sub}) : '';

    return ($name, $email);
}

1;
