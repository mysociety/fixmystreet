use FixMyStreet::TestMech;
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
    subtest 'Remove assisted collection flow, logged out' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Remove assisted collection');
    };

    subtest 'Remove assisted collection flow, staff' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/10001');
        $mech->follow_link_ok({ text => 'Remove assisted collection' });
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org' } });
        $mech->submit_form_ok({ with_fields => { submit => "Submit" } });;
        $mech->content_contains('Your enquiry has been submitted');
    };
};

done_testing;
