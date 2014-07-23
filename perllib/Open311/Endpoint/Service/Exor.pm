package Open311::Endpoint::Service::Exor;
use Moo;
extends 'Open311::Endpoint::Service';
use Open311::Endpoint::Service::Attribute;

has '+attributes' => (
    is => 'ro',
    default => sub { [
        Open311::Endpoint::Service::Attribute->new(
            code => 'easting',
            variable => 0, # set by server
            datatype => 'number',
            required => 1,
            datatype_description => 'a number',
            description => 'easting',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'northing',
            variable => 0, # set by server
            datatype => 'number',
            required => 1,
            datatype_description => 'a number',
            description => 'northing',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'closest_address',
            variable => 0, # set by server
            datatype => 'string',
            required => 1,
            datatype_description => 'an address',
            description => 'closest address',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'external_id',
            variable => 0, # set by server
            datatype => 'string',
            required => 1,
            datatype_description => 'an id',
            description => 'external system ID',
        ),
    ] },
);

1;
