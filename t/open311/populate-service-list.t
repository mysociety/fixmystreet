#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FixMyStreet::App;

use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

use_ok( 'Open311::PopulateServiceList' );
use_ok( 'Open311' );


my $processor = Open311::PopulateServiceList->new( council_list => [] );
ok $processor, 'created object';



subtest 'check basic functionality' => sub {
    FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->delete();

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $council = FixMyStreet::App->model('DB::Open311Conf')->new( {
        area_id => 1
    } );

    my $processor = Open311::PopulateServiceList->new( council_list => [] );
    $processor->_current_council( $council );
    $processor->process_services( $service_list );

    my $contact_count = FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->count();
    is $contact_count, 3, 'correct number of contacts';
};

subtest 'check non open311 contacts marked as deleted' => sub {
    FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->delete();

    my $contact = FixMyStreet::App->model('DB::Contact')->create(
        {
            area_id => 1,
            email =>   'contact@example.com',
            category => 'An old category',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $council = FixMyStreet::App->model('DB::Open311Conf')->new( {
        area_id => 1
    } );

    my $processor = Open311::PopulateServiceList->new( council_list => [] );
    $processor->_current_council( $council );
    $processor->process_services( $service_list );

    my $contact_count = FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->count();
    is $contact_count, 4, 'correct number of contacts';

    $contact_count = FixMyStreet::App->model('DB::Contact')->search( { area_id => 1, deleted => 1 } )->count();
    is $contact_count, 1, 'correct number of deleted contacts';
};

subtest 'check email changed if matching category' => sub {
    FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->delete();

    my $contact = FixMyStreet::App->model('DB::Contact')->create(
        {
            area_id => 1,
            email =>   '009',
            category => 'Cans left out 24x7',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    ok $contact, 'contact created';

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $council = FixMyStreet::App->model('DB::Open311Conf')->new( {
        area_id => 1
    } );

    my $processor = Open311::PopulateServiceList->new( council_list => [] );
    $processor->_current_council( $council );
    $processor->process_services( $service_list );

    $contact->discard_changes;
    is $contact->email, '001', 'email unchanged';
    is $contact->confirmed, 1, 'contact still confirmed';
    is $contact->deleted, 0, 'contact still not deleted';

    my $contact_count = FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->count();
    is $contact_count, 3, 'correct number of contacts';
};

subtest 'check category name changed if updated' => sub {
    FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->delete();

    my $contact = FixMyStreet::App->model('DB::Contact')->create(
        {
            area_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    ok $contact, 'contact created';

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $council = FixMyStreet::App->model('DB::Open311Conf')->new( {
        area_id => 1
    } );

    my $processor = Open311::PopulateServiceList->new( council_list => [] );
    $processor->_current_council( $council );
    $processor->process_services( $service_list );

    $contact->discard_changes;
    is $contact->email, '001', 'email unchanged';
    is $contact->category, 'Cans left out 24x7', 'category changed';
    is $contact->confirmed, 1, 'contact still confirmed';
    is $contact->deleted, 0, 'contact still not deleted';

    my $contact_count = FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->count();
    is $contact_count, 3, 'correct number of contacts';
};

subtest 'check conflicting contacts not changed' => sub {
    FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->delete();

    my $contact = FixMyStreet::App->model('DB::Contact')->create(
        {
            area_id => 1,
            email =>   'existing@example.com',
            category => 'Cans left out 24x7',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    ok $contact, 'contact created';

    my $contact2 = FixMyStreet::App->model('DB::Contact')->create(
        {
            area_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    ok $contact2, 'contact created';

    my $service_list = get_xml_simple_object( get_standard_xml() );

    my $council = FixMyStreet::App->model('DB::Open311Conf')->new( {
        area_id => 1
    } );

    my $processor = Open311::PopulateServiceList->new( council_list => [] );
    $processor->_current_council( $council );
    $processor->process_services( $service_list );

    $contact->discard_changes;
    is $contact->email, 'existing@example.com', 'first contact email unchanged';
    is $contact->category, 'Cans left out 24x7', 'first contact category unchanged';
    is $contact->confirmed, 1, 'first contact contact still confirmed';
    is $contact->deleted, 0, 'first contact contact still not deleted';

    $contact2->discard_changes;
    is $contact2->email, '001', 'second contact email unchanged';
    is $contact2->category, 'Bins left out 24x7', 'second contact category unchanged';
    is $contact2->confirmed, 1, 'second contact contact still confirmed';
    is $contact2->deleted, 0, 'second contact contact still not deleted';

    my $contact_count = FixMyStreet::App->model('DB::Contact')->search( { area_id => 1 } )->count();
    is $contact_count, 4, 'correct number of contacts';
};

subtest 'check meta data population' => sub {
    my $processor = Open311::PopulateServiceList->new( council_list => [] );

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
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::App->model('DB::Contact')->find_or_create(
        {
            area_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/100.xml' => $meta_xml }
    );

    my $council = FixMyStreet::App->model('DB::Open311conf')->new( {
        area_id => 2482
    } );

    $processor->_current_open311( $o );
    $processor->_current_council( $council );
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

    } ];

    $contact->discard_changes;

    is_deeply $contact->extra, $extra, 'meta data saved';
};

subtest 'check attribute ordering' => sub {
    my $processor = Open311::PopulateServiceList->new( council_list => [] );

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

    my $contact = FixMyStreet::App->model('DB::Contact')->find_or_create(
        {
            area_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/100.xml' => $meta_xml }
    );

    my $council = FixMyStreet::App->model('DB::Open311conf')->new( {
        area_id => 1
    } );

    $processor->_current_open311( $o );
    $processor->_current_council( $council );
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

    is_deeply $contact->extra, $extra, 'meta data re-ordered correctly';
};

subtest 'check bromely skip code' => sub {
    my $processor = Open311::PopulateServiceList->new( council_list => [] );

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

    my $contact = FixMyStreet::App->model('DB::Contact')->find_or_create(
        {
            area_id => 1,
            email =>   '001',
            category => 'Bins left out 24x7',
            confirmed => 1,
            deleted => 0,
            editor => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'test contact',
        }
    );

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/100.xml' => $meta_xml }
    );

    my $council = FixMyStreet::App->model('DB::Open311conf')->new( {
        area_id => 2482
    } );

    $processor->_current_open311( $o );
    $processor->_current_council( $council );
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

    } ];

    $contact->discard_changes;

    is_deeply $contact->extra, $extra, 'only non std bromley meta data saved';

    $council->area_id(1);

    $processor->_current_council( $council );
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

    is_deeply $contact->extra, $extra, 'all meta data saved for non bromley';
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

    my $simple = XML::Simple->new();
    my $obj;

    eval {
        $obj = $simple->XMLin( $xml );
    };

    die $@ if $@;

    return $obj;
}

done_testing();
