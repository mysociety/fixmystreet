use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');
my $user2 = $mech->create_user_ok('test2@example.com', name => 'Test User 2');
my $superuser = $mech->create_user_ok(
    'superuser@example.com',
    name         => 'Super User',
    is_superuser => 1
);

my $iow = $mech->create_body_ok(2636, 'Isle of Wight Council', { can_be_devolved => 1 } );
my $iow_contact = $mech->create_contact_ok(
    body_id     => $iow->id,
    category    => 'Potholes',
    email       => 'potholes@example.com',
    send_method => 'Triage'
);
$mech->create_contact_ok(
    body_id  => $iow->id,
    category => 'Traffic lights',
    email    => 'lights@example.com'
);

my $dt = DateTime->now();

my ($report) = $mech->create_problems_for_body(
    1,
    $iow->id,
    'TITLE',
    {
        areas => 2636,
        category => 'Potholes',
        whensent => $dt,
        latitude => 50.71086,
        longitude => -1.29573,
        send_method_used => 'Triage',
    }
);

FixMyStreet::override_config {
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    ALLOWED_COBRANDS => [ 'isleofwight' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "user can access triage page with triage permission" => sub {
        $user->update({ from_body => $iow });
        $mech->log_out_ok;
        $mech->get_ok('/admin/triage');

        $mech->log_in_ok($user->email);
        $mech->get('/admin/triage');
        is $mech->res->code, 403, 'permission denied';

        $user->user_body_permissions->create( { body => $iow, permission_type => 'triage' } );
        $mech->get_ok('/admin/triage');
    };

    subtest "reports marked for triage show triage interface" => sub {
        $mech->log_out_ok;
        $mech->log_in_ok( $user->email );

        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('CONFIRM Subject');

        $report->update( { state => 'for triage' } );

        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('CONFIRM Subject');
    };

    subtest "changing report category marks report as confirmed" => sub {
        my $report_url = '/report/' . $report->id;
        $mech->get_ok($report_url);

        my $alert = FixMyStreet::DB->resultset('Alert')->create(
            {
                user       => $user2,
                alert_type => 'new_updates',
                parameter  => $report->id,
                parameter2 => '',
                confirmed => 1,
            }
        );

        $mech->content_contains('Traffic lights');

        $mech->submit_form_ok( {
                with_fields => {
                    category => 'Traffic lights',
                    include_update => 0,
                }
            },
            'triage form submitted'
        );

        $mech->content_contains('Potholes');

        $report->discard_changes;
        is $report->state, 'confirmed', 'report marked as confirmed';
        ok !$report->whensent, 'report marked to resend';

        my @comments = $report->comments;
        my $comment = $comments[0];
        my $extra = $comment->get_extra_metadata();
        is $extra->{triage_report}, 1, 'comment indicates it is for triage in extra';
        is $extra->{holding_category}, 'Potholes', 'comment extra has previous category';
        is $extra->{new_category}, 'Traffic lights', 'comment extra has new category';
        ok $comment->whensent, 'comment is marked as sent';

        $mech->get_ok($report_url);
        $mech->content_contains('Report triaged from Potholes to Traffic lights');

        $mech->log_out_ok;
        $mech->get_ok($report_url);
        $mech->content_lacks('Report triaged from Potholes to Traffic lights');

        $mech->clear_emails_ok;
        FixMyStreet::Script::Alerts::send();
        $mech->email_count_is(0);
    };
};

done_testing();
