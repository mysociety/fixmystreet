package Open311::Endpoint::Schema;
use Moo;
use Data::Rx;

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
            }
        });

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/bool',
            $self->enum( '//str', qw[ true false ] ));

        $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/service',
            {
                type => '//rec',
                required => {
                    service_name => '//str',
                    type => $self->enum( '//str', qw[ realtime batch blackbox ] ),
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
        return $schema;
    },
);

1;
