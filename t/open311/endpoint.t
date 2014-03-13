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
                service_code => '123',
                service_name => 'wibble',
                description => 'hurrah',
                attributes => {
                    foo => Open311::Endpoint::Service::Attribute->new(
                        code => 'foo',
                        required => undef,
                        datatype => 'number',
                        datatype_description => 'an integer',
                        description => 'number of foos',
                    ),
                },
                type => 'realtime',
                keywords => [qw/ foo bar baz/],
                group => 'sanitation',
            ),
            Open311::Endpoint::Service->new(
                service_code => '124',
                service_name => 'wobble',
                description => 'meh',
                attributes => {},
                type => 'realtime',
                keywords => [qw/ foo bar baz/],
                group => 'sanitation',
            )
        );
    }
}

my $endpoint = t::Open311::Endpoint->new;
my $json = JSON->new;

subtest "services" => sub {
    my $res = $endpoint->run_test_request( GET => '/services.xml' );
    ok $res->is_success;
    is_string $res->content, <<CONTENT;
<services>
  <service>
    <description>hurrah</description>
    <group>sanitation</group>
    <keywords>foo,bar,baz</keywords>
    <metadata>true</metadata>
    <service_code>123</service_code>
    <service_name>wibble</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>meh</description>
    <group>sanitation</group>
    <keywords>foo,bar,baz</keywords>
    <metadata>false</metadata>
    <service_code>124</service_code>
    <service_name>wobble</service_name>
    <type>realtime</type>
  </service>
</services>
CONTENT

    $res = $endpoint->run_test_request( GET => '/services.json' );
    ok $res->is_success;
    is_deeply $json->decode($res->content),
        [ {
               "keywords" => "foo,bar,baz",
               "group" => "sanitation",
               "service_name" => "wibble",
               "type" => "realtime",
               "metadata" => "true",
               "description" => "hurrah",
               "service_code" => "123"
            }, {
               "keywords" => "foo,bar,baz",
               "group" => "sanitation",
               "service_name" => "wobble",
               "type" => "realtime",
               "metadata" => "false",
               "description" => "meh",
               "service_code" => "124"
            } ];

};

done_testing;
