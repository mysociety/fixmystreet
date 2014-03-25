package Open311::Endpoint;

use Web::Simple;

use JSON;
use XML::Simple;

use Open311::Endpoint::Result;
use Open311::Endpoint::Service;
use Open311::Endpoint::Service::Request;
use Open311::Endpoint::Spark;
use Open311::Endpoint::Schema;

use MooX::HandlesVia;

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
        return Open311::Endpoint::Result->error( 400, 'not implemented' );
    },

    sub (GET + /requests + ?*) {
        my ($self, $args) = @_;
        $self->call_api( GET_Service_Requests => $args );
    },

    sub (GET + /requests/*) {
        return Open311::Endpoint::Result->error( 400, 'not implemented' );
    },
}

=head1 Configurable arguments

    * default_service_notice - default for <service_notice> if not
        set by the service or an individual request
    * jurisdictions - an array of jurisdiction_ids
        you may want to subclass the methods:
            - requires_jurisdiction_ids
            - check_jurisdiction_id 
    * default_identifier_type
        Open311 doesn't mandate what these types look like, but a backend
        server may! The module provides an example identifier type which allows
        ascii "word" characters .e.g [a-zA-Z0-9_] as an example default.
        You can also override these individually using:

        identifier_types => {
            api_key => '//str', # 
            jurisdiction_id => ...
            service_code => ...
            service_request_id  => ...
            # etc.
        }

=cut

has default_identifier_type => (
    is => 'ro',
    isa => Str,
    default => '/open311/example/identifier',
);

has identifier_types => (
    is => 'ro',
    isa => HashRef[Str],
    default => sub { {} },
    handles_via => 'Hash',
    handles => {
        get_identifier_type => 'get',
    },
);

around get_identifier_type => sub {
    my ($orig, $self, $type) = @_;
    return $self->$orig($type) // $self->default_identifier_type;
};

has default_service_notice => (
    is => 'ro',
    isa => Maybe[Str],
    predicate => 1,
);

has jurisdiction_ids => (
    is => 'ro',
    isa => Maybe[ArrayRef],
    default => sub { [] },
    handles_via => 'Array',
    handles => {
        has_jurisdiction_ids => 'count',
        get_jurisdiction_ids => 'elements',
    }
);

=head1 Other accessors

You might additionally wish to replace the following objects.

    * schema - Data::Rx schema for validating Open311 protocol inputs and
               outputs
    * spark  - methods for munging base data-structure for output
    * json   - JSON output object
    * xml    - XML::Simple output object

=cut

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

has spark => (
    is => 'lazy',
    default => sub {
        Open311::Endpoint::Spark->new();
    },
);

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

has xml => (
    is => 'lazy',
    default => sub {
        XML::Simple->new( 
            NoAttr=> 1, 
            KeepRoot => 1, 
            SuppressEmpty => 0,
        );
    },
);

sub GET_Service_List_input_schema {
    return shift->get_jurisdiction_id_validation;
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
    my $self = shift;
    return {
        type => '//seq',
        contents => [
            $self->get_identifier_type('service_code'),
            $self->get_jurisdiction_id_validation,
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
            required => { 
                service_code => $self->get_identifier_type('service_code'), 
                api_key => $self->get_identifier_type('api_key') },
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
                service_code => $self->get_identifier_type('service_code'),
                api_key => $self->get_identifier_type('api_key'),
                %{ $attributes{required} },
                %{ $address_required },
                $self->get_jurisdiction_id_required_clause,
            },
            optional => {
                email => '//str',
                device_id => '//str',
                account_id => '//str',
                first_name => '//str',
                last_name => '//str',
                phone => '//str',
                description => '//str',
                media_url => '//str',
                %{ $attributes{optional} },
                (map %$_, @address_options),
                $self->get_jurisdiction_id_optional_clause,
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
        ($service->type eq 'realtime') ? ( service_request_id => $self->get_identifier_type('service_request_id') ) : (),
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

    # TODO pass this through instead of calculating again?
    my $service_code = $args->{service_code};
    my $service = $self->service($service_code);

    my @service_requests = $self->post_service_request( $service, $args );
        
    return {
        service_requests => [
            map {
                my $service_notice = 
                    $_->service_notice 
                    || $service->default_service_notice
                    || $self->default_service_notice;
                +{
                    ($service->type eq 'realtime') ? ( service_request_id => $_->service_request_id ) : (),
                    ($service->type eq 'batch')    ? ( token => $_->token ) : (),
                    $service_notice ? ( service_notice => $service_notice ) : (),
                    $_->has_account_id ? ( account_id => $_->account_id ) : (),
                }
            } @service_requests,
        ],
    };
}

sub post_service_request {
    # we assume that the posting of the request is handled by the Service
    # object.  You may wish instead to override this method if this assumption
    # doesn't hold.

    my ($self, $service, $args) = @_;

    my @service_requests = $service->submit_request( $args );
    return @service_requests;
}

sub GET_Service_Requests_input_schema {
    my $self = shift;
    return {
        type => '//rec',
        required => {
            $self->get_jurisdiction_id_required_clause,
        },
        optional => {
            $self->get_jurisdiction_id_optional_clause,,
            service_request_id => {
                type => '/open311/comma',
                contents => $self->get_identifier_type('service_request_id'),
            },
            service_code => {
                type => '/open311/comma',
                contents => $self->get_identifier_type('service_code'),
            },
            start_date => '/open311/datetime',
            end_date   => '/open311/datetime',
            status => {
                type => '/open311/comma',
                contents => '/open311/status',
            },
        },
    };
}

sub GET_Service_Requests_output_schema {
    my $self = shift;
    return {
        type => '//rec',
        service_requests => {
            type => '//arr',
            of => {
                type => '//rec',
                required => {
                    service_request_id => $self->get_identifier_type('service_request_id'),
                    status => '/open311/status',
                    service_name => '//str',
                    service_code => $self->get_identifier_type('service_code'),
                    requested_datetime => '/open311/datetime',
                    updated_datetime => '/open311/datetime',
                    address => '//str',
                    address_id => '//str',
                    zipcode => '//str',
                    lat => '//num',
                    lon => '//num',
                    media_url => '//str',
                },
                optional => {
                    request => '//str',
                    description => '//str',
                    agency_responsible => '//str',
                    service_notice => '//str',
                },
            }
        },
    };
}

sub GET_Service_Requests {
    my ($self, $args) = @_;
    
    my @service_requests = $self->get_service_requests({

        jurisdiction_id => $args->{jurisdiction_id},
        start_date => $args->{start_date},
        end_date => $args->{end_date},

        map {
            $args->{$_} ?
                ( $_ => [ split ',' => $args->{$_} ] )
              : ()
        } qw/ service_request_id service_code status /,
    });

    return {
        service_requests => [
            map {
                my $request = $_;
                +{
                    (
                        map {
                            $_ => $request->$_,
                        }
                        qw/
                            service_request_id
                            status
                            service_name
                            service_code
                            requested_datetime
                            updated_datetime
                            address
                            address_id
                            zipcode
                            lat
                            lon
                            media_url
                            / 
                    ),
                    (
                        map {
                            my $value = $request->$_;
                            $value ? ( $_ => $value ) : (),
                        }
                        qw/
                            request
                            description
                            agency_responsible
                            service_notice
                            /
                    ),
                }
            } @service_requests,
        ],
    };
}

sub get_service_requests {
    # we assume that each service handles getting requests, and we collate them
    # here.
    # if the endpoint handles all services globally, then you may wish to
    # override this.

    my ($self, $args) = @_;

    my @service_code = $args->{service_code} ?
        @{$args->{service_code}}
      : $self->services;

    my @services = map { $self->service($_) } @service_code;

    return map {
        $_->get_service_requests( $args );
    } @service_code;
}

sub services {
    # this should be overridden in your subclass!
    ();
}
sub service {
    # this stub implementation is a simple lookup on $self->services, and
    # should *probably* be overridden in your subclass!
    # (for example, to look up in App DB, with $args->{jurisdiction_id})

    my ($self, $service_code, $args) = @_;

    return first { $_->service_code eq $service_code } $self->services;
}

sub has_multiple_jurisdiction_ids {
    return shift->has_jurisdiction_ids > 1;
}

sub requires_jurisdiction_ids {
    # you may wish to subclass this
    return shift->has_multiple_jurisdiction_ids;
}

sub check_jurisdiction_id {
    my ($self, $jurisdiction_id) = @_;

    # you may wish to override this stub implementation which:
    #   - always succeeds if no jurisdiction_id is set
    #   - accepts no jurisdiction_id if there is only one set
    #   - otherwise checks that the id passed is one of those set
    #
    return 1 unless $self->has_jurisdiction_ids;

    if (! defined $jurisdiction_id) {
        return $self->requires_jurisdiction_ids ? 1 : undef;
    }

    return first { $jurisdiction_id eq $_ } $self->get_jurisdiction_ids;
}

sub get_jurisdiction_id_validation {
    my $self = shift;

    # jurisdiction_id is documented as "Required", but with the note
    # 'This is only required if the endpoint serves multiple jurisdictions'
    # i.e. it is optional as regards the schema, but the server may choose 
    # to error if it is not provided.
    return {
        type => '//rec',
        ($self->requires_jurisdiction_ids ? 'required' : 'optional') => { 
            jurisdiction_id => $self->get_identifier_type('jurisdiction_id'),
        },
    };
}

sub get_jurisdiction_id_required_clause {
    my $self = shift;
    $self->requires_jurisdiction_ids ? (jurisdiction_id => $self->get_identifier_type('jurisdiction_id')) : ();
}

sub get_jurisdiction_id_optional_clause {
    my $self = shift;
    $self->requires_jurisdiction_ids ? () : (jurisdiction_id => $self->get_identifier_type('jurisdiction_id'));
}

sub call_api {
    my ($self, $api_name, @args) = @_;
    
    my $api_method = $self->can($api_name)
        or die "No such API $api_name!";

    my @dispatchers;

    if (my $input_schema_method = $self->can("${api_name}_input_schema")) {
        push @dispatchers, sub () {
            my $input_schema = $self->$input_schema_method(@args)
                or return Open311::Endpoint::Result->error( 400,
                    'Bad request' );

            my $schema = $self->rx->make_schema( $input_schema );
            my $input = (scalar @args == 1) ? $args[0] : [@args];
            eval {
                $schema->assert_valid( $input );
            };
            if ($@) {
                return Open311::Endpoint::Result->error( 400,
                    map $_->struct, @{ $@->failures }, # bit cheeky, spec suggests it wants strings only
                );
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
                    return Open311::Endpoint::Result->error( 500,
                        $data,
                    );
                }
                return $result;
            }
        };
    }

    push @dispatchers, sub () {
        my $data = $self->$api_method(@args);
        if ($data) {
            return Open311::Endpoint::Result->success( $data );
        }
        else {
            return Open311::Endpoint::Result->error( 404 =>
                    'Resource not found' );
        }
    };

    (@dispatchers);
}

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
                [ $self->json->encode( 
                    $self->spark->process_for_json( $data ) 
                )]
            ];
        }
        elsif ($ext eq 'xml') {
            return [
                $status,
                [ 'Content-Type' => 'text/xml' ],
                [ qq(<?xml version="1.0" encoding="utf-8"?>\n),
                  $self->xml->XMLout( 
                    $self->spark->process_for_xml( $data )
                )],
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
