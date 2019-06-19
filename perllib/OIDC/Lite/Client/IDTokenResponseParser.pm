package OIDC::Lite::Client::IDTokenResponseParser;

use strict;
use warnings;

use Try::Tiny qw/try catch/;
use OIDC::Lite::Model::IDToken;
use OAuth::Lite2::Formatters;
use OAuth::Lite2::Client::Error;

=head1 NAME

OIDC::Lite::Client::IDTokenResponseParser - parse id_token JWT into an
L<OIDC::Lite::Model::IDToken> object.

Acts the same as L<OIDC::Lite::Client::TokenResponseParser> but looks for an
id_token in the HTTP response instead of access_token.

=cut

sub new {
    bless {}, $_[0];
}

sub parse {
    my ($self, $http_res) = @_;

    my $formatter =
        OAuth::Lite2::Formatters->get_formatter_by_type(
            $http_res->content_type);

    my $token;

    if ($http_res->is_success) {

        OAuth::Lite2::Client::Error::InvalidResponse->throw(
            message => sprintf(q{Invalid response content-type: %s},
                $http_res->content_type||'')
        ) unless $formatter;

        my $result = try {
            return $formatter->parse($http_res->content);
        } catch {
            OAuth::Lite2::Client::Error::InvalidResponse->throw(
                message => sprintf(q{Invalid response format: %s}, $_),
            );
        };

        OAuth::Lite2::Client::Error::InvalidResponse->throw(
            message => sprintf("Response doesn't include 'id_token'")
        ) unless exists $result->{id_token};

        $token = OIDC::Lite::Model::IDToken->load($result->{id_token});

    } else {

        my $errmsg = $http_res->content || $http_res->status_line;
        if ($formatter && $http_res->content) {
            try {
                my $result = $formatter->parse($http_res->content);
                $errmsg = $result->{error}
                    if exists $result->{error};
            } catch {
        	return OAuth::Lite2::Client::Error::InvalidResponse->throw;
            };
        }
        OAuth::Lite2::Client::Error::InvalidResponse->throw( message => $errmsg );
    }
    return $token;
}

1;
