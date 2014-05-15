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

=cut

use Moo::Role;
no warnings 'illegalproto';

around dispatch_request => sub {
    my ($orig, $self, @args) = @_;
    my @dispatch = $self->$orig(@args);
    return (
        @dispatch,

        sub (GET + /servicerequestupdates + ?*) {
            my ($self, $args) = @_;
            $self->call_api( GET_Service_Request_Updates => $args );
        },

    );
};

sub GET_Service_Request_Updates_input_schema {
    my $self = shift;
    # NB: we can't just return $self->GET_Service_Requests_input_schema(@_);
    # as the propsed extension doesn't accept service_code, service_request_id, or status
    return {
        type => '//rec',
        required => {
            $self->get_jurisdiction_id_required_clause,
        },
        optional => {
            $self->get_jurisdiction_id_optional_clause,,
            start_date => '/open311/datetime',
            end_date   => '/open311/datetime',
        }
    };
}

sub GET_Service_Request_Updates_output_schema {
    my $self = shift;
    return $self->GET_Service_Requests_output_schema(@_);
}

sub GET_Service_Request_Updates {
    my ($self, $args) = @_;

    my @service_requests = $self->get_service_request_updates({
        jurisdiction_id => $args->{jurisdiction_id},
        start_date => $args->{start_date},
        end_date => $args->{end_date},
    });

    $self->format_service_requests(@service_requests);
}

sub get_service_request_updates {
    my ($self, $args) = @_;
    die "abstract method get_service_request_updates not overridden";
}

1;
