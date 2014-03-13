package Open311::Endpoint::Service;
use Moo;
use MooX::HandlesVia;
use Types::Standard ':all';
use namespace::clean;

has service_name => (
    is => 'ro',
    isa => Str,
);

has service_code => (
    is => 'ro',
    isa => Str,
);

has description => (
    is => 'ro',
    isa => Str,
);

has keywords => (
    is => 'ro',
    isa => ArrayRef[Str],
);

has group => (
    is => 'ro',
    isa => Str,
);

has type => (
    is => 'ro',
    isa => Enum[qw/ realtime batch blackbox /],
);

has attributes => (
    is => 'ro',
    isa => HashRef[ InstanceOf['Open311::Endpoint::Service::Attribute'] ],
    handles_via => 'Hash',
    handles => {
        get_attribute => 'get',
        has_attributes => 'count',
    }
);

1;
