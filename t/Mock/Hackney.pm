package t::Mock::Hackney;

use JSON::MaybeXS;
use Web::Simple;
use LWP::Protocol::PSGI;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub output {
    my ($self, $response) = @_;
    my $json = $self->json->encode($response);
    return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
}

my $addresses = {
    10008312004 => {
        locality => 'HACKNEY',
        line1 => 'FLAT 1',
        line2 => '176-179 SHOREDITCH HIGH STREET',
        line3 => 'HACKNEY',
        postcode => 'E1 6AX',
        UPRN => '10008312004',
        latitude => '51.524449',
        longitude => '-0.077625',
    },
    100000222 => {
        locality => 'ELSEWHERE',
        line1 => '1 ROAD ROAD',
        line2 => '',
        line3 => '',
        postcode => 'SW1A 1AA',
        UPRN => '100000222',
        latitude => '52',
        longitude => '2',
    },
    100022950072 => {
        locality => 'HACKNEY',
        line1 => '1000000 SHOREDITCH HIGH STREET',
        line2 => 'HACKNEY',
        line3 => '',
        postcode => 'E1 6AX',
        UPRN => '100022950072',
        latitude => '51.524448',
        longitude => '-0.077625',
    },
};

sub dispatch_request {
    my $self = shift;

    sub (GET + ?*) {
        my ($self, $query) = @_;
        if ($query->{uprn}) {
            return $self->output({
                data => {
                    address => [ $addresses->{$query->{uprn}} ],
                    pageCount => 1,
                    total_count => 2,
                },
                statusCode => 200,
                error => undef,
            });
        }

        return $self->output({}) if $query->{postcode} eq 'B2 4QA';
        if ($query->{postcode} eq 'L1 1JD') {
            my $response = {
                data => {
                    pageCount => 1,
                    address => [ { locality => 'ELSEWHERE' } ]
                }
            };
            return $self->output($response);
        }
        my $response = {
            data => {
                address => [ values %$addresses ],
                pageCount => 1,
                total_count => 4,
            },
            statusCode => 200,
            error => undef,
        };
        return $self->output($response);
    },

}

__PACKAGE__->run_if_script;
