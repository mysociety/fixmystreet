package t::open311::endpoint::ServiceType1;
use Moo;
extends 'Open311::Endpoint::Service';
use DateTime;

use Open311::Endpoint::Service::Request;

has '+default_service_notice' => (
    default => 'This is a test service',
);

1;
