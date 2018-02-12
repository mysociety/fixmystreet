package t::Mock::GoogleGeocoder;

use JSON::MaybeXS;
use Web::Simple;
use LWP::Protocol::PSGI;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->utf8->pretty->allow_blessed->convert_blessed;
    },
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /maps/api/geocode/json + ?*) {
        my ($self, $args) = @_;
        my $response = {};
        if ($args->{address} =~ /result/) {
            $response->{status} = 'OK';
            push @{$response->{results}}, { formatted_address => 'High Street, Old Town, City of Edinburgh, Scotland', geometry => { location => { lng => -3.1858425, lat => 55.9504009 } } };
        }
        if ($args->{address} eq 'two results') {
            push @{$response->{results}}, { geometry => { location => { lat => "55.8596449", "lng" => "-4.240377" } }, formatted_address => "High Street, Collegelands, Merchant City, Glasgow, Scotland" };
        }
        my $json = mySociety::Locale::in_gb_locale {
            $self->json->encode($response);
        };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

LWP::Protocol::PSGI->register(t::Mock::GoogleGeocoder->to_psgi_app, host => 'maps.googleapis.com');

__PACKAGE__->run_if_script;
