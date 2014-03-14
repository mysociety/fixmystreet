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

# + all the rest

1;
