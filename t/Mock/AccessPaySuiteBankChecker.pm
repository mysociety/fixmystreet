package t::Mock::AccessPaySuiteBankChecker;

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

sub dispatch_request {
    my $self = shift;

    sub (GET + ?*) {
        my ($self, $query) = @_;
        if (my $code = $query->{sortCode}) {
            my $codes = {
                # valid everything
                123456 => {
                    success => {
                        account => {
                            status => JSON->true,
                            cautious => JSON->false,
                        },
                        sortcode => {
                            Bank => 'Test Bank',
                            Branch => 'Test Branch',
                        },
                    },
                },

                # invalid account number
                110012 => {
                    success => {
                        account => {
                            status => JSON->false,
                        },
                        sortcode => {
                            Bank => 'Test Bank',
                            Branch => 'Test Branch',
                        },
                    },
                },

                # invalid sort code
                110013 => {
                    success => {
                        account => {
                            status => JSON->true,
                            cautious => JSON->false,
                        },
                        sortcode => "invalid",
                    },
                },

                # invalid api key
                110014 => { error => "Either the client code or the API key is incorrect."},

                # invalid client param
                110015 => { error => "Either the client code or the API key is incorrect, or there is more than one client with the same code in the database"},

                # another weird error
                110016 => { error => "Account number includes non-numeric characters"},

            };
            my $default = { error => "Invalid parameters." };

            if ( $code eq '000000' ) {
                return [ 200, [ 'Content-Type' => 'text/plain' ], [ "this is just a plain text string" ] ];
            } else {
                return $self->output($codes->{$code} || $default);
            }
        }
    },

}

__PACKAGE__->run_if_script;
