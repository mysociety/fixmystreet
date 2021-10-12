use utf8;
use CGI::Simple;
use DateTime;
use JSON::MaybeXS;
use Test::MockModule;
use FixMyStreet::TestMech;
use Open311;
use Open311::GetServiceRequests;
use Open311::GetServiceRequestUpdates;
use Open311::PostServiceRequestUpdates;
use FixMyStreet::Script::Alerts;
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
};

my $hackney = $mech->create_body_ok(2508, 'Hackney Council', $params);
my $contact = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Potholes & stuff',
    email => 'pothole@example.org',
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

my $user = $mech->create_user_ok('user@example.org', name => 'Test User');
my $phone_user = $mech->create_user_ok('+447700900002');
my $hackney_user = $mech->create_user_ok('hackney_user@example.org', name => 'Hackney User', from_body => $hackney);
$hackney_user->user_body_permissions->create({
    body => $hackney,
    permission_type => 'moderate',
});
$hackney_user->user_body_permissions->create({
    body => $hackney,
    permission_type => 'category_edit',
});

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

my ($p) = $mech->create_problems_for_body(1, $hackney->id, '', { cobrand => 'hackney' });
my $alert = FixMyStreet::DB->resultset('Alert')->create( {
    parameter  => $p->id,
    alert_type => 'new_updates',
    user       => $user,
    cobrand    => 'hackney',
} )->confirm;

FixMyStreet::DB->resultset('Alert')->create( {
    parameter  => $p->id,
    alert_type => 'new_updates',
    user       => $phone_user,
    cobrand    => 'hackney',
} )->confirm;

subtest "sends branded alert emails" => sub {
    $mech->create_comment_for_problem($p, $system_user, 'Other User', 'This is some update text', 'f', 'confirmed', undef);
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
    like $mech->get_text_body_from_email($email), qr/Hackney Council/, "emails are branded";
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
}, sub {
    subtest "special send handling" => sub {
        my $cbr = Test::MockModule->new('FixMyStreet::Cobrand::Hackney');
        my $p = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        $contact2->update({ email => 'park:parks@example;estate:estates@example;other:OTHER', send_method => '' });

        subtest 'in a park' => sub {
            $cbr->mock('_fetch_features', sub {
                my ($self, $cfg, $x, $y) = @_;
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
            $p->update({ whensent => undef });
        };

        subtest 'in an estate' => sub {
            $cbr->mock('_fetch_features', sub {
                my ($self, $cfg, $x, $y) = @_;
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
            $p->update({ whensent => undef });
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
        $contact2->update({ send_method => 'Email' });
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
        geocode => {
            resourceSets => [ {
                resources => [ {
                    name => '12 A Street, XX1 1SZ',
                    address => {
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

    my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User',
        from_body => $hackney, password => 'password');
    $mech->log_in_ok( $staffuser->email );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'hackney',
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('"Reported As","Nearest address","Nearest postcode","Extra details"');
    $mech->content_contains('hackney,,"12 A Street, XX1 1SZ","XX1 1SZ","Some detailed information"');
};

done_testing();
