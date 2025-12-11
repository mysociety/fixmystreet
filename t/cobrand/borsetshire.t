use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok( 2608, 'Borsetshire Council');
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params);
    $contact->set_extra_metadata(type => 'waste');
    $contact->set_extra_fields(@extra);
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed' });

subtest 'check display of waste category' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'borsetshire',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/around?latitude=51.496194&longitude=-2.603439');
    };
    $mech->content_lacks('Report missed collection');
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'borsetshire',
    COBRAND_FEATURES => { waste => { borsetshire => 1 } },
}, sub {
    subtest 'Address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'BR1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '1' } });
        $mech->content_contains('1 Example Street');
        $mech->content_contains('Blue bin');
    };
};

done_testing;
