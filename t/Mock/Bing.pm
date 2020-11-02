package t::Mock::Bing;

use JSON::MaybeXS;
use Web::Simple;
use LWP::Protocol::PSGI;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /REST/v1/Locations + ?*) {
        my ($self, $query) = @_;
        my $results = [ {
            point => { coordinates => [ 51, -1 ] },
            name => 'Constitution Hill, London, SW1A',
            confidence => 'High',
            address => {
                addressLine => 'Constitution Hill',
                locality => 'London',
                countryRegion => 'United Kingdom',
            }
        } ];
        if ($query->{q} =~ /two results/) {
            push @$results, {
                point => { coordinates => [ 51, -1 ] },
                name => 'Constitution Hill again, United Kingdom',
                confidence => 'High',
                address => {
                    addressLine => 'Constitution Hill again',
                    locality => 'London',
                    countryRegion => 'United Kingdom',
                }
            };
        }
        if ($query->{q} =~ /low/) {
            push @$results, {
                point => { coordinates => [ 52, -2 ] },
                name => 'Constitution Hill elsewhere, United Kingdom',
                confidence => 'Low',
                address => {
                    addressLine => 'Constitution Hill elsewhere',
                    locality => 'London',
                    countryRegion => 'United Kingdom',
                }
            };
        }
        if ($query->{q} =~ /onlylow/) {
            @$results = map { $_->{confidence} = 'Low'; $_ } @$results;
        }
        my $data = {
            statusCode => 200,
            resourceSets => [ { resources => $results } ],
        };
        my $json = $self->json->encode($data);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /REST/v1/Locations/* + ?*) {
        my ($self, $location, $query) = @_;
        my $data = {
            resourceSets => [ {
                resources => [ {
                    name => 'Constitution Hill, London, SW1A',
                    address => {
                        addressLine => 'Constitution Hill',
                        locality => 'London',
                    }
                } ],
            } ],
        };
        my $json = $self->json->encode($data);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

LWP::Protocol::PSGI->register(t::Mock::Bing->to_psgi_app, host => 'dev.virtualearth.net');

__PACKAGE__->run_if_script;
