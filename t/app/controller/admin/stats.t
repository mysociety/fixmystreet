use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

subtest "smoke view some stats pages" => sub {
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok('/admin/stats/fix-rate');
    $mech->get_ok('/admin/stats/questionnaire');
};

subtest "test refused stats page works" => sub {
    my $body1 = $mech->create_body_ok(2651, 'Edinburgh Council');
    my $body2 = $mech->create_body_ok(2237, 'Oxfordshire Council', { send_method  => 'Refused' });
    my $body3 = $mech->create_body_ok(2243, 'Warwickshire Council', { can_be_devolved => 1 });
    $mech->create_contact_ok(body_id => $body1->id, category => 'Street lighting', email => 'REFUSED');
    $mech->create_contact_ok(body_id => $body1->id, category => 'Potholes', email => 'potholes@example.org');
    $mech->create_contact_ok(body_id => $body2->id, category => 'Potholes', email => 'potholes@example.org');
    $mech->create_contact_ok(body_id => $body3->id, category => 'Street lighting', email => 'lights@example.org');
    $mech->create_contact_ok(body_id => $body3->id, category => 'Potholes', email => 'potholes@example.org', send_method => 'Refused');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    }, sub {
        $mech->get_ok('/admin/stats/refused');
    };
    $mech->content =~ /class="content"(.*)class="nav-wrapper/s;
    my @lines = split /<li>/, $1;
    is @lines, 7;
    like $lines[1], qr/Edinburgh/;
    like $lines[2], qr/Street lighting/;
    like $lines[3], qr/Oxfordshire/;
    like $lines[4], qr/ALL/;
    like $lines[5], qr/Warwickshire/;
    like $lines[6], qr/Potholes/;
};

done_testing();
