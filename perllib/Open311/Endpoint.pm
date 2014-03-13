package Open311::Endpoint;

use Web::Simple;

use JSON;
use XML::Simple;
use Data::Rx;

use Open311::Endpoint::Result;
use Open311::Endpoint::Service;
use Open311::Endpoint::Spark;

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

    sub (GET + /services/* + ?*) {
        my ($self, $service_id, $args) = @_;
        $self->call_api( GET_Service_Definition => $service_id, $args );
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

has spark => (
    is => 'lazy',
    default => sub {
        Open311::Endpoint::Spark->new();
    },
);

has rx => (
    is => 'lazy',
    default => sub {
        my $schema = Data::Rx->new({
            prefix => {
                open311 => 'tag:wiki.open311.org,GeoReport_v2:rx/',
            }
        });

        # TODO, turn these into proper type_plugin
        
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/input_jurisdiction',
            # jurisdiction_id is documented as "Required", but with the note
            # 'This is only required if the endpoint serves multiple jurisdictions'
            # i.e. it is optional as regards the schema, but the server may choose 
            # to error if it is not provided.
            {
                type => '//rec',
                optional => {
                    jurisdiction_id => '//str',
                },
            }
        );

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
                    type => '//str', # actually //any of (realtime, batch, blackbox)
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
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/value',
            {
                type => '//rec',
                required => {
                    key => '//str',
                    name => '//str',
                }
            }
        );
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/values_list',
            {
                type => '//arr',
                contents => '/open311/value',
            },
        );
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/attribute',
            {
                type => '//rec',
                required => {
                    code => '//str',
                    datatype => '//str', # actually Enum[qw/ string number datetime text singlevaluelist multivaluelist /],
                    datatype_description => '//str',
                    description => '//str',
                    order => '//int',
                    required => '/open311/bool',
                    variable => '/open311/bool',
                },
                optional => {
                    values => '/open311/values_list',
                },
            }
        );
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/attribute_list',
            {
                type => '//arr',
                contents => '/open311/attribute',
            }
        );
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/service_definition',
            {
                type => '//rec',
                required => {
                    service_code => '//str',
                    attributes => '/open311/attribute_list',
                },
            }
        );
        return $schema;
    },
);

sub GET_Service_List_input_schema {
    return {
        type => '/open311/input_jurisdiction',
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

sub GET_Service_Definition_input_schema {
    return {
        type => '//seq',
        contents => [
            '//str', # service_code
            '/open311/input_jurisdiction',
        ],
    };
}

sub GET_Service_Definition_output_schema {
    return {
        type => '//rec',
        required => {
            service_definition => {
                type => '/open311/service_definition',
            },
        }
    };
}

sub GET_Service_Definition {
    my ($self, $service_id, $args) = @_;

    my $service = $self->service($service_id, $args) or return;
    my $order = 0;
    my $service_definition = {
        service_definition => {
            service_code => $service_id,
            attributes => [
                map {
                    my $attribute = $_;
                    {
                        order => ++$order,
                        variable => $attribute->variable ? 'true' : 'false',
                        required => $attribute->required ? 'true' : 'false',
                        $attribute->has_values ? (
                            values => [
                                map { 
                                    my ($key, $name) = @$_;
                                    +{ 
                                        key => $key, 
                                        name => $name,
                                    }
                                } $attribute->values_kv
                            ]) : (),
                        map { $_ => $attribute->$_ } 
                            qw/ code datatype datatype_description description /,
                    }
                } $service->get_attributes,
            ],
        },
    };
    return $service_definition;
}

sub services {
    # this should be overridden in your subclass!
    [];
}
sub service {
    # this is a simple lookup on $self->services, and should 
    # *probably* be overridden in your subclass!
    # (for example, to look up in App DB, with $args->{jurisdiction_id})

    my ($self, $service_code, $args) = @_;

    return first { $_->service_code eq $service_code } $self->services;
}

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
        if ($data) {
            return Open311::Endpoint::Result->new({
                status => 200,
                data => $data,
            });
        }
        else {
            return Open311::Endpoint::Result->new({
                status => 404,
                data => {
                    error => 'Resource not found',
                }
            });
        }
    };

    (@dispatchers);
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
            return [
                $status, 
                [ 'Content-Type' => 'application/json' ],
                [ $json->encode( $self->spark->process_for_json( $data ) )]
            ];
        }
        elsif ($ext eq 'xml') {
            my $xs = XML::Simple->new( 
                NoAttr=> 1, 
                KeepRoot => 1, 
                SuppressEmpty => 0,
                );

            return [
                $status,
                [ 'Content-Type' => 'text/xml' ],
                [ 
                    qq(<?xml version="1.0" encoding="utf-8"?>\n),
                    $xs->XMLout( $self->spark->process_for_xml( $data )),
                ],
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
