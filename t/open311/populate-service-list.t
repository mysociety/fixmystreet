#!/usr/bin/env perl
package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::Default';

sub council_area_id { 1 }

package main;

use FixMyStreet::Test;
use FixMyStreet::DB;
use Test::Warn;
use utf8;

use_ok( 'Open311::PopulateServiceList' );
use_ok( 'Open311' );


my $processor = Open311::PopulateServiceList->new();
ok $processor, 'created object';

my $body = FixMyStreet::DB->resultset('Body')->create({
    name => 'Body Numero Uno',
} );
$body->body_areas->create({
    area_id => 1
} );

my $BROMLEY = 'Bromley Council';
my $bromley = FixMyStreet::DB->resultset('Body')->create( {
    name => $BROMLEY,
} );
$bromley->body_areas->create({
    area_id => 2482
} );

my $bucks = FixMyStreet::DB->resultset('Body')->create({
    name => 'Buckinghamshire Council',
});
$bucks->body_areas->create({
    area_id => 2217
});

for my $test (
    { desc => 'groups not set for new contacts', enable_groups => 0, groups => 0, delete => 1 },
    { desc => 'groups set for new contacts', enable_groups => 1, groups => 1, delete => 1},
    { desc => 'groups removed for existing contacts', enable_groups => 0, groups => 0, delete => 0 },
    { desc => 'groups added for existing contacts', enable_groups => 1, groups => 1, delete => 0},
) {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'tester' ],
        COBRAND_FEATURES => {
           category_groups => { tester => $test->{enable_groups} },
        }
    }, sub {
        subtest 'check basic functionality, ' . $test->{desc} => sub {
            FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete() if $test->{delete};

            my $service_list = get_xml_simple_object( get_standard_xml() );

            my $processor = Open311::PopulateServiceList->new();
            $processor->_current_body( $body );
            $processor->process_services( $service_list );

            my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
            is $contact_count, 3, 'correct number of contacts';

            for my $expects (
                { code => "001", group => $test->{groups} ? "sanitation" : undef },
                { code => "002", group => $test->{groups} ? "street" : undef },
                { code => "003", group => $test->{groups} ? "street" : undef },
            ) {
                my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id, email => $expects->{code} } )->first;
                is $contact->get_extra->{group}, $expects->{group}, "Group set correctly";
            }
        };
    };
}

my $last_update = {};
for my $test (
    { desc => 'set multiple groups for contact', enable_multi => 1, groups => ['sanitation', 'street']  },
    { desc => 'groups not edited if unchanged', enable_multi => 1, groups => ['sanitation', 'street'], unchanged => 1  },
) {
    subtest $test->{desc} => sub {
        FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete();

        my $services_xml = '<?xml version="1.0" encoding="utf-8"?>
        <services>
          <service>
            <service_code>100</service_code>
            <service_name>Cans left out 24x7</service_name>
            <description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
            <metadata>false</metadata>
            <type>realtime</type>
            <keywords>lorem, ipsum, dolor</keywords>
            <groups><group>sanitation</group><group>street</group></groups>
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
        </services>
        ';

        my $service_list = get_xml_simple_object($services_xml);

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'tester' ],
            COBRAND_FEATURES => {
               category_groups => { tester => 1 },
            }
        }, sub {
            my $processor = Open311::PopulateServiceList->new();
            $processor->_current_body( $body );
            $processor->process_services( $service_list );
        };
        my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
        is $contact_count, 2, 'correct number of contacts';

        my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id, email => 100 } )->first;
        is_deeply $contact->get_extra->{group}, $test->{groups}, "Multi groups set correctly";
        if ($test->{unchanged}) {
            is $contact->whenedited, $last_update->{100}, "contact unchanged";
        }
        $last_update->{100} = $contact->whenedited;

        $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id, email => '002'} )->first;
        is $contact->get_extra->{group}, 'street', "Single groups set correctly";
        if ($test->{unchanged}) {
            is $contact->whenedited, $last_update->{002}, "contact unchanged";
        }
        $last_update->{002} = $contact->whenedited;
    };
}

subtest "set multiple groups with groups element" => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete();

    my $services_xml = '<?xml version="1.0" encoding="utf-8"?>
    <services>
      <service>
        <service_code>100</service_code>
        <service_name>Cans left out 24x7</service_name>
        <description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
        <metadata>false</metadata>
        <type>realtime</type>
        <keywords>lorem, ipsum, dolor</keywords>
        <groups><group>sanitation &amp; cleaning</group><group>street</group></groups>
      </service>
    </services>
    ';

    my $service_list = get_xml_simple_object($services_xml);

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'tester' ],
        COBRAND_FEATURES => {
           category_groups => { tester => 1 },
        }
    }, sub {
        my $processor = Open311::PopulateServiceList->new();
        $processor->_current_body( $body );
        $processor->process_services( $service_list );
    };
    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 1, 'correct number of contacts';

    my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id, email => 100 } )->first;
    is_deeply $contact->get_extra->{group}, ['sanitation & cleaning','street'], "groups set correctly";
};

subtest 'check non open311 contacts marked as deleted' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => $body->id,
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

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 4, 'correct number of contacts';

    $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id, state => 'deleted' } )->count();
    is $contact_count, 1, 'correct number of deleted contacts';
};

subtest 'check email changed if matching category' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => $body->id,
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

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 3, 'correct number of contacts';
};

subtest 'check category name changed if updated' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => $body->id,
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

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 3, 'correct number of contacts';
};

subtest 'check conflicting contacts not changed' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete();

    my $contact = FixMyStreet::DB->resultset('Contact')->create(
        {
            body_id => $body->id,
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
            body_id => $body->id,
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

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 4, 'correct number of contacts';
};

subtest 'check new category marked non_public' => sub {
    FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->delete();

    my $services_xml = '<?xml version="1.0" encoding="utf-8"?>
    <services>
      <service>
        <service_code>100</service_code>
        <service_name>Cans left out 24x7</service_name>
        <description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
        <metadata>false</metadata>
        <type>realtime</type>
        <keywords>private</keywords>
        <group>sanitation</group>
      </service>
    </services>
        ';

    my $service_list = get_xml_simple_object( $services_xml );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 1, 'correct number of contacts';

    my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->first;
    is $contact->email, '100', 'email correct';
    is $contact->category, 'Cans left out 24x7', 'category correct';
    is $contact->non_public, 1, 'contact marked as non_public';
};

subtest 'check protected categories do not have name/group overwritten' => sub {
    my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->first;
    $contact->set_extra_metadata('open311_protect', 1);
    $contact->set_extra_metadata('group', [ 'sanitation' ]);
    $contact->non_public(0);
    $contact->update;

    my $services_xml = '<?xml version="1.0" encoding="utf-8"?>
    <services>
      <service>
        <service_code>100</service_code>
        <service_name>Cans left out constantly</service_name>
        <description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
        <metadata>false</metadata>
        <type>realtime</type>
        <keywords>private</keywords>
        <group>cleansing</group>
      </service>
    </services>
        ';

    my $service_list = get_xml_simple_object( $services_xml );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'tester' ],
        COBRAND_FEATURES => {
           category_groups => { tester => 1 },
        }
    }, sub {
        my $processor = Open311::PopulateServiceList->new();
        $processor->_current_body( $body );
        $processor->process_services( $service_list );
    };

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 1, 'correct number of contacts';

    $contact->discard_changes;
    is $contact->email, '100', 'email correct';
    is $contact->category, 'Cans left out 24x7', 'category unchanged';
    is_deeply $contact->groups, ['sanitation'], 'group unchanged';
    # test that something did change
    is $contact->non_public, 1, 'contact marked as non_public';
};


subtest 'check existing category marked non_public' => sub {
    my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->first;
    $contact->update({
        non_public => 0
    });
    is $contact->non_public, 0, 'contact not marked as non_public';

    my $services_xml = '<?xml version="1.0" encoding="utf-8"?>
    <services>
      <service>
        <service_code>100</service_code>
        <service_name>Cans left out 24x7</service_name>
        <description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
        <metadata>false</metadata>
        <type>realtime</type>
        <keywords>private</keywords>
        <group>sanitation</group>
      </service>
    </services>
        ';

    my $service_list = get_xml_simple_object( $services_xml );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 1, 'correct number of contacts';

    $contact->discard_changes;
    is $contact->email, '100', 'email correct';
    is $contact->category, 'Cans left out 24x7', 'category correct';
    is $contact->non_public, 1, 'contact changed to non_public';
};

subtest 'check existing non_public category does not get marked public' => sub {
    my $contact = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->first;
    is $contact->non_public, 1, 'contact marked as non_public';

    my $services_xml = '<?xml version="1.0" encoding="utf-8"?>
    <services>
      <service>
        <service_code>100</service_code>
        <service_name>Cans left out 24x7</service_name>
        <description>Garbage or recycling cans that have been left out for more than 24 hours after collection. Violators will be cited.</description>
        <metadata>false</metadata>
        <type>realtime</type>
        <keywords></keywords>
        <group>sanitation</group>
      </service>
    </services>
        ';

    my $service_list = get_xml_simple_object( $services_xml );

    my $processor = Open311::PopulateServiceList->new();
    $processor->_current_body( $body );
    $processor->process_services( $service_list );

    my $contact_count = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } )->count();
    is $contact_count, 1, 'correct number of contacts';

    $contact->discard_changes;
    is $contact->email, '100', 'email correct';
    is $contact->category, 'Cans left out 24x7', 'category correct';
    is $contact->non_public, 1, 'contact remains non_public';
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
                description => 'Type of <b>bin</b>'

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
                <description>&lt;type&gt;Type&lt;/type&gt; of &lt;b&gt;bin&lt;/b&gt;</description>
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
        desc => 'check meta data unchanging',
        has_meta => 1,
        has_no_history => 1,
        orig_meta => [ {
            variable => 'true',
            code => 'type',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Colour of bin',
            order => 1,
            description => 'Cólour of bin'

        } ],
        end_meta => [ {
            variable => 'true',
            code => 'type',
            datatype => 'string',
            required => 'true',
            datatype_description => 'Colour of bin',
            order => 1,
            description => 'Cólour of bin'

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
                <description>Cólour of bin</description>
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
        desc => 'check protected meta data not overwritten',
        has_meta => 1,
        end_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Bin type',
                order => 1,
                description => 'Bin type',
                protected => 'true'

        } ],
        orig_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Bin type',
                order => 1,
                description => 'Bin type',
                protected => 'true'

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
        desc => 'check protected meta data retained',
        has_meta => 1,
        end_meta => [
            {
                variable => 'true',
                code => 'type2',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Type of bin',
                order => 1,
                description => 'Type of bin',

            },
            {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Number of bin',
                order => 1,
                description => 'Number of bin',
                protected => 'true'
            },
        ],
        orig_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Number of bin',
                order => 1,
                description => 'Number of bin',
                protected => 'true'

        } ],
        meta_xml => '<?xml version="1.0" encoding="utf-8"?>
    <service_definition>
        <service_code>100</service_code>
        <attributes>
            <attribute>
                <variable>true</variable>
                <code>type2</code>
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
        desc => 'check protected meta data retained on removal of all Open311 extras',
        end_meta => [
            {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Number of bin',
                order => 1,
                description => 'Number of bin',
                protected => 'true'
            },
        ],
        orig_meta => [ {
                variable => 'true',
                code => 'type',
                datatype => 'string',
                required => 'true',
                datatype_description => 'Number of bin',
                order => 1,
                description => 'Number of bin',
                protected => 'true'

        } ],
        meta_xml => '<?xml version="1.0" encoding="utf-8"?>
    <service_definition>
        <service_code>100</service_code>
        <attributes>
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
                body_id => $body->id,
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

        my $count = FixMyStreet::DB->resultset('ContactsHistory')->search({
            contact_id => $contact->id,
        })->count;

        $processor->process_services( $service_list );

        $contact->discard_changes;

        is_deeply $contact->get_extra_fields, $test->{end_meta}, 'meta data saved';

        if ($test->{has_no_history}) {
            is +FixMyStreet::DB->resultset('ContactsHistory')->search({
                contact_id => $contact->id,
            })->count, $count, 'No new history';
        }
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
            body_id => $body->id,
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
        <attribute>
            <variable>true</variable>
            <code>easting</code>
            <datatype>string</datatype>
            <required>true</required>
            <datatype_description>String</datatype_description>
            <order>1</order>
            <description>Easting</description>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::DB->resultset('Contact')->find_or_create(
        {
            body_id => $body->id,
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
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bromley' ],
    }, sub {
        $processor->_current_body( $bromley );
    };
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
            automated => 'server_set',
            variable => 'true',
            code => 'easting',
            datatype => 'string',
            required => 'true',
            datatype_description => 'String',
            order => 1,
            description => 'Easting',
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
        }, {
            variable => 'true',
            code => 'easting',
            datatype => 'string',
            required => 'true',
            datatype_description => 'String',
            order => 1,
            description => 'Easting',
        },
    ];

    $contact->discard_changes;

    is_deeply $contact->get_extra_fields, $extra, 'all meta data saved for non bromley';
};

subtest 'check Buckinghamshire extra code' => sub {
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
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::DB->resultset('Contact')->find_or_create({
        body_id => $body->id,
        email => '001',
        category => 'Flytipping',
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
        ALLOWED_COBRANDS => [ 'buckinghamshire' ],
    }, sub {
        $processor->_current_body( $bucks );
    };
    $processor->_current_service( { service_code => 100, service_name => 'Flytipping' } );
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
        variable => 'true',
        code => 'road-placement',
        datatype => 'singlevaluelist',
        required => 'true',
        order => 100,
        description => 'Is the fly-tip located on',
        values => [
            { key => 'road', name => 'The road' },
            { key => 'off-road', name => 'Off the road/on a verge' },
        ],
    } ];

    $contact->discard_changes;
    is_deeply $contact->get_extra_fields, $extra, 'extra Bucks field returned for flytipping';

    $processor->_current_service( { service_code => 100, service_name => 'Street lights' } );
    $processor->_add_meta_to_contact( $contact );

    $extra = [ {
        variable => 'true',
        code => 'type',
        datatype => 'string',
        required => 'true',
        datatype_description => 'Type of bin',
        order => 1,
        description => 'Type of bin'
    } ];

    $contact->discard_changes;
    is_deeply $contact->get_extra_fields, $extra, 'no extra Bucks field returned otherwise';
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
