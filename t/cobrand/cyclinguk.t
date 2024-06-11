use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::BathNES');
$cobrand->mock('area_types', sub { [ 'UTA' ] });

my $body = $mech->create_body_ok(2551, 'Bath and North East Somerset Council', {}, { cobrand => 'bathnes' });
my $cyclinguk = $mech->create_body_ok(2551, 'Cycling UK', {}, { cobrand => 'cyclinguk' });
$cyclinguk->body_areas->delete;

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'POTHOLE',
);

my $user = $mech->create_user_ok( 'bathnes@example.com', name => 'Public User 1' );
my $user2 = $mech->create_user_ok( 'anotheruser@example.com', name => 'Public User 2' );
my $staff = $mech->create_user_ok( 'staff@cyclinguk.org', name => 'Staff User 1' );
my $staff2 = $mech->create_user_ok( 'staff@anotherexample.org', name => 'Staff User 2' );
my $super = $mech->create_user_ok( 'super@example.com', name => 'Super User', is_superuser => 1 );

$staff->alerts->create({
    alert_type => 'council_problems',
    parameter => $body->id,
    whensubscribed => DateTime->now->subtract( hours => 1 ),
    cobrand => 'cyclinguk',
    confirmed => 1,
});

my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Potholes', cobrand => 'fixmystreet',
    user => $user,
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'cyclinguk' ],
    COBRAND_FEATURES => {
        base_url => {
            cyclinguk => "http://cyclinguk.fixmystreet.com/",
        },
    },
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { skip_must_have_2fa => 1 },
}, sub {

subtest 'cobrand front page looks OK' => sub {
    $mech->get_ok('/');
    $mech->content_contains("Fill That Hole");
    $mech->content_contains("Report or find a hazard");
    $mech->content_lacks("Report, view, or discuss local problems");
};

subtest '.com and council cobrand reports do not appear on site' => sub {
    $problem->update({ cobrand => 'fixmystreet'});
    $mech->get('/report/' . $problem->id);
    is $mech->res->code, 404;
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_lacks($problem->title);
    $mech->get_ok('/rss/problems');
    $mech->content_lacks($problem->title);
    $mech->log_in_ok($super->email);
    $mech->get('/admin/report_edit/' . $problem->id);
    is $mech->res->code, 404;
    $mech->log_out_ok;

    $problem->update({ cobrand => 'bathnes'});
    $mech->get('/report/' . $problem->id);
    is $mech->res->code, 404;
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_lacks($problem->title);
    $mech->get_ok('/rss/problems');
    $mech->content_lacks($problem->title);
    $mech->log_in_ok($super->email);
    $mech->get('/admin/report_edit/' . $problem->id);
    is $mech->res->code, 404;
    $mech->log_out_ok;
};

subtest 'cyclinguk cobrand reports do appear on site' => sub {
    $problem->update({ cobrand => 'cyclinguk'});
    $mech->get_ok('/report/' . $problem->id);
    $mech->content_contains($problem->title);
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_contains($problem->title);
};

$mech->log_in_ok($super->email);

subtest 'cyclinguk dashboard shows correct report data' => sub {
    $problem->update({ cobrand => 'fixmystreet'});
    $mech->get_ok("/dashboard");
    $mech->content_like(qr{th scope="row">Total</th>\s*<td>0</td>}, ".com reports not shown in dashboard");

    $problem->update({ cobrand => 'bathnes'});
    $mech->get_ok("/dashboard");
    $mech->content_like(qr{th scope="row">Total</th>\s*<td>0</td>}, "council cobrand reports not shown in dashboard");

    $problem->update({ cobrand => 'cyclinguk'});
    $mech->get_ok("/dashboard");
    $mech->content_like(qr{th scope="row">Total</th>\s*<td>1</td>}, "cyclinguk cobrand reports are shown in dashboard");
};

subtest 'cyclinguk dashboard shows correct bodies' => sub {
    $mech->get_ok("/dashboard");
    $mech->content_contains("<option value=''>All</option>");
    $mech->content_contains('<option value="' . $body->id . '">Bath and North East Somerset Council</option>');
};

my ($problem2, $problem3);
subtest 'Admin users limited correctly' => sub {
    $mech->get_ok("/admin/users/" . $staff->id);
    $mech->content_contains($staff->name);

    $mech->get_ok("/admin/users/" . $user->id);
    $mech->content_contains($user->name);

    $mech->get("/admin/users/" . $staff2->id);
    is $mech->res->code, 404;
    $mech->content_contains("Page Not Found");

    $mech->get("/admin/users/" . $user2->id);
    is $mech->res->code, 404;
    $mech->content_contains("Page Not Found");

    $staff2->update({ from_body => $cyclinguk });
    $mech->get_ok("/admin/users/" . $staff2->id);
    $mech->content_contains($staff2->name);

    ($problem2) = $mech->create_problems_for_body(1, $body->id, 'Title', {
        areas => ",2651,", category => 'Potholes', cobrand => 'fixmystreet',
        user => $user2,
    });
    $mech->get("/admin/users/" . $user2->id);
    is $mech->res->code, 404;
    $mech->content_contains("Page Not Found");

    # If the user made a report via this cobrand they should appear
    $problem2->update({ cobrand => 'cyclinguk' });
    $mech->get_ok("/admin/users/" . $user2->id);
    $mech->content_contains($user2->name);

    # if they've not made a problem report via this cobrand but have made an
    # update on a report on this cobrand they'll appear
    $problem2->update({ cobrand => 'fixmystreet' });
    ($problem3) = $mech->create_problems_for_body(1, $body->id, 'Title', {
        areas => ",2651,", category => 'Potholes', cobrand => 'cyclinguk',
        user => $user,
    });
    $mech->get("/admin/users/" . $user2->id);
    is $mech->res->code, 404;
    $mech->content_contains("Page Not Found");
    $mech->create_comment_for_problem($problem3, $user2, $user2->name, 'This is a test comment', 0, 'confirmed', 'confirmed');
    $mech->get_ok("/admin/users/" . $user2->id);
    $mech->content_contains($user2->name);
};

$mech->log_out_ok;

subtest 'Test alerts working okay' => sub {
    FixMyStreet::Script::Alerts::send_other();
    my $text = $mech->get_text_body_from_email;
    like $text, qr{report/@{[$problem->id]}};
    unlike $text, qr{report/@{[$problem2->id]}};
    like $text, qr{report/@{[$problem3->id]}};
};

subtest 'New report user info fields' => sub {
    $mech->log_in_ok( $user->email );
    $mech->get_ok('/report/new?longitude=-2.364050&latitude=51.386269');
    $mech->content_lacks("form_phone");
    $mech->submit_form_ok(
        {
            button      => 'submit_register',
            with_fields => {
                title         => 'Test',
                detail        => 'Detail',
                photo1        => '',
                first_name    => "First",
                last_name    => "Last",
                may_show_name => '0',
                category      => 'Potholes',
            }
        },
        'submit report form ok'
    );
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    is $report->name, "First Last";
    $mech->log_out_ok;

    $mech->get_ok('/report/new?longitude=-2.364050&latitude=51.386269');
    $mech->submit_form_ok(
        {
            button      => 'submit_register',
            with_fields => {
                username_register      => 'brandnew@example.org',
                title         => 'Test',
                detail        => 'Detail',
                photo1        => '',
                first_name    => "Brand",
                last_name     => "New",
                may_show_name => '0',
                category      => 'Potholes',
                marketing_opt_in => '1'
            }
        },
        'submit report form ok'
    );
    $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    is $report->name, "Brand New";
    is $report->get_extra_metadata('CyclingUK_marketing_opt_in'), 'yes';

    $mech->get_ok('/report/new?longitude=-2.364050&latitude=51.386269');
    $mech->submit_form_ok(
        {
            button      => 'submit_register',
            with_fields => {
                username_register      => 'brandnew@example.org',
                title         => 'Test',
                detail        => 'Detail',
                photo1        => '',
                first_name    => "Brand",
                last_name     => "New",
                may_show_name => '0',
                category      => 'Potholes',
                marketing_opt_in => '0'
            }
        },
        'submit report form ok'
    );
    $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    is $report->name, "Brand New";
    is $report->get_extra_metadata('CyclingUK_marketing_opt_in'), 'no';
};

subtest 'Dashboard CSV export' => sub {
    $mech->log_in_ok($super->email);

    $mech->create_problems_for_body(1, $body->id, 'Title', {
        areas => ",2551,", category => 'Potholes', cobrand => 'cyclinguk',
        user => $user, extra => {
            _fields => [
                # these should not be included in the CSV export as they're from the contact's fields
                {
                    name => "width",
                    value => "10cm"
                },
                {
                    name => "depth",
                    value => "25cm"
                },
            ],
            "CyclingUK_injury_suffered" => "no",
            "CyclingUK_property_damage" => "yes",
            "CyclingUK_transport_mode" => "other",
            "CyclingUK_transport_other" => "horse",
            "CyclingUK_marketing_opt_in" => "yes",
        }
    });
    $mech->get_ok('/dashboard?export=1');
    $mech->content_contains('"Injury suffered?","Property damage?","Mode of transport","Mode of transport (other)","First name","Last name","User Email","Marketing opt-in?"');
    $mech->content_contains(',no,yes,other,horse,Test,User,' . $user->email . ',yes');
    $mech->content_lacks('10cm');
    $mech->content_lacks('25cm');
};

$mech->log_out_ok;

subtest 'Contact form' => sub {
    $mech->get_ok('/contact');
    $mech->submit_form_ok({ with_fields => {
        em      => 'test@example.com',
        name    => 'A name',
        subject => 'A subject',
        message => 'A message',
    }});
    $mech->content_contains("Thank you for your enquiry");
};

};

done_testing();
