use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my');
is $mech->uri->path, '/auth', "got sent to the sign in page";

$mech->get_ok('/my/anonymize');
is $mech->uri->path, '/auth', "got sent to the sign in page";

my @problems = $mech->create_problems_for_body(3, 1234, 'Test Title');
$problems[1]->update({anonymous => 1});

my $other_user = FixMyStreet::DB->resultset('User')->find_or_create({ email => 'another@example.com' });
my @other = $mech->create_problems_for_body(1, 1234, 'Another Title', { user => $other_user });

my $user = $mech->log_in_ok( 'test@example.com' );
my @update;
my $i = 0;
my $staff_text = '<p>this is <script>how did this happen</script> <strong>an update</strong></p><ul><li>With</li><li>A</li><li>List</li></ul>';
foreach ($user, $user, $other_user) {
    $update[$i] = FixMyStreet::DB->resultset('Comment')->create({
        text => $staff_text,
        user => $_,
        state => 'confirmed',
        problem => $problems[0],
        mark_fixed => 0,
        confirmed => \'current_timestamp',
        anonymous => $i % 2,
    });
    $i++;
}

subtest 'Check loading of /my page' => sub {
    $mech->get_ok('/my');
    is $mech->uri->path, '/my', "stayed on '/my' page";

    $mech->content_contains('Test Title');
    $mech->content_lacks('Another Title');
    $mech->content_contains('&lt;p&gt;this is');
    $mech->content_lacks('<p>this is  <strong>an update</strong></p><ul><li>With');

    $update[0]->update({ extra => { is_superuser => 1 } });
    $mech->get_ok('/my');
    $mech->content_contains('<p>this is  <strong>an update</strong></p><ul><li>With');
};

foreach (
    { type => 'problem', id => 0, result => 404, desc => 'nothing' },
    { type => 'problem', obj => $problems[0], result => 200, desc => 'own report' },
    { type => 'problem', obj => $problems[1], result => 400, desc => 'already anon report' },
    { type => 'problem', obj => $other[0], result => 400, desc => 'other user report' },
    { type => 'update', id => -1, result => 400, desc => 'non-existent update' },
    { type => 'update', obj => $update[0], result => 200, desc => 'own update' },
    { type => 'update', obj => $update[1], result => 400, desc => 'already anon update' },
    { type => 'update', obj => $update[2], result => 400, desc => 'other user update' },
) {
    my $id = $_->{id} // $_->{obj}->id;
    $mech->get("/my/anonymize?$_->{type}=$id");
    is $mech->res->code, $_->{result}, "Got $_->{result} fetching $_->{desc}";
    if ($_->{result} == 200) {
        $mech->submit_form_ok( { button => 'hide' }, 'Submit button to hide name' );
        $_->{obj}->discard_changes;
        is $_->{obj}->anonymous, 1, 'Object now made anonymous';
        $_->{obj}->update({anonymous => 0});
    }
}

$mech->get("/my/anonymize?problem=" . $problems[0]->id);
$mech->submit_form_ok( { button => 'hide_everywhere' }, 'Submit button to hide name everywhere' );
is $problems[0]->discard_changes->anonymous, 1, 'Problem from form made anonymous';
is $problems[2]->discard_changes->anonymous, 1, 'Other user problem made anonymous';
is $update[0]->discard_changes->anonymous, 1, 'User update made anonymous';

subtest 'test setting of notification preferences' => sub {
    FixMyStreet::override_config {
        SMS_AUTHENTICATION => 1,
    }, sub {
        $mech->get_ok('/my/notify_preference');
        is $mech->uri->path, '/my';
        $mech->get_ok('/my');
        $mech->content_contains('id="update_notify_email" value="email" checked');
        $mech->content_lacks('id="update_notify_phone" value="phone"');
        $mech->content_contains('id="alert_notify_email" value="email" checked');
        $mech->submit_form_ok({ with_fields => { update_notify => 'none', alert_notify => 'none' } });
        $mech->content_contains('id="update_notify_none" value="none" checked');
        $mech->content_lacks('id="update_notify_phone" value="phone"');
        $mech->content_contains('id="alert_notify_none" value="none" checked');
        $user->update({ phone => '01234 567890', phone_verified => 1 });
        $mech->get_ok('/my');
        $mech->content_contains('id="update_notify_email" value="email">');
        $mech->content_contains('id="update_notify_phone" value="phone"');
        $mech->submit_form_ok({ with_fields => { update_notify => 'phone', alert_notify => 'email' } });
        $mech->content_contains('id="update_notify_phone" value="phone" checked');
        $mech->content_contains('id="alert_notify_email" value="email" checked');
        $user->update({ email_verified => 0 });
        $mech->get_ok('/my');
        $mech->content_lacks('id="update_notify_email" value="email"');
        $mech->content_contains('id="update_notify_phone" value="phone"');
        $mech->content_lacks('id="alert_notify_email" value="email"');
        $mech->submit_form_ok({ with_fields => { update_notify => 'phone', alert_notify => 'none' } });
        $mech->content_lacks('id="update_notify_email" value="email"');
        $mech->content_contains('id="update_notify_phone" value="phone" checked');
        $mech->content_lacks('id="alert_notify_email" value="email"');
        $mech->content_contains('id="alert_notify_none" value="none" checked');
    };
};

done_testing();
