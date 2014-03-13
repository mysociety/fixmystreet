package Open311::Endpoint;

use Web::Simple;

use JSON;
use XML::Simple;
use Data::Rx;

use Open311::Endpoint::Result;
use Open311::Endpoint::Service;

use Data::Dumper;
use Scalar::Util 'blessed';
use List::Util 'first';

# http://wiki.open311.org/GeoReport_v2

sub dispatch_request {
    my $self = shift;

    sub (.*) {
        my ($self, $ext) = @_;
        $self->format_response($ext);
    },

    sub (GET + /services + ?*) {
        my ($self, $args) = @_;
        $self->call_api( GET_Service_List => $args );
    },

    sub (GET + /services/*) {
        my ($self, $service_id) = @_;
        # requires jurisdiction_id
        return bless {
            service_definition => {
                service_code => $service_id,
                attributes => [
                    {
                        attribute => {
                            variable => 'true|false',
                            code => undef,
                            datatype => 'string|number|datetime|text|singlevaluelist|multivaluelist',
                            required => 'true|false',
                            datatype_description => undef,
                            order => undef, #int
                            description => undef,
                            values => [
                                {
                                    value => {
                                        key => undef,
                                        name => undef,
                                    }
                                }
                            ],
                        },
                    },
                ],
            },
        }, 'Open311::Endpoint::Result';
    },

    sub (POST + /requests) {
        # jurisdiction_id
        # service_code
        # lat/lon OR address_string OR address_id
        # attribute: array of key/value responses, as per service definition
        # NB: various optional arguments
        
        return bless {
            service_requests => {
                request => {
                    service_request_id => undef,
                    service_notice => undef,
                },
            },
        }, 'Open311::Endpoint::Result';
    },

    sub (GET + /tokens/*) {
        return bless [], 'Open311::Endpoint::Result';
    },

    sub (GET + /requests) {
        return bless [], 'Open311::Endpoint::Result';
    },

    sub (GET + /requests/*) {
        return bless [], 'Open311::Endpoint::Result';
    },
}

has rx => (
    is => 'lazy',
    default => sub {
        my $schema = Data::Rx->new({
            prefix => {
                open311 => 'tag:wiki.open311.org,GeoReport_v2:rx/',
            }
        });
        # TODO, turn these into proper type_plugin
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/bool',
            {
                type => '//any',
                of => [
                    { type => '//str', value => 'true' },
                    { type => '//str', value => 'false' },
                ],
            }
        );
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/service',
            {
                type => '//rec',
                required => {
                    service_name => '//str',
                    type => '//str', # actually multi
                    metadata => '/open311/bool',
                    description => '//str',
                    service_code => '//str',
                },
                optional => {
                    keywords => '//str',
                    group => '//str',
                }
            }
        );
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/_service',
            {
                type => '//rec',
                required => {
                    service => '/open311/service',
                }
            }
        );
        return $schema;
    },
);

sub call_api {
    my ($self, $api_name, @args) = @_;
    
    my $api_method = $self->can($api_name)
        or die "No such API $api_name!";

    my @dispatchers;

    if (my $input_schema_method = $self->can("${api_name}_input_schema")) {
        push @dispatchers, sub () {
            my $schema = $self->rx->make_schema( $self->$input_schema_method );
            my $input = (scalar @args == 1) ? $args[0] : [@args];
            eval {
                $schema->assert_valid( $input );
            };
            if ($@) {
                my $data = {
                    error => 'Bad request',
                    details => [ map $_->struct, @{ $@->failures } ],
                };
                return Open311::Endpoint::Result->new({
                    status => 400,
                    data => $data,
                });
            }
            return; # pass onwards
        };
    }

    if (my $output_schema_method = $self->can("${api_name}_output_schema")) {
        push @dispatchers, sub () {
            response_filter {
                my $result = shift;
                my $schema = $self->rx->make_schema( $self->$output_schema_method );
                eval {
                    $schema->assert_valid( $result->data );
                };
                if ($@) {
                    my $data = {
                        error => 'Server error: bad response',
                        details => [ map $_->struct, @{ $@->failures } ],
                    };
                    return Open311::Endpoint::Result->new({
                        status => 500,
                        data => $data,
                    });
                }
                return $result;
            }
        };
    }

    push @dispatchers, sub () {
        my $data = $self->$api_method(@args);
        return Open311::Endpoint::Result->new({
            status => 200,
            data => $data,
        });
    };

    (@dispatchers);
}

sub GET_Service_List_input_schema {
    return {
        type => '//rec',
        optional => {
            # jurisdiction_id is documented as "Required", but with the note
            # 'This is only required if the endpoint serves multiple jurisdictions'
            # i.e. it is optional as regards the schema, but the server may choose 
            # to error if it is not provided.
            jurisdiction_id => {
                type => '//str',
            },
        }
    };
}

sub GET_Service_List_output_schema {
    return {
        type => '//rec',
        required => {
            services => {
                type => '//arr',
                contents => '/open311/service',
            },
        }
    };
}

sub GET_Service_List {
    my ($self, @args) = @_;

    my @services = map {
        my $service = $_;
        {
            keywords => (join ',' => @{ $service->keywords } ),
            metadata => $service->has_attributes ? 'true' : 'false',
            map { $_ => $service->$_ } 
                qw/ service_name service_code description type group /,
        }
    } $self->services;
    return {
        services => \@services,
    };
}

sub services {
    # this should be overridden in your subclass!
    [];
}
sub service {
    # this is a simple lookup on $self->services, and should 
    # *probably* be overridden in your subclass!
    my ($self, $service_code) = @_;

    return first { $_->service_code eq $service_code } $self->services;
}


my $json = JSON->new->pretty->allow_blessed->convert_blessed;
sub format_response {
    my ($self, $ext) = @_;
    response_filter {
        my $response = shift;
        return $response unless blessed $response;
        my $status = $response->status;
        my $data = $response->data;
        if ($ext eq 'json') {
            # Spark convention
            if (ref $data eq 'HASH' and scalar keys %$data == 1) {
                $data = $data->{ (keys %$data)[0] };
            }
            return [
                $status, 
                [ 'Content-Type' => 'application/json' ],
                [ $json->encode( $data )]
            ];
        }
        elsif ($ext eq 'xml') {
            my $xs = XML::Simple->new( 
                NoAttr=> 1, 
                KeepRoot => 1, 
                SuppressEmpty => 0,
                );

            # Spark convention transform: http://wiki.open311.org/JSON_and_XML_Conversion#The_Spark_Convention
            use Data::Visitor::Callback;
            my $visitor;
            $visitor = Data::Visitor::Callback->new(
                hash => sub {
                    my $hash = $_;
                    for my $k (keys %$hash) {
                        my $v = $hash->{$k};
                        if (ref $v eq 'ARRAY') {
                            (my $singular = $k)=~s/s$//;
                            $hash->{$k} = { $singular => $v };
                            $visitor->visit($v);
                        }
                    }
                }
            );
            $visitor->visit($data);
            return [
                $status,
                [ 'Content-Type' => 'text/xml' ],
                [ $xs->XMLout( $data) ],
            ];
        }
        elsif ($ext eq 'html') {
            # TODO, refactor with json above
            if (ref $data eq 'HASH' and scalar keys %$data == 1) {
                $data = $data->{ (keys %$data)[0] };
            }
            return [
                $status, 
                [ 'Content-Type' => 'text/plain' ],
                [ $json->encode( $data )]
            ];
        }
        else {
            return [
                404,
                [ 'Content-Type' => 'text/plain' ],
                [ 'Bad extension. We support .xml and .json' ],
            ] 
        }
    }
}

__PACKAGE__->run_if_script;
