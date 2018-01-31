use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

subtest "smoke view some stats pages" => sub {
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok('/admin/stats/fix-rate');
    $mech->get_ok('/admin/stats/questionnaire');
};

done_testing();
