package Open311::Endpoint::Service::Attribute;
use Moo;
use MooX::HandlesVia;
use Types::Standard ':all';
use namespace::clean;

# from http://wiki.open311.org/GeoReport_v2#GET_Service_Definition

# A unique identifier for the attribute
has code => (
    is => 'ro',
    isa => Str,
);

# true denotes that user input is needed
# false means the attribute is only used to present information to the user within the description field
#
# NB: unsure what false means for the rest of the options here, e.g. should remainder of fields by Maybe[] ?
has variable => (
    is => 'ro',
    isa => Bool,
    default => sub { 1 }, 
);

# Denotes the type of field used for user input.
has datatype => (
    is => 'ro',
    isa => Enum[qw/ string number datetime text singlevaluelist multivaluelist /],
);

has required => (
    is => 'ro',
    isa => Bool,
);

# A description of the datatype which helps the user provide their input
has datatype_description => (
    is => 'ro',
    isa => Str,
);

# A description of the attribute field with instructions for the user to find
# and identify the requested information   
has description => (
    is => 'ro',
    isa => Str,
);

# NB: we don't model the "Order" field here, as that's really for the Service
# object to return

# only relevant for singlevaluelist or multivaluelist
has values => (
    is => 'ro',
    isa => HashRef,
    default => sub { {} },
    handles_via => 'Hash',
    handles => {
        get_value => 'get',
        has_values => 'count',
        values_kv => 'kv',
    }
);

1;
