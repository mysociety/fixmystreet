use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my ($problem) = $mech->create_problems_for_body(1, 2504, 'title');
my $update = $mech->create_comment_for_problem($problem, $problem->user, 'Name', 'Text', 'f', 'confirmed', 'confirmed');

subtest 'not visible on live site' => sub {
    $mech->get('/_dev/');
    is $mech->res->code, 404;
    $mech->get('/_dev/email');
    is $mech->res->code, 404;
    $mech->get('/_dev/email/login');
    is $mech->res->code, 404;
};

$problem->user->update({ is_superuser => 1 });
$mech->log_in_ok($problem->user->email);

subtest 'dev index' => sub {
    $mech->get_ok('/_dev/');
    $mech->content_contains('<h1>/_dev</h1>');
};

subtest 'dev email index page' => sub {
    $mech->get_ok('/_dev/email/');
    $mech->content_contains('login">login</a></li>');
    $mech->content_contains('questionnaire?problem=' . $problem->id  . '">questionnaire</a></li>');
    $mech->content_contains('update-confirm?update=' . $update->id . '">update-confirm</a></li>');
};

subtest 'individual email previews' => sub {
    $mech->get_ok('/_dev/email/alert-problem-area');
    $mech->get_ok('/_dev/email/alert-update?problem=' . $problem->id);
    $mech->get_ok('/_dev/email/questionnaire?problem=' . $problem->id);
    $mech->get_ok('/_dev/email/update-confirm?update=' . $update->id);
};

subtest 'problem confirmation page preview' => sub {
    $mech->get_ok('/_dev/confirm_problem/' . $problem->id );
};

subtest 'update confirmation page preview' => sub {
    $mech->get_ok('/_dev/confirm_update/' . $problem->id);
};

subtest 'alert confirmation page preview' => sub {
    $mech->get_ok('/_dev/confirm_alert/subscribe');
};

subtest 'contact form submission page preview' => sub {
    $mech->get_ok('/_dev/contact_submit/1');
};

subtest 'questionnaire completion page previews' => sub {
    $mech->get_ok('/_dev/questionnaire_completed?been_fixed=Yes');
    $mech->get_ok('/_dev/questionnaire_completed?been_fixed=Unknown');
    $mech->get_ok('/_dev/questionnaire_completed?new_state=confirmed');
    $mech->get_ok('/_dev/questionnaire_creator_fixed');
};

done_testing();
