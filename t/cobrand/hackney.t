use CGI::Simple;
use DateTime;
use DateTime::Format::W3CDTF;
use File::Temp 'tempdir';
use JSON::MaybeXS;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Cobrand::Hackney;
use Open311;
use Open311::GetServiceRequests;
use Open311::GetServiceRequestUpdates;
use Open311::PostServiceRequestUpdates;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
    cobrand => 'hackney',
};

my $hackney = $mech->create_body_ok(2508, 'Hackney Council', $params);
my $contact = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Potholes & stuff',
    email => 'pothole@example.org',
    send_method => 'Email',
);
$contact->set_extra_fields( ( {
    code => 'urgent',
    datatype => 'string',
    description => 'question',
    variable => 'true',
    required => 'false',
    order => 1,
    datatype_description => 'datatype',
} ) );
$contact->update;

$mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Graffiti',
    email => 'Environment-Graffiti',
);
$contact = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Flytipping',
    email => 'Environment-Flytipping',
);
$contact->set_extra_fields( ( {
    code => 'flytip_size',
    datatype => 'string',
    description => 'Size of flytip?',
    variable => 'true',
    required => 'true',
    order => 1,
    datatype_description => 'datatype',
}, {
    code => 'flytip_type',
    datatype => 'string',
    description => 'Type of flytip?',
    variable => 'true',
    required => 'true',
    order => 2,
    datatype_description => 'datatype',
} ) );
$contact->update;

my $user = $mech->create_user_ok('user@example.org', name => 'Test User');
my $phone_user = $mech->create_user_ok('+447700900002');
my $hackney_user = $mech->create_user_ok('hackney_user@example.org', name => 'Hackney User', from_body => $hackney);
$hackney_user->user_body_permissions->create({ body => $hackney, permission_type => 'moderate' });
$hackney_user->user_body_permissions->create({ body => $hackney, permission_type => 'category_edit' });
$hackney_user->user_body_permissions->create({ body => $hackney, permission_type => 'report_edit' });

my $contact2 = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Roads',
    email => 'roads@example.org',
    send_method => 'Email',
);

my $admin_user = $mech->create_user_ok('admin-user@example.org', name => 'Admin User', from_body => $hackney);

my @reports = $mech->create_problems_for_body(1, $hackney->id, 'A Hackney report', {
    confirmed => '2019-10-25 09:00',
    lastupdate => '2019-10-25 09:00',
    latitude => 51.552267,
    longitude => -0.063316,
    user => $user,
    external_id => 101202303
});

subtest "check clicking all reports link" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney'],
    }, sub {
        $mech->get_ok('/');
        $mech->follow_link_ok({ text => 'All reports' });
    };

    $mech->content_contains("A Hackney report", "Hackney report there");
    $mech->content_contains("Hackney Council", "is still on cobrand");
};

subtest "check moderation label uses correct name" => sub {
    my $REPORT_URL = '/report/' . $reports[0]->id;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney'],
        COBRAND_FEATURES => {
            do_not_reply_email => {
                hackney => 'fms-hackney-DO-NOT-REPLY@hackney-example.com',
            },
            verp_email_domain => {
                hackney => 'hackney-example.com',
            },
        },
    }, sub {
        $mech->log_out_ok;
        $mech->log_in_ok( $hackney_user->email );
        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('show-moderation');
        $mech->follow_link_ok({ text_regex => qr/^Moderate$/ });
        $mech->content_contains('show-moderation');
        $mech->submit_form_ok({ with_fields => {
            problem_title  => 'Good good',
            problem_detail => 'Good good improved',
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );
        $mech->content_like(qr/Moderated by Hackney Council/);
    };
};

$_->delete for @reports;

my $system_user = $mech->create_user_ok('system_user@example.org');
my $dt = DateTime->now->set(hour => 13, minute => 0);

my ($p) = $mech->create_problems_for_body(1, $hackney->id, '', { cobrand => 'hackney' });
my $alert = FixMyStreet::DB->resultset('Alert')->create( {
    parameter  => $p->id,
    alert_type => 'new_updates',
    user       => $user,
    cobrand    => 'hackney',
    whensubscribed => $dt,
} )->confirm;

FixMyStreet::DB->resultset('Alert')->create( {
    parameter  => $p->id,
    alert_type => 'new_updates',
    user       => $phone_user,
    cobrand    => 'hackney',
    whensubscribed => $dt,
} )->confirm;

subtest "sends branded alert emails" => sub {
    $mech->create_comment_for_problem($p, $system_user, 'Other User', 'This is some update text', 'f', 'confirmed', undef, { confirmed => $dt });
    $mech->clear_emails_ok;

    my $mod_lwp = Test::MockModule->new('LWP::UserAgent');
    my $text_content;
    $mod_lwp->mock('post', sub {
        my ($self, $url, %args) = @_;
        my $data = decode_json($args{Content});
        $text_content = $data->{personalisation}{text};
        HTTP::Response->new(200, 'OK', [], '{ "id": 123 }');
    });

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney','fixmystreet'],
        COBRAND_FEATURES => {
            do_not_reply_email => { hackney => 'fms-hackney-DO-NOT-REPLY@hackney-example.com' },
            sms_authentication => { hackney => 1 },
            govuk_notify => { hackney => { key => 'test-0123456789abcdefghijklmnopqrstuvwxyz-key-goes-here' } },
        },
    }, sub {
        FixMyStreet::Script::Alerts::send_updates();
    };

    my $id = $p->id;
    like $text_content, qr{Your report \($id\) has had an update; to view: http://hackney.example.org/report/$id\n\nTo stop: http://hackney.example.org/A/[A-Za-z0-9]+};
    my $email = $mech->get_email;
    ok $email, "got an email";
    my $text = $mech->get_text_body_from_email($email);
    like $text, qr/Hackney Council/, "emails are branded";
    like $text, qr/\d\d:\d\d today/, "date is included";
};


subtest "All updates left on reports get emailed to Hackney" => sub {
    $p->set_extra_metadata(sent_to => ['hackneyservice@example.org']);
    $p->update;

    for my $cobrand ( 'hackney', 'fixmystreet' ) {
        subtest "Correct behaviour when update made on $cobrand cobrand" => sub {
            FixMyStreet::override_config {
                MAPIT_URL => 'http://mapit.uk/',
                ALLOWED_COBRANDS => $cobrand,
                COBRAND_FEATURES => {
                    do_not_reply_email => {
                        hackney => 'fms-hackney-DO-NOT-REPLY@hackney-example.com',
                    },
                    verp_email_domain => {
                        hackney => 'hackney-example.com',
                    },
                },
            }, sub {
                $mech->log_in_ok('testuser@example.org');
                $mech->clear_emails_ok();
                $p->comments->delete;

                my $id = $p->id;
                $mech->get_ok("/report/$id");

                my $values = $mech->visible_form_values('updateForm');

                $mech->submit_form_ok(
                    {
                        with_fields => {
                            submit_update => 1,
                            name => "Test User",
                            update => "this update was left on the $cobrand cobrand",
                            add_alert => undef,
                        }
                    },
                    'submit update'
                );

                is $p->comments->count, 1, "comment was added";

                my $email = $mech->get_email;
                my $body = $mech->get_text_body_from_email($email);
                like $body, qr/this update was left on the $cobrand cobrand/i, "Correct email text";
                my $title = $p->title;
                like $email->header('Subject'), qr/New Report A Problem updates on report: '$title'/, 'correct cobrand name in subject';
            };
        };
    }
    $p->comments->delete;
    $p->delete;
};

subtest "sends branded confirmation emails" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;
    $mech->get_ok('/?filter_category=Potholes+%26+stuff');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'hackney' ],
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            do_not_reply_email => {
                hackney => 'fms-hackney-DO-NOT-REPLY@hackney-example.com',
            },
            verp_email_domain => {
                hackney => 'hackney-example.com',
            },
        },
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'E8 1DY', } },
            "submit location" );

        # While we're here, check the category with an ampersand (regression test)
        $mech->content_contains('<option value="Potholes &amp; stuff" selected>');

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    username_register => 'test-1@example.com',
                    category      => 'Roads',
                }
            },
            "submit good details"
        );

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $mech->get_text_body_from_email($email), qr/Hackney Council/, "emails are branded";

        my $url = $mech->get_link_from_email($email);
        $mech->get_ok($url);
        $mech->clear_emails_ok;
    };
};

FixMyStreet::override_config {
    STAGING_FLAGS => { send_reports => 1 },
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => ['hackney', 'fixmystreet'],
    COBRAND_FEATURES => { environment_extra_fields => {
        hackney => [ 'flytip_size', 'flytip_type' ],
    } },
}, sub {
    subtest "special send handling" => sub {
        my $cbr = Test::MockModule->new('FixMyStreet::Cobrand::Hackney');
        my $p = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        my ($x, $y) = $p->local_coords;
        $contact2->update({ email => 'park:parks@example;estate:estates@example;other:OTHER', send_method => '' });

        subtest 'in a park' => sub {
            $cbr->mock('_fetch_features', sub {
                my ($self, $cfg) = @_;
                return [{
                    properties => { park_id => 'park' },
                    geometry => {
                        type => 'Polygon',
                        coordinates => [ [ [ $x-1, $y-1 ], [ $x+1, $y+1 ] ] ],
                    }
                }] if $cfg->{typename} eq 'greenspaces:hackney_park';
            });
            FixMyStreet::Script::Reports::send();
            my $email = $mech->get_email;
            is $email->header('To'), '"Hackney Council" <parks@example>';
            $mech->clear_emails_ok;
            $p->discard_changes;
            $p->resend;
            $p->update;
        };

        subtest 'in an estate' => sub {
            $cbr->mock('_fetch_features', sub {
                my ($self, $cfg) = @_;
                return [{
                    properties => { id => 'estate' },
                    geometry => {
                        type => 'Polygon',
                        coordinates => [ [ [ $x-1, $y-1 ], [ $x+1, $y+1 ] ] ],
                    }
                }] if $cfg->{typename} eq 'housing:lbh_estate';
            });
            FixMyStreet::Script::Reports::send();
            my $email = $mech->get_email;
            is $email->header('To'), '"Hackney Council" <estates@example>';
            $mech->clear_emails_ok;
            $p->discard_changes;
            $p->resend;
            $p->update;
        };

        subtest 'elsewhere' => sub {
            $cbr->mock('_fetch_features', sub {
                my ($self, $cfg, $x, $y) = @_;
                return []; # Not in park or estate
            });
            FixMyStreet::Script::Reports::send();
            my $req = Open311->test_req_used;
            my $c = CGI::Simple->new($req->content);
            is $c->param('service_code'), 'OTHER';
        };
        $contact2->update({ send_method => 'Email' }); # Switch back for next test
    };

    subtest "resending of reports by changing category" => sub {
        my ($problem) = $mech->create_problems_for_body(1, $hackney->id, '', {
            areas => ',2508,',
            #latitude => 51.552287,
            #longitude => -0.063326,
            cobrand => 'hackney',
            category => 'Roads',
            whensent => \'current_timestamp',
            send_state => 'sent',
        });
        my $whensent = $problem->whensent;
        $mech->log_in_ok( $hackney_user->email );
        $mech->get_ok('/admin/report_edit/' . $problem->id);
        foreach (
            { category => 'Potholes & stuff', resent => 1 }, # Email to email
            { category => 'Flytipping', resent => 1 }, # Email to non-email
            { category => 'Graffiti', resent => 0, }, # Non-email to non-email
            { category => 'Roads', resent => 1 }, # Non-email to email
        ) {
            $mech->submit_form_ok({ with_fields => { category => $_->{category} } }, "Switch to $_->{category}");
            $problem->discard_changes;
            if ($_->{resent}) {
                is $problem->send_state, 'unprocessed', "Marked for resending";
                $problem->update({ whensent => $whensent, send_method_used => 'Open311', send_state => 'sent' }); # reset as sent
            } else {
                is $problem->send_state, 'sent', "Not marked for resending";
            }
        }
    };

    subtest "Environment extra fields put in description" => sub {
        $mech->log_in_ok( $user->email );
        set_fixed_time('2021-08-06T10:00:00Z');
        $mech->get_ok("/");
        $mech->submit_form_ok( { with_fields => { pc => 'E8 1DY', } },
            "submit location" );


        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    name          => 'Joe Bloggs',
                    category      => 'Flytipping',
                }
            },
            "submit good details"
        );
        $mech->submit_form_ok(
            {
                with_fields => {
                    flytip_type   => 'Rubble',
                    flytip_size   => 'Lots',
                }
            },
            "submit extra details"
        );

        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'Environment-Flytipping';
        my $expected_title = "Test Report

Size of flytip?
Lots

Type of flytip?
Rubble";
        (my $c_title = $c->param('attribute[title]')) =~ s/\r\n/\n/g;
        is $c_title, $expected_title;

        my $p = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $c->param('attribute[requested_datetime]'), DateTime::Format::W3CDTF->format_datetime($p->confirmed->set_nanosecond(0));
    };
};

#subtest "sends branded report sent emails" => sub {
    #$mech->clear_emails_ok;
    #FixMyStreet::override_config {
        #STAGING_FLAGS => { send_reports => 1 },
        #MAPIT_URL => 'http://mapit.uk/',
        #ALLOWED_COBRANDS => ['hackney','fixmystreet'],
    #}, sub {
        #FixMyStreet::Script::Reports::send();
    #};
    #my $email = $mech->get_email;
    #ok $email, "got an email";
    #like $mech->get_text_body_from_email($email), qr/Hackney Council/, "emails are branded";
#};

subtest "check category extra uses correct name" => sub {
    my @extras = ( {
            code => 'test',
            datatype => 'string',
            description => 'question',
            variable => 'true',
            required => 'false',
            order => 1,
            datatype_description => 'datatype',
        } );
    $contact2->set_extra_fields( @extras );
    $contact2->update;

    my $extra_details;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney','fixmystreet'],
    }, sub {
        $extra_details = $mech->get_ok_json('/report/new/category_extras?category=Roads&latitude=51.552267&longitude=-0.063316');
    };

    like $extra_details->{category_extra}, qr/Hackney Council/, 'correct name in category extras';
};

subtest "can edit special destination email addresses" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney'],
        COBRAND_FEATURES => { anonymous_account => { hackney => 'anonymous' } },
    }, sub {
        $mech->log_in_ok( $hackney_user->email );
        $mech->get_ok("/admin/body/" . $hackney->id . "/" . $contact2->category);
        $mech->submit_form_ok( { with_fields => { email => 'park:parks@example.com;estate:estates@example;other:new@example.org' } },
            "submit valid new email address");
        $mech->content_lacks("Please enter a valid email");
        $contact2->discard_changes;
        is $contact2->email, 'park:parks@example.com;estate:estates@example;other:new@example.org', "New email addresses saved";

        $mech->get_ok("/admin/body/" . $hackney->id . "/" . $contact2->category);
        $mech->submit_form_ok( { with_fields => { email => 'invalid' } },
            "submit invalid new email address");
        $mech->content_contains("Please enter a valid email");
        $contact2->discard_changes;
        is $contact2->email, 'park:parks@example.com;estate:estates@example;other:new@example.org', "Invalid email addresses not saved";
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    my ($report) = $mech->create_problems_for_body(1, $hackney->id, 'A Hackney report', {
        latitude => 51.552267,
        longitude => -0.063316,
        cobrand => 'hackney',
        areas => ',2508,144390,',
        geocode => {
            resourceSets => [ {
                resources => [ {
                    address => {
                        formattedAddress => '12 A Street, XX1 1SZ',
                        addressLine => '12 A Street',
                        postalCode => 'XX1 1SZ'
                    }
                } ]
            } ]
        },
        extra => {
            detailed_information => "Some detailed information",
        },
    });

    $mech->log_in_ok( $hackney_user->email );
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'hackney',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Reported As","Nearest address","Nearest postcode","Extra details"');
        $mech->content_contains('hackney,,"12 A Street, XX1 1SZ","XX1 1SZ","Some detailed information"');

        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1&ward=144390');
        $mech->content_contains('Brownswood');
        $mech->get_ok('/dashboard?export=1&ward=144387');
        $mech->content_lacks('Brownswood');
    };
};

# Test tree routing for Hackney based on asset owner attribute

# Create tree categories with 'Trees' group using split email format
# Format: housing:email1;highways:email2;parks:email3;other:email4
# Or simplified: housing:email1;other:email2 (where 'other' catches highways/parks/unknown)
# The 'owner' extra field is populated automatically from the tree asset layer
my $tree_contact = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Tree issue',
    email => 'housing:estategardeners@example.com;housing individual:individual-trees@example.com;other:streettrees@example.com',
    send_method => 'Email',
    group => 'Trees',
    extra => { _fields => [
        { code => 'owner', description => 'Tree owner', required => 'false', automated => 'hidden_field' },
        { code => 'tree_code', description => 'Tree code', required => 'false', automated => 'hidden_field' },
    ] },
);

my $dangerous_tree_contact = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Dangerous tree',
    email => 'housing:estategardeners@example.com;highways:highways-streettrees@example.com;parks:parks-streettrees@example.com;other:default-trees@example.com',
    send_method => 'Email',
    group => 'Trees',
    extra => { _fields => [
        { code => 'owner', description => 'Tree owner', required => 'false', automated => 'hidden_field' },
        { code => 'tree_code', description => 'Tree code', required => 'false', automated => 'hidden_field' },
    ] },
);

# Create a non-tree category for comparison
my $grass_contact = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Grass and Hedges',
    email => 'grass@example.com',
    send_method => 'Email',
);

my $cobrand = FixMyStreet::Cobrand::Hackney->new;

sub create_tree_problem {
    my ($category, $owner, $title) = @_;
    $title ||= 'Tree problem';
    my ($p) = $mech->create_problems_for_body(1, $hackney->id, $title, {
        category => $category,
        latitude => 51.552267,
        longitude => -0.063316,
        cobrand => 'hackney',
        user => $user,
    });
    if (defined $owner) {
        $p->push_extra_fields({ name => 'owner', value => $owner });
        $p->update;
    }
    return $p;
}

my @routing_cases = (
    {
        name => 'Housing tree routes to estategardeners@example.com',
        params => [ 'Tree issue', 'Housing', 'Housing tree problem' ],
        expected_contact_id => $tree_contact->id,
        expected_email => 'estategardeners@example.com',
    },
    {
        name => 'Housing Individual tree routes to individual-trees@example.com',
        params => [ 'Tree issue', 'Housing Individual', 'Housing Individual tree problem' ],
        expected_contact_id => $tree_contact->id,
        expected_email => 'individual-trees@example.com',
    },
    {
        name => 'Highways tree routes to highways-streettrees@example.com',
        params => [ 'Dangerous tree', 'Highways', 'Highways tree problem' ],
        expected_contact_id => $dangerous_tree_contact->id,
        expected_email => 'highways-streettrees@example.com',
    },
    {
        name => 'Parks tree routes to parks-streettrees@example.com',
        params => [ 'Dangerous tree', 'Parks', 'Parks tree problem' ],
        expected_contact_id => $dangerous_tree_contact->id,
        expected_email => 'parks-streettrees@example.com',
    },
    {
        name => 'Dangerous tree with unknown owner routes to default-trees@example.com',
        params => [ 'Dangerous tree', 'Unknown Department', 'Unknown owner dangerous tree' ],
        expected_contact_id => $dangerous_tree_contact->id,
        expected_email => 'default-trees@example.com',
    },
);

for my $case (@routing_cases) {
    subtest $case->{name} => sub {
        my $p = create_tree_problem(@{ $case->{params} });

        my $sender = $cobrand->get_body_sender($hackney, $p);
        is $sender->{method}, 'Email', 'Send method is Email';
        is $sender->{contact}->id, $case->{expected_contact_id}, 'Contact as expected';

        my $split_match = $p->get_extra_metadata('split_match');
        my $split_key = $sender->{contact}->email;
        is $split_match->{$split_key}, $case->{expected_email}, $case->{name};

        $p->delete;
    };
}

subtest 'Owner matching is case-insensitive' => sub {
    my @cases = ('housing', 'Housing', 'HOUSING', 'HoUsInG');
    for my $case (@cases) {
        my $p = create_tree_problem('Tree issue', $case);
        my $sender = $cobrand->get_body_sender($hackney, $p);
        my $split_match = $p->get_extra_metadata('split_match');
        my $split_key = $sender->{contact}->email;
        is $split_match->{$split_key}, 'estategardeners@example.com', qq{"$case" routes to correct email};
        $p->delete;
    }
};

subtest 'Tree category without asset selected falls back to "other" email' => sub {
    my $p = create_tree_problem('Tree issue', undef, 'Tree problem no asset');

    my $sender = $cobrand->get_body_sender($hackney, $p);
    is $sender->{method}, 'Email', 'Send method is Email';
    is $sender->{contact}->id, $tree_contact->id, 'Contact is tree_contact';

    # Should use 'other' email from split format when no owner is present
    my $split_match = $p->get_extra_metadata('split_match');
    my $split_key = $sender->{contact}->email;
    is $split_match->{$split_key}, 'streettrees@example.com', 'Falls back to "other" email without asset selection';

    $p->delete;
};

subtest 'Tree with unrecognized owner falls back to "other" email' => sub {
    my $p = create_tree_problem('Tree issue', 'Unknown Department', 'Unknown owner tree');

    my $sender = $cobrand->get_body_sender($hackney, $p);
    is $sender->{method}, 'Email', 'Send method is Email';
    is $sender->{contact}->id, $tree_contact->id, 'Contact is tree_contact';

    # Should use 'other' email from split format
    my $split_match = $p->get_extra_metadata('split_match');
    my $split_key = $sender->{contact}->email;
    is $split_match->{$split_key}, 'streettrees@example.com', 'Unrecognized owner falls back to "other" email';

    $p->delete;
};

subtest 'Non-tree category unaffected by tree routing' => sub {
    my $p = create_tree_problem('Grass and Hedges', 'Housing', 'Grass cutting problem');

    my $sender = $cobrand->get_body_sender($hackney, $p);
    is $sender->{method}, 'Email', 'Send method is Email';
    is $sender->{contact}->id, $grass_contact->id, 'Contact is grass_contact';

    # Should not route based on tree logic
    my $split_match = $p->get_extra_metadata('split_match');
    is $split_match, undef, 'Non-tree category not affected by tree routing';

    $p->delete;
};

subtest '_parse_split_emails helper method' => sub {
    my $emails = $cobrand->_parse_split_emails('housing:email1@example.com;other:email2@example.com');
    is_deeply $emails, { housing => 'email1@example.com', other => 'email2@example.com' },
        'Basic two-part split works';

    $emails = $cobrand->_parse_split_emails('housing:a@test.com;highways:b@test.com;parks:c@test.com;other:d@test.com');
    is_deeply $emails, {
        housing => 'a@test.com',
        highways => 'b@test.com',
        parks => 'c@test.com',
        other => 'd@test.com'
    }, 'Four-part split works';

    # Test park/estate/other format (existing format)
    $emails = $cobrand->_parse_split_emails('park:park@test.com;estate:estate@test.com;other:other@test.com');
    is_deeply $emails, {
        park => 'park@test.com',
        estate => 'estate@test.com',
        other => 'other@test.com'
    }, 'Park/estate/other format also works';

    # Test case insensitivity (keys are lowercased)
    $emails = $cobrand->_parse_split_emails('Housing:email1@test.com;HIGHWAYS:email2@test.com');
    is_deeply $emails, { housing => 'email1@test.com', highways => 'email2@test.com' },
        'Keys are lowercased for case-insensitive matching';

    $emails = $cobrand->_parse_split_emails(' housing : email1@test.com ; other : email2@test.com ');
    is_deeply $emails, { housing => 'email1@test.com', other => 'email2@test.com' },
        'Whitespace is trimmed';

    $emails = $cobrand->_parse_split_emails('simple@test.com');
    is $emails, undef, 'Non-split email returns undef';

    $emails = $cobrand->_parse_split_emails('');
    is $emails, undef, 'Empty string returns undef';
};

subtest 'existing _split_emails still works for park/estate/other' => sub {
    my @emails = $cobrand->_split_emails('park:park@test.com;estate:estate@test.com;other:other@test.com');
    is_deeply \@emails, ['park@test.com', 'estate@test.com', 'other@test.com'],
        'Returns list in park/estate/other order';

    @emails = $cobrand->_split_emails('housing:a@test.com;other:b@test.com');
    is_deeply \@emails, [], 'Returns empty list for non-park/estate/other format';

    @emails = $cobrand->_split_emails('simple@test.com');
    is_deeply \@emails, [], 'Returns empty list for simple email';
};

done_testing();
