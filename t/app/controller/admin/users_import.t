use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $body = $mech->create_body_ok(2509, 'Haringey Borough Council');

$mech->log_in_ok( $superuser->email );

my $body_id = $body->id;
my $csv = <<EOF;
name,email,from_body,permissions,roles
Adrian,adrian\@example.org,$body_id,moderate:user_edit,
Belinda,belinda\@example.org,$body_id,,Customer Service
EOF

FixMyStreet::DB->resultset("Role")->create({
    body => $body,
    name => 'Customer Service',
});

subtest 'import CSV file' => sub {
    $mech->get_ok('/admin/users/import');
    $mech->submit_form_ok({ with_fields => {
        csvfile => [ [ undef, 'foo.csv', Content => $csv ], 1],
    }});
    $mech->content_contains('Created 2 new users');
    my $a = FixMyStreet::DB->resultset("User")->find({ email => 'adrian@example.org' });
    is $a->user_body_permissions->count, 2;
    my $b = FixMyStreet::DB->resultset("User")->find({ email => 'belinda@example.org' });
    is $b->roles->count, 1;
};

done_testing();
