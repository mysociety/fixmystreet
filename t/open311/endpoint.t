use strict; use warnings;

use Test::More;
use Test::LongString;
use Test::MockTime ':all';

use Open311::Endpoint;
use Data::Dumper;
use JSON::MaybeXS;

use t::open311::endpoint::Endpoint1;

my $endpoint = t::open311::endpoint::Endpoint1->new;

subtest "GET Service List" => sub {
    my $res = $endpoint->run_test_request( GET => '/services.xml' );
    ok $res->is_success, 'xml success'
        or diag $res->content;
    is_string $res->content, <<CONTENT, 'xml string ok';
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
    ok $res->is_success, 'json success';
    is_deeply decode_json($res->content),
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
            } ], 'json structure ok';

};

subtest "GET Service Definition" => sub {
    my $res = $endpoint->run_test_request( GET => '/services/POT.xml' );
    ok $res->is_success, 'xml success',
        or diag $res->content;
    is_string $res->content, <<CONTENT, 'xml string ok';
<?xml version="1.0" encoding="utf-8"?>
<service_definition>
  <attributes>
    <attribute>
      <code>depth</code>
      <datatype>number</datatype>
      <datatype_description>an integer</datatype_description>
      <description>depth of pothole, in centimetres</description>
      <order>1</order>
      <required>true</required>
      <variable>true</variable>
    </attribute>
    <attribute>
      <code>shape</code>
      <datatype>singlevaluelist</datatype>
      <datatype_description>square | circle | triangle</datatype_description>
      <description>shape of the pothole</description>
      <order>2</order>
      <required>false</required>
      <values>
        <value>
          <name>Circle</name>
          <key>circle</key>
        </value>
        <value>
          <name>Square</name>
          <key>square</key>
        </value>
        <value>
          <name>Triangle</name>
          <key>triangle</key>
        </value>
      </values>
      <variable>true</variable>
    </attribute>
  </attributes>
  <service_code>POT</service_code>
</service_definition>
CONTENT

    $res = $endpoint->run_test_request( GET => '/services/POT.json' );
    ok $res->is_success, 'json success';
    is_deeply decode_json($res->content),
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
                            "name" => "Circle",
                            "key" => "circle"
                        },
                        {
                            "name" => "Square",
                            "key" => "square"
                        },
                        {
                            "name" => "Triangle",
                            "key" => "triangle"
                        },
                    ],
               }
            ],
        }, 'json structure ok';
};

subtest "POST Service Request validation" => sub {
    my $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
    );
    ok ! $res->is_success, 'no service_code';

    $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
        service_code => 'BIN',
    );
    ok ! $res->is_success, 'no api_key';

    $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
        api_key => 'test',
        service_code => 'BADGER', # has moved the goalposts
    );
    ok ! $res->is_success, 'bad service_code';

    $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
        api_key => 'test',
        service_code => 'POT',
        address_string => '22 Acacia Avenue',
        first_name => 'Bob',
        last_name => 'Mould',
    );
    ok ! $res->is_success, 'no required attributes';

    $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
        api_key => 'test',
        service_code => 'POT',
        address_string => '22 Acacia Avenue',
        first_name => 'Bob',
        last_name => 'Mould',
        'attribute[depth]' => 100,
        'attribute[shape]' => 'starfish',
    );
    ok ! $res->is_success, 'bad attribute';
};

subtest "POST Service Request valid test" => sub {

    set_fixed_time('2014-01-01T12:00:00Z');
    my $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
        api_key => 'test',
        service_code => 'POT',
        address_string => '22 Acacia Avenue',
        first_name => 'Bob',
        last_name => 'Mould',
        'attribute[depth]' => 100,
        'attribute[shape]' => 'triangle',
    );
    ok $res->is_success, 'valid request'
        or diag $res->content;

    is_deeply decode_json($res->content),
        [ {
            "service_notice" => "This is a test service",
            "service_request_id" => 0
        } ], 'correct json returned';

    set_fixed_time('2014-02-01T12:00:00Z');
    $res = $endpoint->run_test_request( 
        POST => '/requests.xml', 
        api_key => 'test',
        service_code => 'POT',
        address_string => '22 Acacia Avenue',
        first_name => 'Bob',
        last_name => 'Mould',
        'attribute[depth]' => 100,
        'attribute[shape]' => 'triangle',
    );

    ok $res->is_success, 'valid request'
        or diag $res->content;

    is_string $res->content, <<CONTENT, 'xml string ok';
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
  <request>
    <service_notice>This is a test service</service_notice>
    <service_request_id>1</service_request_id>
  </request>
</service_requests>
CONTENT
};

subtest "GET Service Requests" => sub {

    my $res = $endpoint->run_test_request( GET => '/requests.xml', );
    ok $res->is_success, 'valid request'
        or die $res->content;
    my $xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
  <request>
    <address>22 Acacia Avenue</address>
    <address_id></address_id>
    <lat>0</lat>
    <long>0</long>
    <media_url></media_url>
    <requested_datetime>2014-01-01T12:00:00Z</requested_datetime>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <service_request_id>0</service_request_id>
    <status>open</status>
    <updated_datetime>2014-01-01T12:00:00Z</updated_datetime>
    <zipcode></zipcode>
  </request>
  <request>
    <address>22 Acacia Avenue</address>
    <address_id></address_id>
    <lat>0</lat>
    <long>0</long>
    <media_url></media_url>
    <requested_datetime>2014-02-01T12:00:00Z</requested_datetime>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <service_request_id>1</service_request_id>
    <status>open</status>
    <updated_datetime>2014-02-01T12:00:00Z</updated_datetime>
    <zipcode></zipcode>
  </request>
</service_requests>
CONTENT

    is_string $res->content, $xml, 'xml string ok';

    $res = $endpoint->run_test_request( GET => '/requests.xml?service_code=POT', );
    ok $res->is_success, 'valid request';

    is_string $res->content, $xml, 'xml string ok POT'
        or diag $res->content;

    $res = $endpoint->run_test_request( GET => '/requests.xml?service_code=BIN', );
    ok $res->is_success, 'valid request';
    is_string $res->content, <<CONTENT, 'xml string ok BIN (no requests)';
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
</service_requests>
CONTENT
};

subtest "GET Service Request" => sub {
    my @req=(<<REQ0,<<REQ1);
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
  <request>
    <address>22 Acacia Avenue</address>
    <address_id></address_id>
    <lat>0</lat>
    <long>0</long>
    <media_url></media_url>
    <requested_datetime>2014-01-01T12:00:00Z</requested_datetime>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <service_request_id>0</service_request_id>
    <status>open</status>
    <updated_datetime>2014-01-01T12:00:00Z</updated_datetime>
    <zipcode></zipcode>
  </request>
</service_requests>
REQ0
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
  <request>
    <address>22 Acacia Avenue</address>
    <address_id></address_id>
    <lat>0</lat>
    <long>0</long>
    <media_url></media_url>
    <requested_datetime>2014-02-01T12:00:00Z</requested_datetime>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <service_request_id>1</service_request_id>
    <status>open</status>
    <updated_datetime>2014-02-01T12:00:00Z</updated_datetime>
    <zipcode></zipcode>
  </request>
</service_requests>
REQ1

    my $res = $endpoint->run_test_request( GET => '/requests/0.xml', );
    ok $res->is_success, 'valid request';

    is_string $res->content, $req[0], 'Request 0 ok'
        or diag $res->content;;

    $res = $endpoint->run_test_request( GET => '/requests/1.xml', );
    ok $res->is_success, 'valid request';

    is_string $res->content, $req[1], 'Request 1 ok';
};

restore_time();
done_testing;
