use FixMyStreet::Test;

use Test::Deep;

use Open311;
use FixMyStreet::SendReport::Open311;
use FixMyStreet::DB;

use Data::Dumper;

package main;
sub test_overrides; # defined below

use constant TEST_USER_EMAIL => 'fred@example.com';

my %standard_open311_parameters = (
    'send_notpinpointed' => 0,
    'extended_description' => 1,
    'use_service_as_deviceid' => 0,
    'extended_statuses' => 0,
    'always_send_latlong' => 1,
    'debug' => 0,
    'error' => '',
    'endpoints' => {
        'requests' => 'requests.xml',
        'service_request_updates' => 'servicerequestupdates.xml',
        'services' => 'services.xml',
        'update' => 'servicerequestupdates.xml',
    },
);

test_overrides oxfordshire =>
    {
        body_name => 'Oxfordshire',
        body_id   => 2237,
        row_data  => {
            postcode => 'OX1 1AA',
        },
        extra => {
            northing => 100,
            easting => 100,
            closest_address => '49 St Giles',
        },
    },
    superhashof({
        handler => isa('FixMyStreet::Cobrand::Oxfordshire'),
        discard_changes => 1,
        'open311' => noclass(superhashof({
            %standard_open311_parameters,
            'extended_description' => 'oxfordshire',
        })),
        problem_extra => bag(
            { name => 'northing', value => 100 },
            { name => 'easting', value => 100 },
            { name => 'closest_address' => value => '49 St Giles' },
            { name => 'external_id', value => re('[0-9]+') },
        ),
    });

my $bromley_check =
    superhashof({
        handler => isa('FixMyStreet::Cobrand::Bromley'),
        discard_changes => 1,
        'open311' => noclass(superhashof({
            %standard_open311_parameters,
            'send_notpinpointed' => 1,
            'extended_description' => 0,
            'use_service_as_deviceid' => 0,
            'always_send_latlong' => 0,
        })),
        problem_extra => bag(
            { name => 'report_url' => value => 'http://example.com/1234' },
            { name => 'report_title', value => 'Problem' },
            { name => 'public_anonymity_required', value => 'TRUE' },
            { name => 'email_alerts_requested', value => 'FALSE' },
            { name => 'requested_datetime', value => re(qr/^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/) },
            { name => 'email', value => TEST_USER_EMAIL },
            { name => 'last_name', value => 'Bloggs' },
        ),
    });

test_overrides bromley =>
    {
        body_name => 'Bromley',
        body_id   => 2482,
        row_data  => {
            postcode => 'BR1 1AA',
            extra => [ { name => 'last_name', value => 'Bloggs' } ],
        },
        extra => {
            northing => 100,
            easting => 100,
            url => 'http://example.com/1234',
        },
    },
    $bromley_check;

test_overrides fixmystreet =>
    {
        body_name => 'Bromley',
        body_id   => 2482,
        row_data  => {
            postcode => 'BR1 1AA',
            # NB: we don't pass last_name here, as main cobrand doesn't know to do this!
        },
        extra => {
            northing => 100,
            easting => 100,
            url => 'http://example.com/1234',
        },
    },
    $bromley_check;

test_overrides greenwich =>
    {
        body_name => 'Greenwich',
        body_id   => 2493,
    },
    superhashof({
        handler => isa('FixMyStreet::Cobrand::Greenwich'),
        'open311' => noclass(superhashof({
            %standard_open311_parameters,
        })),
        problem_extra => bag(
            { name => 'external_id', value => re('[0-9]+') },
        ),
    });

test_overrides fixmystreet =>
    {
        body_name => 'West Berkshire',
        body_id   => 2619,
        row_data  => {
            postcode => 'RG1 1AA',
        },
    },
    superhashof({
        handler => isa('FixMyStreet::Cobrand::WestBerkshire'),
        'open311' => noclass(superhashof({
            %standard_open311_parameters,
            'endpoints' => {
                'requests' => 'Requests',
                'services' => 'Services',
            },
        })),
    });

sub test_overrides {
    # NB: Open311 and ::SendReport::Open311 are mocked below in BEGIN { ... }
    my ($cobrand, $input, $expected_data) = @_;
    subtest "$cobrand ($input->{body_name}) overrides" => sub {

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => ['fixmystreet', 'oxfordshire', 'bromley', 'westberkshire', 'greenwich'],
        }, sub {
            my $db = FixMyStreet::DB->schema;
            #$db->txn_begin;

            my $params = { id => $input->{body_id}, name => $input->{body_name} };
            my $body = $db->resultset('Body')->find_or_create($params);
            $body->body_areas->find_or_create({ area_id => $input->{body_id} });
            ok $body, "found/created body " . $input->{body_name};
            $body->update({ can_be_devolved => 1 });

            my $contact = $body->contacts->find_or_create(
                state => 'confirmed',
                email => 'ZZ',
                category => 'ZZ',
                editor => 'test suite',
                note => '',
                whenedited => DateTime->now,
                jurisdiction => '1234',
                api_key => 'SEEKRIT',
                body_id => $input->{body_id},
            );
            $contact->update({ send_method => 'Open311', endpoint => 'http://example.com/open311' });

            my $user = $db->resultset('User')->find_or_create( {
                    name => 'Fred Bloggs',
                    email => TEST_USER_EMAIL,
                    password => 'dummy',
            });

            my $row = $db->resultset('Problem')->create( {
                title => 'Problem',
                detail => 'A big problem',
                used_map => 1,
                name => 'Fred Bloggs',
                anonymous => 1,
                state => 'unconfirmed',
                bodies_str => $input->{body_id},
                areas => (sprintf ',%d,', $input->{body_id}),
                category => 'ZZ',
                cobrand => $cobrand,
                user => $user,
                postcode => 'ZZ1 1AA',
                latitude => 100,
                longitude => 100,
                confirmed => DateTime->now(),
                %{ $input->{row_data} || {} },
            } );

            my $sr = FixMyStreet::SendReport::Open311->new;
            $sr->add_body($body, $contact);
            $sr->send( $row, $input->{extra} || {} );

            cmp_deeply (Open311->_get_test_data, $expected_data, 'Data as expected')
                or diag Dumper( Open311->_get_test_data );

            Open311->_reset_test_data();
            #$db->txn_rollback;
        };
    }
}

BEGIN {
    # Prepare the %data variable to write data from Open311 calls to...
    my %data;
    package Open311;
    use Class::Method::Modifiers;
    around new => sub {
        my $orig = shift;
        my ($class, %params) = @_;
        my $self = $class->$orig(%params);
        $data{open311} = $self;
        $self;
    };
    around send_service_request => sub {
        my $orig = shift;
        my ($self, $problem, $extra, $service_code) = @_;
        $data{problem} = { $problem->get_columns };
        $data{extra} = $extra;
        $data{problem_extra} = $problem->get_extra_fields;
        $data{problem_user} = { $problem->user->get_columns };
        $data{service_code} = $service_code;
        # don't actually send the service request!
    };

    sub _get_test_data { return +{ %data } }
    sub _reset_test_data { %data = () }

    package FixMyStreet::DB::Result::Problem;
    use Class::Method::Modifiers; # is marked as immutable by Moose
    sub discard_changes {
        $data{discard_changes}++;
        # no need to actually discard, as we're in transaction anyway
    };

    package FixMyStreet::DB::Result::Body;
    use Class::Method::Modifiers; # is marked as immutable by Moose
    around get_cobrand_handler => sub {
        my $orig = shift;
        my ($self) = @_;
        my $handler = $self->$orig();
        $data{handler} = $handler;
        $handler;
    };
}

done_testing();
