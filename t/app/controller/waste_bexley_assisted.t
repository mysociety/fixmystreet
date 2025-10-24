use Test::Deep;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;
use t::Mock::Bexley;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(
    2494,
    'London Borough of Bexley',
    { cobrand => 'bexley' },
);
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');

my $contact = $mech->create_contact_ok(
    body => $body,
    category => 'Assisted collection remove',
    email => 'assistedremove@example.org',
    extra => {
        type => 'waste',
        _fields => [ {
            code => "uprn",
            required => "false",
            automated => "hidden_field",
            description => "UPRN reference",
        }, {
            code => "notes",
            required => "false",
            datatype => 'text',
            description => "Notes",
        } ],
    },
    group => ['Waste'],
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        whitespace => { bexley => { url => 'http://example.org/' } },
        waste => { bexley => 1 },
    },
}, sub {
    subtest 'Correct services are shown for address, that is assisted' => sub {
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Remove assisted collection');
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/10001');
        $mech->follow_link_ok({ text => 'Remove assisted collection' });
        $mech->submit_form_ok({ with_fields => { extra_notes => 'Notes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org' } });
        $mech->submit_form_ok({ with_fields => { submit => "Submit" } });;
        $mech->content_contains('Your enquiry has been submitted');
    };
};

done_testing;
