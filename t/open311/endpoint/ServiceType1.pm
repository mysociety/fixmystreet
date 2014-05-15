package t::open311::endpoint::ServiceType1;
use Moo;
extends 'Open311::Endpoint::Service';
use DateTime;

has '+default_service_notice' => (
    default => 'This is a test service',
);

1;
