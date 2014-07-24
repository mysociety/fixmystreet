package Open311::Endpoint::Role::mySociety;

=head1 NAME

Open311::Endpoint::Role::mySociety - mySociety's proposed Open311 extensions

=head1 SYNOPSIS

See mySociety's 
L<blog post|https://www.mysociety.org/2013/02/20/open311-extended/>
and 
L<proposal|https://github.com/mysociety/FixMyStreet/wiki/Open311-FMS---Proposed-differences-to-Open311>
for a full explanation of the spec extension.

You can use the extensions as follows:

    package My::Open311::Endpoint;
    use Web::Simple;
    extends 'Open311::Endpoint';
    with 'Open311::Endpoint::Role::mySociety';

You will have to provide implementations of

    get_service_request_updates
    post_service_request_update

You will need to return L<Open311::Endpoint::Service::Request::Update>
objects.  However, the root L<Open311::Endpoint::Service::Request> is not
aware of updates, so you may may find it easier to ensure that the ::Service
objects you create (with get_service_request etc.) return
L<Open311::Endpoint::Service::Request::mySociety> objects.

=cut

use Moo::Role;
no warnings 'illegalproto';

use Open311::Endpoint::Service::Request::mySociety;
has '+request_class' => (
    is => 'ro',
    default => 'Open311::Endpoint::Service::Request::mySociety',
);

around dispatch_request => sub {
    my ($orig, $self, @args) = @_;
    my @dispatch = $self->$orig(@args);
    return (
        @dispatch,

        sub (GET + /servicerequestupdates + ?*) {
            my ($self, $args) = @_;
            $self->call_api( GET_Service_Request_Updates => $args );
        },

        sub (POST + /servicerequestupdates + ?*) {
            my ($self, $args) = @_;
            $self->call_api( POST_Service_Request_Update => $args );
        },

    );
};

sub GET_Service_Request_Updates_input_schema {
    my $self = shift;
    return {
        type => '//rec',
        required => {
            $self->get_jurisdiction_id_required_clause,
        },
        optional => {
            $self->get_jurisdiction_id_optional_clause,
            api_key => $self->get_identifier_type('api_key'),
            start_date => '/open311/datetime',
            end_date   => '/open311/datetime',
        }
    };
}

sub GET_Service_Request_Updates_output_schema {
    my $self = shift;
    return {
        type => '//rec',
        required => {
            service_request_updates => {
                type => '//arr',
                contents => '/open311/service_request_update',
            },
        },
    };
}

sub GET_Service_Request_Updates {
    my ($self, $args) = @_;

    my @updates = $self->get_service_request_updates({
        jurisdiction_id => $args->{jurisdiction_id},
        start_date => $args->{start_date},
        end_date => $args->{end_date},
    });

    $self->format_updates(@updates);
}

sub format_updates {
    my ($self, @updates) = @_;
    return {
        service_request_updates => [
            map {
                my $update = $_;
                +{
                    (
                        map {
                            $_ => $update->$_,
                        }
                        qw/
                            update_id
                            service_request_id
                            status
                            description
                            media_url
                            / 
                    ),
                    (
                        map {
                            $_ => $self->w3_dt->format_datetime( $update->$_ ), 
                        }
                        qw/
                            updated_datetime
                        /
                    ),
                }
            } @updates
        ]
    };
}

sub get_service_request_updates {
    my ($self, $args) = @_;
    die "abstract method get_service_request_updates not overridden";
}

sub learn_additional_types {
    my ($self, $schema) = @_;
    $schema->learn_type( 'tag:wiki.open311.org,GeoReport_v2:rx/service_request_update',
        {
            type => '//rec',
            required => {
                service_request_id => $self->get_identifier_type('service_request_id'),
                update_id => $self->get_identifier_type('update_id'),
                status => '/open311/status',
                updated_datetime => '/open311/datetime',
                description => '//str',
                media_url => '//str',
            },
        }
    );
}

1;
