package Open311::Endpoint::Integration::Exor;
use Web::Simple;
extends 'Open311::Endpoint';
with 'Open311::Endpoint::Role::mySociety';

use Open311::Endpoint::Service::Request::mySociety;
use constant request_class => 'Open311::Endpoint::Service::Request::mySociety';

sub services {
    die "TODO";
}

1;
