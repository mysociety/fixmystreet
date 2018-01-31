use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

$mech->log_in_ok( $user->email );

subtest 'basic states admin' => sub {
    $mech->get_ok('/admin/states');
    $mech->submit_form_ok({ button => 'new', with_fields => { label => 'third party', type => 'closed', name => 'Third party referral' } });
    $mech->content_contains('Third party referral');
    $mech->content_contains('Fixed');
    $mech->submit_form_ok({ button => 'delete:fixed' });
    $mech->content_lacks('Fixed');
    $mech->submit_form_ok({ form_number => 2, button => 'new_fixed' });
    $mech->content_contains('Fixed');
    $mech->submit_form_ok({ with_fields => { 'name:third party' => 'Third party incident' } });
    $mech->content_contains('Third party incident');
};

# TODO Language tests

done_testing;
