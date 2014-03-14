package t::open311::endpoint::Endpoint1;
use Web::Simple;
extends 'Open311::Endpoint';

use Open311::Endpoint::Service;
use t::open311::endpoint::ServiceType1;
use Open311::Endpoint::Service::Attribute;

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

1;
