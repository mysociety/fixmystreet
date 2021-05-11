use FixMyStreet::TestMech;

use_ok 'FixMyStreet::Script::UK::AutoClose';

my $mech = FixMyStreet::TestMech->new;
my $user = $mech->create_user_ok('systemuser@example.com');
my $body = $mech->create_body_ok(2217, 'Buckinghamshire Council', { comment_user => $user });
$mech->create_contact_ok(category => 'Flytipping (off-road)', body => $body, email => 'fly');
$body->add_to_response_templates({ title => 'Auto-closure', text => 'Auto closed' });

my $ac = FixMyStreet::Script::UK::AutoClose->new(
    body_name => 'Buckinghamshire Council',
    category => 'Flytipping (off-road)',
    commit => 0,
    retain_alerts => 1,
    from => 28,
    to => 14,
    template_title => 'Auto-closure',
);
$ac->close;

done_testing;
