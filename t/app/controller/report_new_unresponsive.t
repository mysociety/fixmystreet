use FixMyStreet::TestMech;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body_edin = $mech->create_body_ok(2651, 'City of Edinburgh Council', { send_method => 'Refused' });
my $body_chelt = $mech->create_body_ok(2326, 'Cheltenham Borough Council');
$mech->create_contact_ok(body_id => $body_edin->id, category => 'Street lighting', email => 'highways@example.com');
my $contact = $mech->create_contact_ok(body_id => $body_chelt->id, category => 'Trees', email => 'trees@example.org');
$mech->create_contact_ok(body_id => $body_edin->id, category => 'Trees', email => 'trees@example.com');
my $user = $mech->create_user_ok('test-2@example.com');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "unresponsive body handling, body-level send method" => sub {
        my $body_id = $body_edin->id;
        my $extra_details = $mech->get_ok_json('/report/new/ajax?latitude=55.952055&longitude=-3.189579');
        like $extra_details->{top_message}, qr{Edinburgh.*accept reports.*/unresponsive\?body=$body_id};
        is_deeply $extra_details->{unresponsive}, { $body_id => 1 }, "unresponsive json set";
        $extra_details = $mech->get_ok_json('/report/new/category_extras?category=Street%20lighting&latitude=55.952055&longitude=-3.189579');
        is_deeply $extra_details->{unresponsive}, { $body_id => 1 }, "unresponsive json set";

        make_report('EH1 1BB');

        like $mech->get_text_body_from_email, qr/despite not being sent/i, "correct email sent";

        $user->problems->delete;
    };

    subtest "unresponsive body handling from mobile app" => sub {
        $mech->log_out_ok;
        $mech->post_ok( '/report/new/mobile', {
            title               => "Test Report at café",
            detail              => 'Test report details.',
            photo1              => '',
            name                => 'Joe Bloggs',
            email               => $user->email,
            may_show_name       => '1',
            phone               => '07903 123 456',
            category            => 'Trees',
            service             => 'iOS',
            lat                 => 55.952055,
            lon                 => -3.189579,
            pc                  => '',
            used_map            => '1',
            submit_register     => '1',
            password_register   => '',
        });
        my $res = $mech->response;
        ok $res->header('Content-Type') =~ m{^application/json\b}, 'response should be json';

        my $report = $user->problems->first;
        ok $report, "Found the report";
        is $report->bodies_str, undef, "Report not going anywhere";

        like $mech->get_text_body_from_email, qr/despite not being sent/i, "correct email sent";

        $body_edin->update({ send_method => undef });
        $user->problems->delete;
    };

    subtest "unresponsive body handling, per-category refusing" => sub {
        $contact->update({ email => 'REFUSED' });
        my $extra_details = $mech->get_ok_json('/report/new/ajax?latitude=51.896268&longitude=-2.093063');
        like $extra_details->{by_category}{Trees}{category_extra}, qr/Cheltenham.*Trees.*unresponsive.*category=Trees/s;
        $extra_details = $mech->get_ok_json('/report/new/category_extras?category=Trees&latitude=51.896268&longitude=-2.093063');
        is_deeply $extra_details->{unresponsive}, { $body_chelt->id => 1 }, "unresponsive json set";

        make_report('GL50 2PR');

        $contact->update({ email => 'trees@example.org' });
    };

    subtest "unresponsive body page works" => sub {
        my $url = "/unresponsive?body=" . $body_edin->id;
        is $mech->get($url)->code, 404, "page not found";
        $body_edin->update({ send_method => 'Refused' });
        $mech->get_ok($url);
        $mech->content_contains('Edinburgh');
        $body_edin->update({ send_method => undef });

        $url = "/unresponsive?body=" . $body_chelt->id . ";category=Trees";
        is $mech->get($url)->code, 404, "page not found";
        $contact->update({ email => 'REFUSED' });
        $mech->get_ok($url);
        $mech->content_contains('Cheltenham');
        $mech->content_contains('Trees');
    };
};

done_testing;

sub make_report {
    my $pc = shift;
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => $pc } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            with_fields => {
                title         => "Test Report at café",
                detail        => 'Test report details.',
                photo1        => '',
                name          => 'Joe Bloggs',
                username      => $user->email,
                may_show_name => '1',
                phone         => '07903 123 456',
                category      => 'Trees',
            }
        },
        "submit good details"
    );

    my $report = $user->problems->first;
    ok $report, "Found the report";
    is $report->bodies_str, undef, "Report not going anywhere";
}
