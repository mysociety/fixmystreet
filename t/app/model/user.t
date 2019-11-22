use FixMyStreet::TestMech;
use FixMyStreet::DB;
use Catalyst::Test 'FixMyStreet::App';
use HTTP::Request::Common;
use Test::Exception;

my $mech = FixMyStreet::TestMech->new();
$mech->log_in_ok('test@example.com');

my ($problem) = $mech->create_problems_for_body(1, '2504', 'Title', { anonymous => 'f' });
is $problem->user->latest_anonymity, 0, "User's last report was not anonymous";

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/around?pc=sw1a1aa');
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->content_like(qr/may_show_name[^>]*checked/);
};

($problem) = $mech->create_problems_for_body(1, '2504', 'Title', { anonymous => 't' });
is $problem->user->latest_anonymity, 1, "User's last report was anonymous";

create_update($problem, anonymous => 'f');
is $problem->user->latest_anonymity, 0, "User's last update was not anonyous";

create_update($problem, anonymous => 't');
is $problem->user->latest_anonymity, 1, "User's last update was anonymous";

subtest "Sign user up for alerts" => sub {
    my $user = $problem->user;

    my $alert_exists =  $user->alert_for_problem( $problem->id );
    is !defined( $alert_exists ), 1, "No current alerts exist";

    my $options = {
      cobrand      => 'default',
      lang         => 'en-gb',
    };
    $user->create_alert($problem->id, $options);
    my $alert = $user->alert_for_problem( $problem->id );

    is defined( $alert ), 1, "User is signed up for alerts";
    is $alert->confirmed, 1, "Alert is confirmed";

    $alert->delete();

    $user->alerts->create({
        alert_type   => 'new_updates',
        parameter    => $problem->id,
    });

    $user->create_alert($problem->id, $options);

    my $new_alert = $user->alert_for_problem( $problem->id );
    is $alert->confirmed, 1, "Already created alert is confirmed";
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/around?pc=sw1a1aa');
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->content_like(qr/may_show_name[^>c]*>/);
};

subtest 'Check non-existent methods on user object die' => sub {
    my $c = ctx_request(POST '/auth', { username => $problem->user->email, password_sign_in => 'secret' });
    throws_ok(
        sub { $c->user->is_super_user },
        qr/Can't locate object method 'is_super_user'/,
        'attempt to call non-existent method'
    );
};

subtest 'OIDC ids can be manipulated correctly' => sub {
    my $user = $problem->user;

    is $user->oidc_ids, undef, 'user starts with no OIDC ids';

    $user->add_oidc_id("fixmystreet:1234:5678");
    is_deeply $user->oidc_ids, ["fixmystreet:1234:5678"], 'OIDC id added correctly';

    $user->add_oidc_id("mycobrand:0123:abcd");
    is_deeply [ sort @{$user->oidc_ids} ], ["fixmystreet:1234:5678", "mycobrand:0123:abcd"], 'Second OIDC id added correctly';

    $user->add_oidc_id("mycobrand:0123:abcd");
    is_deeply [ sort @{$user->oidc_ids} ], ["fixmystreet:1234:5678", "mycobrand:0123:abcd"], 'Adding existing OIDC id does not add duplicate';

    $user->remove_oidc_id("mycobrand:0123:abcd");
    is_deeply $user->oidc_ids, ["fixmystreet:1234:5678"], 'OIDC id can be removed OK';

    $user->remove_oidc_id("mycobrand:0123:abcd");
    is_deeply $user->oidc_ids, ["fixmystreet:1234:5678"], 'Removing non-existent OIDC id has no effect';

    $user->remove_oidc_id("fixmystreet:1234:5678");
    is $user->oidc_ids, undef, 'Removing last OIDC id results in undef';

};

done_testing();

sub create_update {
    my ($problem, %params) = @_;
    my $dt = DateTime->now()->add(days => 1);
    return FixMyStreet::DB->resultset('Comment')->find_or_create({
        problem_id => $problem->id,
        user_id => $problem->user_id,
        name => 'Other User',
        mark_fixed => 'false',
        text => 'This is some update text',
        state => 'confirmed',
        anonymous => 'f',
        created => $dt->ymd . ' ' . $dt->hms,
        %params,
    });
}
