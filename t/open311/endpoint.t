use strict; use warnings;

use Test::More;
use Test::LongString;

use Open311::Endpoint;
use Data::Dumper;
use JSON;

{
    package t::Open311::Endpoint;
    use Web::Simple;
    extends 'Open311::Endpoint';
    use Open311::Endpoint::Service;
    use Open311::Endpoint::Service::Attribute;

    sub services {
        return (
            Open311::Endpoint::Service->new(
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
            Open311::Endpoint::Service->new(
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
}

my $endpoint = t::Open311::Endpoint->new;
my $json = JSON->new;

subtest "GET Service List" => sub {
    my $res = $endpoint->run_test_request( GET => '/services.xml' );
    ok $res->is_success
        or diag $res->content;
    is_string $res->content, <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<services>
  <service>
    <description>Pothole Repairs Service</description>
    <group>highways</group>
    <keywords>deep,hole,wow</keywords>
    <metadata>true</metadata>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Bin Enforcement Service</description>
    <group>sanitation</group>
    <keywords>bin</keywords>
    <metadata>false</metadata>
    <service_code>BIN</service_code>
    <service_name>Bin Enforcement</service_name>
    <type>realtime</type>
  </service>
</services>
CONTENT

    $res = $endpoint->run_test_request( GET => '/services.json' );
    ok $res->is_success;
    is_deeply $json->decode($res->content),
        [ {
               "keywords" => "deep,hole,wow",
               "group" => "highways",
               "service_name" => "Pothole Repairs",
               "type" => "realtime",
               "metadata" => "true",
               "description" => "Pothole Repairs Service",
               "service_code" => "POT"
            }, {
               "keywords" => "bin",
               "group" => "sanitation",
               "service_name" => "Bin Enforcement",
               "type" => "realtime",
               "metadata" => "false",
               "description" => "Bin Enforcement Service",
               "service_code" => "BIN"
            } ];

};

subtest "GET Service List" => sub {
    my $res = $endpoint->run_test_request( GET => '/services/POT.xml' );
    ok $res->is_success
        or diag $res->content;
    is_string $res->content, <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_definition>
  <attributes>
    <code>depth</code>
    <datatype>number</datatype>
    <datatype_description>an integer</datatype_description>
    <description>depth of pothole, in centimetres</description>
    <order>1</order>
    <required>true</required>
    <variable>true</variable>
  </attributes>
  <attributes>
    <code>shape</code>
    <datatype>singlevaluelist</datatype>
    <datatype_description>square | circle | triangle</datatype_description>
    <description>shape of the pothole</description>
    <order>2</order>
    <required>false</required>
    <values>
      <name>Triangle</name>
      <key>triangle</key>
    </values>
    <values>
      <name>Circle</name>
      <key>circle</key>
    </values>
    <values>
      <name>Square</name>
      <key>square</key>
    </values>
    <variable>true</variable>
  </attributes>
  <service_code>POT</service_code>
</service_definition>
CONTENT

    $res = $endpoint->run_test_request( GET => '/services/POT.json' );
    ok $res->is_success;
    is_deeply $json->decode($res->content),
        {
            "service_code" => "POT",
            "attributes" => [
                {
                    "order" => 1,
                    "code" => "depth",
                    "required" => "true",
                    "variable" => "true",
                    "datatype_description" => "an integer",
                    "description" => "depth of pothole, in centimetres",
                    "datatype" => "number",
                },
                {
                    "order" => 2,
                    "code" => "shape",
                    "variable" => "true",
                    "datatype_description" => "square | circle | triangle",
                    "description" => "shape of the pothole",
                    "required" => "false",
                    "datatype" => "singlevaluelist",
                    "values" => [
                        {
                            "name" => "Triangle",
                            "key" => "triangle"
                        },
                        {
                            "name" => "Circle",
                            "key" => "circle"
                        },
                        {
                            "name" => "Square",
                            "key" => "square"
                        }
                    ],
               }
            ],
        };
};
done_testing;
