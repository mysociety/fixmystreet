package Open311::Endpoint::Result;
use Moo;

has status => (
    is => 'ro',
);
has data => (
    is => 'ro',
);

1;
