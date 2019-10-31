use utf8;
use FixMyStreet::Script::UpdateAllReports;

use Test::MockModule;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $resolver = Test::MockModule->new('Email::Valid');
$resolver->mock('address', sub { $_[1] });

my $body = $mech->create_body_ok( 2514, 'Birmingham' );

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Traffic lights',
    email => 'lights@example.com'
);

my $data;
FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $data = FixMyStreet::Script::UpdateAllReports::generate_dashboard($body);
};

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    TEST_DASHBOARD_DATA => $data,
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest 'check marketing dashboard access' => sub {
        # Not logged in, redirected
        $mech->get_ok('/reports/Birmingham/summary');
        is $mech->uri->path, '/about/council-dashboard';

        $mech->submit_form_ok({ with_fields => { username => 'someone@somewhere.example.org' }});
        $mech->content_contains('did not recognise your email');

        $mech->log_in_ok('someone@somewhere.example.org');
        $mech->get_ok('/reports/Birmingham/summary');
        is $mech->uri->path, '/about/council-dashboard';
        $mech->content_contains('Ending in .gov.uk');

        $mech->submit_form_ok({ with_fields => { name => 'Someone', username => 'someone@birmingham.gov.uk' }});
        $mech->content_contains('Now check your email');
        # XXX Check email arrives, click link

        $mech->log_in_ok('someone@birmingham.gov.uk');
        # Logged in, redirects
        $mech->get_ok('/about/council-dashboard');
        is $mech->uri->path, '/reports/Birmingham/summary';
        $mech->content_contains('Where we send Birmingham');
        $mech->content_contains('lights@example.com');
    };

    subtest 'check marketing dashboard csv' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        $mech->create_problems_for_body(105, $body->id, 'Titlē', {
            detail => "this report\nis split across\nseveral lines",
            areas => ",2514,",
        });

        $mech->get_ok('/reports/Birmingham/summary?csv=1');
        my @rows = $mech->content_as_csv;
        is scalar @rows, 101, '1 (header) + 100 (reports) = 101 lines';

        is scalar @{$rows[0]}, 10, '10 columns present';

        is_deeply $rows[0],
            [
                'Report ID',
                'Title',
                'Category',
                'Created',
                'Confirmed',
                'Status',
                'Latitude',
                'Longitude',
                'Query',
                'Report URL',
            ],
            'Column headers look correct';

        my $body_id = $body->id;
        like $rows[1]->[1], qr/Titlē Test \d+ for $body_id/, 'problem title correct';
    };

    subtest 'check marketing dashboard contact listings' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        $body->send_method('Open311');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Reports to Birmingham are currently sent directly');

        $body->send_method('Refused');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Birmingham currently does not accept');

        $body->send_method('Noop');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Reports are currently not being sent');

        $mech->log_out_ok();
        $mech->get_ok('/reports');
        $mech->content_lacks('Where we send Birmingham');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest 'test enforced 2FA for superusers' => sub {
        my $test_email = 'test@example.com';
        my $user = FixMyStreet::DB->resultset('User')->find_or_create({ email => $test_email });
        $user->password('password');
        $user->is_superuser(1);
        $user->update;

        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $test_email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('requires two-factor');
    };
};

done_testing();
