package OIDC::Lite::Client::WebServer::Azure;

use strict;
use warnings;
use parent 'OIDC::Lite::Client::WebServer';

use OIDC::Lite::Client::IDTokenResponseParser;

=head1 NAME

OIDC::Lite::Client::WebServer::Azure - extension to auth against Azure AD B2C

OIDC::Lite doesn't appear to support the authorisation code flow to get an
ID token - only an access token. Azure returns all its claims in the id_token
and doesn't support a UserInfo endpoint, so this extension adds support for
parsing the id_token when calling get_access_token.

=cut

=head2 new

Overrides response_parser so that get_access_token returns a
L<OIDC::Lite::Model::IDToken> object.

NB this does not perform any verification of the id_token. It's assumed to be
safe as it's come directly from the OpenID IdP and not an untrusted user's
browser.

=cut

sub new {
    my $self = shift->next::method(@_);

    $self->{response_parser} = OIDC::Lite::Client::IDTokenResponseParser->new;

    return $self;
}

1;
