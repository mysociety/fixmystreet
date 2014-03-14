package t::open311::endpoint::ServiceType1;
use Moo;
extends 'Open311::Endpoint::Service';
use DateTime;
use Types::Standard ':all';
use MooX::HandlesVia;

use Open311::Endpoint::Service::Request;

has '+default_service_notice' => (
    default => 'This is a test service',
);

# FOR TESTING, we'll just maintain requests in a *global* array...
# obviously a real Service driver will use a DB or API call!
{
    our @SERVICE_REQUESTS;
    has _requests => (
        is => 'ro',
        isa => ArrayRef[ InstanceOf[ 'Open311::Endpoint::Service::Request' ] ],
        default => sub { \@SERVICE_REQUESTS },
        handles_via => 'Array',
        handles => {
            next_request_id => 'count',
            _add_request => 'push',
            get_request => 'get',
        }
    );
}

sub submit_request {
    my ($self, $args) = @_;

    my $request = Open311::Endpoint::Service::Request->new(

        # NB: possible race condition between next_request_id and _add_request
        # (this is fine for synchronous test-cases)
        
        service_request_id => $self->next_request_id, 
        status => 'open',
        description => $args->{description},
        agency_responsible => '',
        requested_datetime => DateTime->now(),
        update_datetime => DateTime->now(),
        address => $args->{address_string},
        address_id => $args->{address_id},
        # NB: other info is passed in that would be stored by an Open311
        # endpoint, see Open311::Endpoint::Service::Request for full list,
        # but we don't need to handle all of those in this test
    );
    $self->_add_request( $request );

    return ( $request );
}

1;
