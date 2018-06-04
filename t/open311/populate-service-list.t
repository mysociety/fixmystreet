#!/usr/bin/env perl

use FixMyStreet::Test;
use FixMyStreet::DB;

use_ok( 'Open311::PopulateServiceList' );
use_ok( 'Open311' );


my $processor = Open311::PopulateServiceList->new();
ok $processor, 'created object';

my $body = FixMyStreet::DB->resultset('Body')->find_or_create( {
    id => 1,
    name => 'Body Numero Uno',
} );
$body->body_areas->find_or_create({
    area_id => 1
} );

my $BROMLEY = 'Bromley Council';
my $bromley = FixMyStreet::DB->resultset('Body')->find_or_create( {
    id => 2482,
    name => $BROMLEY,
} );
$bromley->update({ name => $BROMLEY });
$bromley->body_areas->find_or_create({
    area_id => 2482
} );

subtest 'check basic functionality' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->delete();

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->count();
    is $contact_count, 3, 'correct number of contacts';

    for my $test (
        { code => "001", group => "sanitation" },
        { code => "002", group => "street" },
        { code => "003", group => "street" },
    ) {
        my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => 1, email => $test->{code} } )->first;
        is $contact->get_extra->{group}, $test->{group}, "Group set correctly";
    }
};

subtest 'check non open311 contacts marked as deleted' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => 1,
            email =>   'contact@example.com',
            category => 'An old category',
            state => 'confirmed',
            editor => $0,
            whenedited => \'current_timestamp',
            note => 'test contact',
        }
    );

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->count();
    is $contact_count, 4, 'correct number of contacts';

    $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => 1, state => 'deleted' } )->count();
    is $contact_count, 1, 'correct number of deleted contacts';
};

subtest 'check email changed if matching category' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => 1,
            email =>   '009',
            category => 'Cans left out 24x7',
            state => 'confirmed',
            editor => $0,
            whenedited => \'current_timestamp',
            note => 'test contact',
        }
    );

    ok $contact, 'contact created';

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    $contact->discard_changes;
    is $contact->email, '001', 'email unchanged';
    is $contact->state, 'confirmed', 'contact still confirmed';

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->count();
    is $contact_count, 3, 'correct number of contacts';
};

subtest 'check category name changed if updated' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            state => 'confirmed',
            editor => $0,
            whenedited => \'current_timestamp',
            note => 'test contact',
        }
    );

    ok $contact, 'contact created';

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    $contact->discard_changes;
    is $contact->email, '001', 'email unchanged';
    is $contact->category, 'Cans left out 24x7', 'category changed';
    is $contact->state, 'confirmed', 'contact still confirmed';

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->count();
    is $contact_count, 3, 'correct number of contacts';
};

subtest 'check conflicting contacts not changed' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => 1,
            email =>   'existing@example.com',
            category => 'Cans left out 24x7',
            state => 'confirmed',
            editor => $0,
            whenedited => \'current_timestamp',
            note => 'test contact',
        }
    );

    ok $contact, 'contact created';

    my $contact2 = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            state => 'confirmed',
            editor => $0,
            whenedited => \'current_timestamp',
            note => 'test contact',
        }
    );

    ok $contact2, 'contact created';

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    $contact->discard_changes;
    is $contact->email, 'existing@example.com', 'first contact email unchanged';
    is $contact->category, 'Cans left out 24x7', 'first contact category unchanged';
    is $contact->state, 'confirmed', 'first contact still confirmed';

    $contact2->discard_changes;
    is $contact2->email, '001', 'second contact email unchanged';
    is $contact2->category, 'Bins left out 24x7', 'second contact category unchanged';
    is $contact2->state, 'confirmed', 'second contact still confirmed';

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => 1 } )->count();
    is $contact_count, 4, 'correct number of contacts';
};

for my $test (
    {
        desc => 'check meta data added to existing contact',
        has_meta => 1,
        orig_meta => [],
        end_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Type of bin',
                order => 1,
                description => 'Type of bin'

        } ],
        meta_xml => '<?xml version="1.0" encoding="utf-8"?>
    <service_definition>
        <service_code>100</service_code>
        <attributes>
            <attribute>
                <variable>true</variable>
                <code>type</code>
                <datatype>string</datatype>
                <required>true</required>
                <datatype_description>Type of bin</datatype_description>
                <order>1</order>
                <description>Type of bin</description>
            </attribute>
        </attributes>
    </service_definition>
        ',
    },
    {
        desc => 'check meta data updated',
        has_meta => 1,
        orig_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Type of bin',
                order => 1,
                description => 'Type of bin'

        } ],
        end_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Colour of bin',
                order => 1,
                description => 'Colour of bin'

        } ],
        meta_xml => '<?xml version="1.0" encoding="utf-8"?>
    <service_definition>
        <service_code>100</service_code>
        <attributes>
            <attribute>
                <variable>true</variable>
                <code>type</code>
                <datatype>string</datatype>
                <required>true</required>
                <datatype_description>Colour of bin</datatype_description>
                <order>1</order>
                <description>Colour of bin</description>
            </attribute>
        </attributes>
    </service_definition>
        ',
    },
    {
        desc => 'check meta data removed',
        has_meta => 0,
        end_meta => [],
        orig_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Type of bin',
                order => 1,
                description => 'Type of bin'

        } ],
        meta_xml => '<?xml version="1.0" encoding="utf-8"?>
    <service_definition>
        <service_code>100</service_code>
        <attributes>
            <attribute>
                <variable>true</variable>
                <code>type</code>
                <datatype>string</datatype>
                <required>true</required>
                <datatype_description>Type of bin</datatype_description>
                <order>1</order>
                <description>Type of bin</description>
            </attribute>
        </attributes>
    </service_definition>
        ',
    },
    {
        desc => 'check empty meta data handled',
        has_meta => 1,
        orig_meta => [],
        end_meta => [],
        meta_xml => '<?xml version="1.0" encoding="utf-8"?>
    <service_definition>
        <service_code>100</service_code>
        <attributes>
        </attributes>
    </service_definition>
        ',
    },
) {
    subtest $test->{desc} => sub {
        my $processor = Open311::PopulateServiceList->new();

        my $services_xml = '<?xml version="1.0" encoding="utf-8"?>
    <services>
      <service>
        <service_code>100</service_code>
        <service_name>Cans left out 24x7</service_name>
        <description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
        <metadata>false</metadata>
        <type>realtime</type>
        <keywords>lorem, ipsum, dolor</keywords>
        <group>sanitation</group>
      </service>
    </services>
        ';

        if ( $test->{has_meta} ) {
            $services_xml =~ s/metadata>false/metadata>true/ms;
        }

        my $contact = FixMyStreet::DB->resultset('Contact')->find_or_create(
            {
                body_id => 1,
                email =>   '100',
                category => 'Cans left out 24x7',
                state => 'confirmed',
                editor => $0,
                whenedited => \'current_timestamp',
                note => 'test contact',
            }
        );

        $contact->set_extra_fields(@{$test->{orig_meta}});
        $contact->update;

        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'services.xml' => $services_xml, 'services/100.xml' => $test->{meta_xml} }
        );

        my $service_list = get_xml_simple_object( $services_xml );

        $processor->_current_open311( $o );
        $processor->_current_body( $body );

        $processor->process_services( $service_list );

        $contact->discard_changes;

        is_deeply $contact->get_extra_fields, $test->{end_meta}, 'meta data saved';
    };
}

subtest 'check attribute ordering' => sub {
    my $processor = Open311::PopulateServiceList->new();

    my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>100</service_code>
    <attributes>
        <attribute>
            <variable>true</variable>
            <code>type</code>
            <datatype>string</datatype>
            <required>true</required>
            <datatype_description>Type of bin</datatype_description>
            <order>1</order>
            <description>Type of bin</description>
        </attribute>
        <attribute>
            <variable>true</variable>
            <code>colour</code>
            <datatype>string</datatype>
            <required>true</required>
            <datatype_description>Colour of bin</datatype_description>
            <order>3</order>
            <description>Colour of bin</description>
        </attribute>
        <attribute>
            <variable>true</variable>
            <code>size</code>
            <datatype>string</datatype>
            <required>true</required>
            <datatype_description>Size of bin</datatype_description>
            <order>2</order>
            <description>Size of bin</description>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::DB->resultset('Contact')->find_or_create(
        {
            body_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            state => 'confirmed',
            editor => $0,
            whenedited => \'current_timestamp',
            note => 'test contact',
        }
    );

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/100.xml' => $meta_xml }
    );

    $processor->_current_open311( $o );
    $processor->_current_body( $body );
    $processor->_current_service( { service_code => 100 } );

    $processor->_add_meta_to_contact( $contact );

    my $extra = [
        {
            variable => 'true',
            code => 'type',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Type of bin',
            order => 1,
            description => 'Type of bin'

        },
        {
            variable => 'true',
            code => 'size',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Size of bin',
            order => 2,
            description => 'Size of bin'

        },
        {
            variable => 'true',
            code => 'colour',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Colour of bin',
            order => 3,
            description => 'Colour of bin'

        },
    ];

    $contact->discard_changes;

    is_deeply $contact->get_extra_fields, $extra, 'meta data re-ordered correctly';
};

subtest 'check Bromley skip code' => sub {
    my $processor = Open311::PopulateServiceList->new();

    my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>100</service_code>
    <attributes>
        <attribute>
            <variable>true</variable>
            <code>type</code>
            <datatype>string</datatype>
            <required>true</required>
            <datatype_description>Type of bin</datatype_description>
            <order>1</order>
            <description>Type of bin</description>
        </attribute>
        <attribute>
            <variable>true</variable>
            <code>title</code>
            <datatype>string</datatype>
            <required>true</required>
            <datatype_description>Type of bin</datatype_description>
            <order>1</order>
            <description>Type of bin</description>
        </attribute>
        <attribute>
            <variable>true</variable>
            <code>report_url</code>
            <datatype>string</datatype>
            <required>true</required>
            <datatype_description>Type of bin</datatype_description>
            <order>1</order>
            <description>Type of bin</description>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::DB->resultset('Contact')->find_or_create(
        {
            body_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            state => 'confirmed',
            editor => $0,
            whenedited => \'current_timestamp',
            note => 'test contact',
        }
    );

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/100.xml' => $meta_xml }
    );

    $processor->_current_open311( $o );
    $processor->_current_body( $bromley );
    $processor->_current_service( { service_code => 100 } );

    $processor->_add_meta_to_contact( $contact );

    my $extra = [ {
            variable => 'true',
            code => 'type',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Type of bin',
            order => 1,
            description => 'Type of bin'
    }, {
            automated => 'hidden_field',
            variable => 'true',
            code => 'prow_reference',
            datatype => 'string',
            required => 'false',
            order => 101,
            description => 'Right of way reference'
    } ];

    $contact->discard_changes;

    is_deeply $contact->get_extra_fields, $extra, 'only non std bromley meta data saved';

    $processor->_current_body( $body );
    $processor->_add_meta_to_contact( $contact );

    $extra = [
        {
            variable => 'true',
            code => 'type',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Type of bin',
            order => 1,
            description => 'Type of bin'

        },
        {
            variable => 'true',
            code => 'title',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Type of bin',
            order => 1,
            description => 'Type of bin'

        },
        {
            variable => 'true',
            code => 'report_url',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Type of bin',
            order => 1,
            description => 'Type of bin'

        },
    ];

    $contact->discard_changes;

    is_deeply $contact->get_extra_fields, $extra, 'all meta data saved for non bromley';
};

sub get_standard_xml {
    return qq{<?xml version="1.0" encoding="utf-8"?>
<services>
	<service>
		<service_code>001</service_code>
		<service_name>Cans left out 24x7</service_name>
		<description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
		<metadata>false</metadata>
		<type>realtime</type>
		<keywords>lorem, ipsum, dolor</keywords>
		<group>sanitation</group>
	</service>
	<service>
		<service_code>002</service_code>
		<metadata>false</metadata>
		<type>realtime</type>
		<keywords>lorem, ipsum, dolor</keywords>
		<group>street</group>
		<service_name>Construction plate shifted</service_name>
		<description>Metal construction plate covering the street or sidewalk has been moved.</description>
	</service>
	<service>
		<service_code>003</service_code>
		<metadata>false</metadata>
		<type>realtime</type>
		<keywords>lorem, ipsum, dolor</keywords>
		<group>street</group>
		<service_name>Curb or curb ramp defect</service_name>
		<description>Sidewalk curb or ramp has problems such as cracking, missing pieces, holes, and/or chipped curb.</description>
	</service>
</services>
};
}

sub get_xml_simple_object {
    my $xml = shift;
    return Open311->_get_xml_object($xml);
}

done_testing();
