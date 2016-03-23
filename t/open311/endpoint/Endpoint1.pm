package t::open311::endpoint::Endpoint1;
use Web::Simple;
extends 'Open311::Endpoint';
use Types::Standard ':all';
use MooX::HandlesVia;

use Open311::Endpoint::Service;
use t::open311::endpoint::ServiceType1;
use Open311::Endpoint::Service::Attribute;
use Open311::Endpoint::Service::Request;

sub services {
    return (
        t::open311::endpoint::ServiceType1->new(
            service_code => 'POT',
            service_name => 'Pothole Repairs',
            description => 'Pothole Repairs Service',
            attributes => [
                Open311::Endpoint::Service::Attribute->new(
                    code => 'depth',
                    required => 1,
                    datatype => 'number',
                    datatype_description => 'an integer',
                    description => 'depth of pothole, in centimetres',
                ),
                Open311::Endpoint::Service::Attribute->new(
                    code => 'shape',
                    required => 0,
                    datatype => 'singlevaluelist',
                    datatype_description => 'square | circle | triangle',
                    description => 'shape of the pothole',
                    values => {
                        square => 'Square',
                        circle => 'Circle',
                        triangle => 'Triangle',
                    },
                ),
            ],
            type => 'realtime',
            keywords => [qw/ deep hole wow/],
            group => 'highways',
        ),
        t::open311::endpoint::ServiceType1->new(
            service_code => 'BIN',
            service_name => 'Bin Enforcement',
            description => 'Bin Enforcement Service',
            attributes => [],
            type => 'realtime',
            keywords => [qw/ bin /],
            group => 'sanitation',
        )
    );
}

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
            get_requests => 'elements',
            filter_requests => 'grep',
        }
    );
}

sub post_service_request {
    my ($self, $service, $args) = @_;

    my $request = $self->new_request(

        # NB: possible race condition between next_request_id and _add_request
        # (this is fine for synchronous test-cases)
        
        service => $service,
        service_request_id => $self->next_request_id, 
        status => 'open',
        description => $args->{description},
        agency_responsible => '',
        requested_datetime => DateTime->now(),
        updated_datetime => DateTime->now(),
        address => $args->{address_string} // '',
        address_id => $args->{address_id} // '',
        media_url => $args->{media_url} // '',
        zipcode => $args->{zipcode} // '',
        # NB: other info is passed in that would be stored by an Open311
        # endpoint, see Open311::Endpoint::Service::Request for full list,
        # but we don't need to handle all of those in this test
    );
    $self->_add_request( $request );

    return ( $request );
}

sub get_service_requests {
    my ($self, $args) = @_;

    my $service_code = $args->{service_code} or return $self->get_requests;
    return $self->filter_requests( sub { my $c = shift->service->service_code; grep { $_ eq $c } @$service_code });
}

sub get_service_request {
    my ($self, $service_request_id, $args) = @_;
    return $self->get_request( $service_request_id );
}

1;
