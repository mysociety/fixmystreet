package t::MapIt;

use JSON;
use Web::Simple;

use mySociety::Locale;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /postcode/*) {
        my ($self, $postcode) = @_;
        my $response = $self->postcode($postcode);
        # We must make sure we output correctly for testing purposes, we might
        # be within a different locale here...
        my $json = mySociety::Locale::in_gb_locale {
            $self->json->encode($response) };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

sub postcode {
    my ($self, $postcode) = @_;
    return {
        wgs84_lat => 51.5, wgs84_lon => 2.1, postcode => $postcode,
    };
}

__PACKAGE__->run_if_script;
