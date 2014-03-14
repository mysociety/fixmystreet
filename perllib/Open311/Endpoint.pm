package Open311::Endpoint;

use Web::Simple;

use JSON;
use XML::Simple;

use Open311::Endpoint::Result;
use Open311::Endpoint::Service;
use Open311::Endpoint::Service::Request;
use Open311::Endpoint::Spark;
use Open311::Endpoint::Schema;

use Data::Dumper;
use Scalar::Util 'blessed';
use List::Util 'first';
use Types::Standard ':all';

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

    sub (POST + /requests + %*) {
        my ($self, $args) = @_;
        $self->call_api( POST_Service_Request => $args );
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

has default_service_notice => (
    is => 'ro',
    isa => Maybe[Str],
    predicate => 1,
);

has spark => (
    is => 'lazy',
    default => sub {
        Open311::Endpoint::Spark->new();
    },
);

has schema => (
    is => 'lazy',
    default => sub {
        Open311::Endpoint::Schema->new,
    },
    handles => {
        rx => 'schema',
        format_boolean => 'format_boolean',
    },
);

sub GET_Service_List_input_schema {
    return {
        type => '//rec',
        # jurisdiction_id is documented as "Required", but with the note
        # 'This is only required if the endpoint serves multiple jurisdictions'
        # i.e. it is optional as regards the schema, but the server may choose 
        # to error if it is not provided.
        optional => {
            jurisdiction_id => '//str',
        },
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
            metadata => $self->format_boolean( $service->has_attributes ),
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
            {
                type => '//rec',
                optional => {
                    jurisdiction_id => '//str',
                }
            },
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
                        variable => $self->format_boolean( $attribute->variable ),
                        required => $self->format_boolean( $attribute->required ),
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

sub POST_Service_Request_input_schema {
    my ($self, $args) = @_;

    my $service_code = $args->{service_code};
    unless ($service_code && $args->{api_key}) {
        # return a simple validator
        # to give a nice error message
        return {
            type => '//rec',
            required => { service_code => '//str', api_key => '//str' },
            rest => '//any',
        };
    }

    my $service = $self->service($service_code)
        or return; # we can't fetch service, so signal error TODO

    my %attributes;
    for my $attribute ($service->get_attributes) {
        my $section = $attribute->required ? 'required' : 'optional';
        my $key = sprintf 'attribute[%s]', $attribute->code;
        my $def = $attribute->schema_definition;

        $attributes{ $section }{ $key } = $def;
    }

    # we have to supply at least one of these, but can supply more
    my @address_options = (
        { lat => '//num', lon => '//num' },
        { address_string => '//str' },
        { address_id => '//str' },
    );

    my @address_schemas;
    while (my $address_required = shift @address_options) {
        push @address_schemas,
        {
            type => '//rec',
            required => {
                service_code => '//str',
                api_key => '//str',
                %{ $attributes{required} },
                %{ $address_required },
            },
            optional => {
                jurisdiction_id => '//str',
                email => '//str',
                device_id => '//str',
                account_id => '//str',
                first_name => '//str',
                last_name => '//str',
                phone => '//str',
                description => '//str',
                media_url => '//str',
                %{ $attributes{optional} },
                map %$_, @address_options,
            },
        };
    }

    return { 
            type => '//any',
            of => \@address_schemas,
        };
}

sub POST_Service_Request_output_schema {
    my ($self, $args) = @_;

    my $service_code = $args->{service_code};
    my $service = $self->service($service_code);

    my %return_schema = (
        ($service->type eq 'realtime') ? ( service_request_id => '//str' ) : (),
        ($service->type eq 'batch')    ? ( token => '//str' ) : (),
    );

    return {
        type => '//rec',
        required => {
            service_requests => {
                type => '//arr',
                contents => {
                    type => '//rec',
                    required => {
                        %return_schema,
                    },
                    optional => {
                        service_notice => '//str',
                        account_id => '//str',

                    },
                },
            },
        },
    };
}

sub POST_Service_Request {
    my ($self, $args) = @_;

    # TODO: pass this through from earlier stages
    my $service_code = $args->{service_code};
    my $service = $self->service($service_code);

    my @service_requests = $service->submit_request( $args );
        
    return {
        service_requests => [
            map {
                my $service_notice = 
                    $_->service_notice 
                    || $service->default_service_notice
                    || $self->default_service_notice;
                {
                    ($service->type eq 'realtime') ? ( service_request_id => $_->service_request_id ) : (),
                    ($service->type eq 'batch')    ? ( token => $_->token ) : (),
                    $service_notice ? ( service_notice => $service_notice ) : (),
                    $_->has_account_id ? ( account_id => $_->account_id ) : (),
                }
            } @service_requests,
        ],
    };
}

sub services {
    # this should be overridden in your subclass!
    [];
}
sub service {
    # this stub implementation is a simple lookup on $self->services, and
    # should *probably* be overridden in your subclass!
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
            my $input_schema = $self->$input_schema_method(@args)
                or return Open311::Endpoint::Result->new({
                    status => 400,
                    data => { error => 'Bad request' }, # TODO: better error reporting
                });

            my $schema = $self->rx->make_schema( $input_schema );
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
                my $schema = $self->rx->make_schema( $self->$output_schema_method(@args) );
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
