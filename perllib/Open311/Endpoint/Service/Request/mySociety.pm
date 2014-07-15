package Open311::Endpoint::Service::Request::mySociety;
use Moo;
use MooX::HandlesVia;
extends 'Open311::Endpoint::Service::Request';

use DateTime;
use Open311::Endpoint::Service::Request::Update;
use Types::Standard ':all';

has updates => (
    is => 'rw',
    isa => ArrayRef[InstanceOf['Open311::Endpoint::Service::Request::Update']],
    default => sub { [] },
    handles_via => 'Array',
    handles => {
        _add_update => 'push',
        get_updates => 'elements',
        get_update  => 'get',
        has_updates => 'count',
        filter_updates => 'grep',
    }
);

sub add_update {
    my ($self, %args) = @_;
    my $update = Open311::Endpoint::Service::Request::Update->new(
        %args,
        service_request => $self,
        service_request_id => $self->service_request_id,
    );
    $self->_add_update($update);
}

sub last_update {
    my $self = shift;
    return $self->has_updates ? $self->get_update(-1) : undef;
}

around updated_datetime => sub {
    my ($orig, $self) = @_;
    my $last_update = $self->last_update or return;
    return $last_update->updated_datetime;
};

around status => sub {
    my ($orig, $self) = @_;
    my $last_update = $self->last_update or return 'open';
    return $last_update->status;
};

1;
