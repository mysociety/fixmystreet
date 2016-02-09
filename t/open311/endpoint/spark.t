use strict; use warnings;

use Test::More;

use Open311::Endpoint;
use Data::Dumper;

my $endpoint = Open311::Endpoint->new;

subtest "Spark test" => sub {
    my $spark = $endpoint->spark;
    my $struct = {
        foo => {
            service_requests => [ 1,2,3 ],
            quxes => [
                {
                    values => [1,2],
                },
                {
                    values => [3,4],
                },
            ],
        },
    };
    is_deeply $spark->process_for_json($struct),
        {
            service_requests => [ 1,2,3 ],
            quxes => [
                {
                    values => [1,2],
                },
                {
                    values => [3,4],
                },
            ],
        };
        
    my $xml_struct = $spark->process_for_xml($struct);
    is_deeply $xml_struct,
        {
            foo => {
                service_requests => { request => [ 1,2,3 ] },
                quxes => {
                    quxe => [
                        {
                            values => {
                                value => [1,2],
                            },
                        },
                        {
                            values => {
                                value => [3,4],
                            },
                        },
                    ]
                },
            }
        }
        or warn Dumper($xml_struct);
};

done_testing;
