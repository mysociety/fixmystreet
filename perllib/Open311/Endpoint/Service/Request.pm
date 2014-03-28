package Open311::Endpoint::Service::Request;
use Moo;
use Types::Standard ':all';
use namespace::clean;

has service => (
    is => 'ro',
    isa => InstanceOf['Open311::Endpoint::Service'],
    handles => [
        qw/ service_code service_name /
    ],
);

has service_request_id => (
    is => 'ro',
    isa => Maybe[Str],
    predicate => 1,
);

has token => (
    is => 'ro',
    isa => Maybe[Str],
    predicate => 1,
);

has service_notice => (
    is => 'ro',
    isa => Maybe[Str],
    predicate => 1,
);

has account_id => (
    is => 'ro',
    isa => Maybe[Str],
    predicate => 1,
);

has status => (
    is => 'rw',
    isa => Enum[qw/ open closed /],
    default => sub { 'open' },
);

has description => (
    is => 'ro',
    isa => Maybe[Str],
);

has agency_responsible => (
    is => 'ro',
    isa => Maybe[Str],
);

has requested_datetime => (
    is => 'ro',
    isa => Maybe[ InstanceOf['DateTime'] ],
);

has updated_datetime => (
    is => 'ro',
    isa => Maybe[ InstanceOf['DateTime'] ],
);

has expected_datetime => (
    is => 'ro',
    isa => Maybe[ InstanceOf['DateTime'] ],
);

has address => (
    is => 'ro',
    isa => Str,
    default => sub { '' },
);

has address_id => (
    is => 'ro',
    isa => Str,
    default => sub { '' },
);

has zipcode => (
    is => 'ro',
    isa => Str,
    default => sub { '' },
);

has latlong => (
    is => 'ro',
    isa => Tuple[ Num, Num ],
    default => sub { [0,0] },
    handles_via => 'Array',
    handles => {
        #lat => [ get => 0 ],
        #lon => [ get => 1 ],
    }
);

sub lat { shift->latlong->[0] }
sub lon { shift->latlong->[1] }

has media_url => (
    is => 'ro',
    isa => Str,
    default => sub { '' },
);

1;
