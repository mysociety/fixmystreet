use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my ($problem) = $mech->create_problems_for_body(1, 2504, 'title');
my $update = $mech->create_comment_for_problem($problem, $problem->user, 'Name', 'Text', 'f', 'confirmed', 'confirmed');

subtest 'not visible on live site' => sub {
    FixMyStreet::override_config {
        STAGING_SITE => 0
    }, sub {
        $mech->get('/_dev/email/');
        is $mech->res->code, 404;
        $mech->get('/_dev/email/login');
        is $mech->res->code, 404;
    };
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

done_testing();
