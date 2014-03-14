package Open311::Endpoint::Service::Request;
use Moo;
use Types::Standard ':all';
use namespace::clean;

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
    isa => Maybe[Str],
);

has address_id => (
    is => 'ro',
    isa => Maybe[Str],
);

has zipcode => (
    is => 'ro',
    isa => Maybe[Str],
);

has latlong => (
    is => 'ro',
    isa => Maybe[Tuple[ Num, Num ]],
);

has media_url => (
    is => 'ro',
    isa => Maybe[Str],
);

1;
