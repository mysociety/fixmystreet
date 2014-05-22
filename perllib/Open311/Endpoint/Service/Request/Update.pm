package Open311::Endpoint::Service::Request::Update;
use Moo;
use Types::Standard ':all';
use namespace::clean;

sub BUILDARGS {
    my ($class, %args) = @_;
    my $service_request = delete $args{service_request};

    if (! $args{status}) {
        $args{status} = $service_request->status;
    }

    return \%args;
}

has update_id => (
    is => 'ro',
    isa => Maybe[Str],
    predicate => 1,
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

has status => (
    is => 'ro',
    isa => Enum[qw/ open closed /],
);

has description => (
    is => 'ro',
    isa => Maybe[Str],
);

has media_url => (
    is => 'ro',
    isa => Str,
    default => sub { '' },
);

has updated_datetime => (
    is => 'ro',
    isa => InstanceOf['DateTime'],
    default => sub { DateTime->now() },
);

1;
