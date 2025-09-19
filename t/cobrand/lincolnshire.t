use FixMyStreet::TestMech;
use Open311::GetServiceRequests;
use FixMyStreet::DB;
use Open311;
use FixMyStreet::Script::CSVExport;
use File::Temp 'tempdir';

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
    cobrand => 'lincolnshire',
};
my $body = $mech->create_body_ok(2232, 'Lincolnshire County Council', $params);
my $lincs_user = $mech->create_user_ok('lincs@example.org', name => 'Lincolnshire User', from_body => $body);
my $superuser = $mech->create_user_ok('super@example.org', name => 'Super User', is_superuser => 1, email_verified => 1);
my $superuser_email = $superuser->email;
my $user_email = 'john.smith@example.com';
my $user2 = $mech->create_user_ok('john.smith.2@example.com');

my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
my $update = Open311::GetServiceRequests->new(
    system_user => $lincs_user,
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'lincolnshire',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_SITE => 0,
}, sub {
    subtest "custom homepage text" => sub {
        $mech->get_ok('/');
        $mech->content_contains('like potholes, broken paving slabs, street lighting, or flooding');
    };

    subtest "fetching problems from Open311 includes user information" => sub {
        my $requests_xml = xml_reports({ id => 123, name => 'John Smith', email => $user_email });
        Open311->_inject_response('/requests.xml', $requests_xml);
        my $args = $update->format_args;
        my $requests = $update->get_requests($o, $body, $args);
        $update->create_problems( $o, $body, $args, $requests );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-123' },
            { prefetch => 'user' },
        )->first;

        ok $p, 'Found problem';
        is $p->name, 'John Smith', 'Name set on problem';
        is $p->user->name, 'John Smith', 'correct user associated with problem';
        is $p->user->email, $user_email, 'correct email associated with problem';

        # Check user has been sent the logged email
        my $email = $mech->get_email;
        is $email->header('To'), $p->user->email, 'email sent to correct address';
        is $email->header('Subject'), 'Your report has been logged: Street light not working problem', 'email has correct subject';
        my $problem_id = $p->id;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Your report to Lincolnshire County Council has been logged/;
        like $body, qr/lincs-123/;
        like $body, qr{http://[^/]+/report/$problem_id}, 'email contains correct link';

        $mech->get_ok("/report/" . $p->id, 'Problem page loaded');
        $mech->content_lacks('John Smith', 'Name not shown on problem page');

        $mech->delete_user($user_email);
    };

    subtest "ignores user information if name is missing" => sub {
        my $requests_xml = xml_reports({ id => 456, name => '', email => $user_email });
        Open311->_inject_response('/requests.xml', $requests_xml);
        my $args = $update->format_args;
        my $requests = $update->get_requests($o, $body, $args);
        $update->create_problems( $o, $body, $args, $requests );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-456' },
            { prefetch => 'user' },
        )->first;

        ok $p, 'Found problem';
        is $p->name, $lincs_user->name, 'Name set on problem';
        is $p->user->name, $lincs_user->name, 'correct user associated with problem';
        is $p->user->email, $lincs_user->email, 'correct email associated with problem';

        $p->delete;
    };

    subtest "is okay if account exists with no name" => sub {
        my $requests_xml = xml_reports({ id => 456, name => 'John Smith', email => $user2->email });
        Open311->_inject_response('/requests.xml', $requests_xml);
        my $args = $update->format_args;
        my $requests = $update->get_requests($o, $body, $args);
        $update->create_problems( $o, $body, $args, $requests );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-456' },
            { prefetch => 'user' },
        )->first;

        $user2->discard_changes;
        ok $p, 'Found problem';
        is $p->name, $user2->name, 'Name set on problem';
        is $p->user->name, $user2->name, 'correct user associated with problem';
        is $p->user->email, $user2->email, 'correct email associated with problem';

        $p->delete;
    };
};

subtest 'Dashboard CSV export includes extra staff columns' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'lincolnshire',
        MAPIT_URL => 'http://mapit.uk/',
        STAGING_SITE => 0,
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        my $csv_staff = $mech->create_user_ok(
            'csvstaff@lincolnshire.gov.uk',
            name => 'CSV Staff',
            from_body => $body,
        );
        my $csv_role = FixMyStreet::DB->resultset("Role")->create({
            body => $body,
            name => 'CSV Role',
            permissions => ['moderate', 'user_edit'],
        });
        $csv_staff->add_to_roles($csv_role);

        my @csv_problems = $mech->create_problems_for_body( 1, $body->id, 'CSV Export Test Issue', {
            cobrand => 'lincolnshire',
            user => $csv_staff,
            extra => { contributed_by => $csv_staff->id },
        });
        my $report = $csv_problems[0];
        my $user_id = $csv_staff->id;

        $report->discard_changes;

        $mech->log_in_ok($csv_staff->email);
        $mech->get_ok('/dashboard?export=1');

        $mech->content_contains('"Staff Role"', "Staff Role column header before export");
        $mech->content_like(qr/CSV Role/, "CSV export includes staff role before export");
        $mech->content_contains('"User Id"', "User Id column header before export");
        $mech->content_like(qr/,$user_id$/, "User Id data before export");

        $report->confirmed(DateTime->now->subtract( days => 5 ));
        $report->update;

        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Staff Role"', "Staff Role column header after export");
        $mech->content_like(qr/CSV Role/, "CSV export includes staff role after export");
        $mech->content_contains('"User Id"', "User Id column header after export");
        $mech->content_like(qr/,$user_id$/, "User Id data after export");
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'lincolnshire',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_SITE => 1,
}, sub {
    subtest "fetching problems from Open311 on staging doesn't include private user information" => sub {
        my $requests_xml = xml_reports({ id => 123, name => 'John Smith', email => $user_email });
        Open311->_inject_response('/requests.xml', $requests_xml);
        my $args = $update->format_args;
        my $requests = $update->get_requests($o, $body, $args);
        $update->create_problems( $o, $body, $args, $requests );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-123' },
            { prefetch => 'user' },
        )->first;
        ok $p, 'Found problem';
        is $p->name, $lincs_user->name, 'Name set on problem';
        is $p->user->name, $lincs_user->name, 'correct user associated with problem';
        is $p->user->email, $lincs_user->email, 'correct email associated with problem';

        is(FixMyStreet::DB->resultset('User')->search({ email => $user_email })->count, 0, "User wasn't created");
    };

    subtest 'fetching problems from Open311 on staging stores user info for @lincolnshire.gov.uk addresses' => sub {
        my $requests_xml = xml_reports({ id => 124, name => 'Simon Neil', email => 'blackhole@lincolnshire.gov.uk' });
        Open311->_inject_response('/requests.xml', $requests_xml);
        my $args = $update->format_args;
        my $requests = $update->get_requests($o, $body, $args);
        $update->create_problems( $o, $body, $args, $requests );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-124' },
            { prefetch => 'user' },
        )->first;
        ok $p, 'Found problem';
        is $p->name, "Simon Neil", 'Name set on problem';
        is $p->user->name, "Simon Neil", 'correct user associated with problem';
        is $p->user->email, 'blackhole@lincolnshire.gov.uk', 'correct email associated with problem';
    };

    subtest 'fetching problems from Open311 on staging stores user info for extant superusers' => sub {
        my $requests_xml = xml_reports({ id => 125, name => 'Super Duper', email => $superuser_email });
        Open311->_inject_response('/requests.xml', $requests_xml);
        my $args = $update->format_args;
        my $requests = $update->get_requests($o, $body, $args);
        $update->create_problems( $o, $body, $args, $requests );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-125' },
            { prefetch => 'user' },
        )->first;
        ok $p, 'Found problem';
        is $p->name, "Super User", "Existing user's name set on problem";
        is $p->user->name, "Super User", "Super user's name not changed";
        is $p->user->email, $superuser_email, 'correct email associated with problem';
    };
};

sub xml_reports {
    my @reports = map { xml_report($_) } @_;
    my $requests_xml = '<?xml version="1.0" encoding="UTF-8"?><service_requests>'
        . join('', @reports) . '</service_requests>';
    my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
    $requests_xml =~ s/DATETIME/$dt/gm;
    return $requests_xml;
}

sub xml_report {
    my $data = shift;
    return qq{
    <request>
        <service_request_id>lincs-$data->{id}</service_request_id>
        <contact_name>$data->{name}</contact_name>
        <contact_email>$data->{email}</contact_email>
        <status>open</status>
        <service_name>Street light not working</service_name>
        <description>Street light not working</description>
        <requested_datetime>DATETIME</requested_datetime>
        <updated_datetime>DATETIME</updated_datetime>
        <address>1 Street</address>
        <lat>52.656144</lat>
        <long>-0.502566</long>
    </request>
    };
}

done_testing();
