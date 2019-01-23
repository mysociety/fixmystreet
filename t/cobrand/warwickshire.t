#!/usr/bin/env perl

use FixMyStreet::Test;
use FixMyStreet::DB;

use_ok( 'Open311::PopulateServiceList' );
use_ok( 'Open311' );

my $processor = Open311::PopulateServiceList->new();
ok $processor, 'created object';

my $warks = FixMyStreet::DB->resultset('Body')->create({
    name => 'Warwickshire County Council',
});
$warks->body_areas->create({ area_id => 2243 });

subtest 'check Warwickshire override' => sub {
    my $processor = Open311::PopulateServiceList->new();

    my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>100</service_code>
    <attributes>
        <attribute>
            <variable>true</variable>
            <code>closest_address</code>
            <datatype>string</datatype>
            <required>true</required>
            <order>1</order>
            <description>Closest address</description>
        </attribute>
        <attribute>
            <variable>true</variable>
            <code>size</code>
            <datatype>string</datatype>
            <required>true</required>
            <order>2</order>
            <description>How big is the pothole</description>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::DB->resultset('Contact')->create({
        body_id => $warks->id,
        email => '100',
        category => 'Pothole',
        state => 'confirmed',
        editor => $0,
        whenedited => \'current_timestamp',
        note => 'test contact',
    });

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/100.xml' => $meta_xml }
    );

    $processor->_current_open311( $o );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'warwickshire' ],
    }, sub {
        $processor->_current_body( $warks );
    };
    $processor->_current_service( { service_code => 100, service_name => 'Pothole' } );
    $processor->_add_meta_to_contact( $contact );

    my $extra = [ {
        variable => 'true',
        code => 'size',
        datatype => 'string',
        required => 'true',
        order => 2,
        description => 'How big is the pothole',
    } ];

    $contact->discard_changes;
    is_deeply $contact->get_extra_fields, $extra, 'No closest_address field returned for Warks';
    is $contact->get_extra_metadata('id_field'), 'external_id', 'id_field set correctly';
};

done_testing();
