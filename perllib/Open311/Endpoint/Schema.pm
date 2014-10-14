package Open311::Endpoint::Schema;
use Moo;
use Data::Rx;

use Open311::Endpoint::Schema::Comma;
use Open311::Endpoint::Schema::Regex;

use Carp 'confess';
has endpoint => (
    is => 'ro',
    handles => [qw/
        get_jurisdiction_id_required_clause
        get_jurisdiction_id_optional_clause
        get_identifier_type
        learn_additional_types
    /],
);

sub enum {
    my ($self, $type, @values) = @_;
    return {
        type => '//any',
        of => [ map {
            {
                type => $type,
                value => $_,
            }
        } @values ],
    };
}

sub format_boolean {
    my ($self, $value) = @_;
    return $value ? 'true' : 'false';
}

has schema => (
    is => 'lazy',
    default => sub {
        my $self = shift;

        my $schema = Data::Rx->new({
            sort_keys => 1,
            prefix => {
                open311 => 'tag:wiki.open311.org,GeoReport_v2:rx/',
            },
            type_plugins => [qw(
                Open311::Endpoint::Schema::Comma
                Open311::Endpoint::Schema::Regex
            )],
        });

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/bool',
            $self->enum( '//str', qw[ true false ] ));

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/datetime',
            {
                type => '/open311/regex',
                pattern => qr{
                    ^
                    \d{4} - \d{2} - \d{2} # yyyy-mm-dd
                    T
                    \d{2} : \d{2} : \d{2} # hh:mm:ss
                   (?:
                        Z                  # "Zulu" time, e.g. UTC
                    |   [+-] \d{2} : \d{2} # +/- hh:mm offset
                   )
                   $
                }ax, # use ascii semantics so /d means [0-9], and allow formatting
                message => "found value isn't a datetime",
            });

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/example/identifier',
            {
                type => '/open311/regex',
                pattern => qr{^ \w+ $}ax,
                message => "found value isn't a valid identifier",
            });

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/status',
            $self->enum( '//str', qw[ open closed ] ));

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/post_type',
            $self->enum( '//str', qw[ realtime batch blackbox ] ));

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/service',
            {
                type => '//rec',
                required => {
                    service_name => '//str',
                    type => '/open311/post_type',
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

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/attribute',
            {
                type => '//rec',
                required => {
                    code => '//str',
                    datatype => $self->enum( '//str', qw[ string number datetime text singlevaluelist multivaluelist ] ),
                    datatype_description => '//str',
                    description => '//str',
                    order => '//int',
                    required => '/open311/bool',
                    variable => '/open311/bool',
                },
                optional => {
                    values => {
                        type => '//arr',
                        contents => '/open311/value',
                    },
                },
            }
        );

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/service_definition',
            {
                type => '//rec',
                required => {
                    service_code => '//str',
                    attributes => {
                        type => '//arr',
                        contents => '/open311/attribute',
                    }
                },
            }
        );
        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/service_request',
            {
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
                    long => '//num',
                    media_url => '//str',
                },
                optional => {
                    request => '//str',
                    description => '//str',
                    agency_responsible => '//str',
                    service_notice => '//str',
                },
            }
        );

        $self->learn_additional_types($schema);

        return $schema;
    },
);

1;
