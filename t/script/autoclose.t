use FixMyStreet::TestMech;

use_ok 'FixMyStreet::Script::UK::AutoClose';

my $mech = FixMyStreet::TestMech->new;
my $user = $mech->create_user_ok('systemuser@example.com');
my $body = $mech->create_body_ok(163793, 'Buckinghamshire Council', { comment_user => $user, cobrand => "buckinghamshire" });
$mech->create_contact_ok(category => 'Flytipping (off-road)', body => $body, email => 'fly');
my $noise = $mech->create_contact_ok(category => 'Noise report', body => $body, email => 'noise');
$body->add_to_response_templates({ title => 'Auto-closure', text => 'Auto closed' });
my $template = $body->add_to_response_templates({ title => 'Noise closure', text => 'Auto closed', state => 'closed', auto_response => 1 });
$template->add_to_contact_response_templates({ contact => $noise });

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

$ac = FixMyStreet::Script::UK::AutoClose->new(
    body_name => 'Buckinghamshire Council',
    category => 'Noise report',
    states => 'confirmed',
    to => 10,
);
$ac->close;

done_testing;
