package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::Default';

sub send_moderation_notifications { 0 }

package FixMyStreet::Cobrand::TestTitle;

use parent 'FixMyStreet::Cobrand::Default';

sub moderate_permission_title { 0 }

package main;

use FixMyStreet::TestMech;
use FixMyStreet::App;
use Data::Dumper;

my $mech = FixMyStreet::TestMech->new;
$mech->host('www.example.org');

my $BROMLEY_ID = 2482;
my $body = $mech->create_body_ok( $BROMLEY_ID, 'Bromley Council' );
$mech->create_contact_ok( body => $body, category => 'Lost toys', email => 'losttoys@example.net' );

my $dt = DateTime->now;

my $user = $mech->create_user_ok('test-moderation@example.com', name => 'Test User');
my $user2 = $mech->create_user_ok('test-moderation2@example.com', name => 'Test User 2');

sub create_report {
    FixMyStreet::App->model('DB::Problem')->create(
    {
        postcode           => 'BR1 3SB',
        bodies_str         => $body->id,
        areas              => ",$BROMLEY_ID,",
        category           => 'Other',
        title              => 'Good bad good',
        detail             => 'Good bad bad bad good bad',
        used_map           => 't',
        name               => 'Test User 2',
        anonymous          => 'f',
        state              => 'confirmed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.4129',
        longitude          => '0.007831',
        user_id            => $user2->id,
        photo              => '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
        extra => { moon => 'waxing full' },
    });
}
my $report = create_report();

my $REPORT_URL = '/report/' . $report->id ;

subtest 'Auth' => sub {

    subtest 'Unaffiliated user cannot see moderation' => sub {
        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('Moderat');

        $mech->get_ok("$REPORT_URL/moderate");
        $mech->content_lacks('Moderat');

        $mech->log_in_ok( $user->email );

        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('Moderat');

        $user->update({ from_body => $body->id });

        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('Moderat');

        $mech->get('/contact?m=1&id=' . $report->id);
        is $mech->res->code, 400;
        $mech->content_lacks('Good bad bad bad');
    };

    subtest 'Affiliated and permissioned user can see moderation' => sub {
        # login and from_body are done in previous test.
        $user->user_body_permissions->create({
            body => $body,
            permission_type => 'moderate',
        });

        $mech->get_ok($REPORT_URL);
        $mech->content_contains('Moderat');
    };
};

my %problem_prepopulated = (
    problem_show_name => 1,
    problem_photo => 1,
    problem_title => 'Good bad good',
    problem_detail => 'Good bad bad bad good bad',
);

subtest 'Problem moderation' => sub {

    subtest 'Post modify title and text' => sub {
        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('show-moderation');
        $mech->follow_link_ok({ text_regex => qr/^Moderate$/ });
        $mech->content_contains('show-moderation');
        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_title  => 'Good good',
            problem_detail => 'Good good improved',
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );
        $mech->content_like(qr/Moderated by Bromley Council/);

        $report->discard_changes;
        is $report->title, 'Good good';
        is $report->detail, 'Good good improved';
    };

    subtest 'Revert title and text' => sub {
        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_revert_title  => 1,
            problem_revert_detail => 1,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $report->discard_changes;
        is $report->title, 'Good bad good';
        is $report->detail, 'Good bad bad bad good bad';

        my @history = $report->moderation_original_datas->search(undef, { order_by => 'id' })->all;
        is @history, 2, 'Right number of entries';
        is $history[0]->title, 'Good bad good', 'Correct original title';
        is $history[1]->title, 'Good good', 'Correct second title';
    };

    subtest 'Post modified title after edited elsewhere' => sub {
        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_title => 'Good good',
            form_started => 1, # January 1970!
        }});
        $mech->base_like( qr{\Q/moderate$REPORT_URL\E} );
        $mech->content_contains('Good bad good'); # Displayed title
        $mech->content_contains('Good good'); # Form edit

        $report->discard_changes;
        is $report->title, 'Good bad good', 'title unchanged';
    };

    subtest 'Make anonymous' => sub {
        $mech->content_lacks('Reported anonymously');

        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_show_name => 0,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Reported anonymously');

        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_show_name => 1,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Reported anonymously');
    };

    subtest 'Hide photo' => sub {
        $mech->content_contains('Photo of this report');

        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_photo => 0,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Photo of this report');

        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_photo => 1,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Photo of this report');
    };

    subtest 'Hide report' => sub {
        $mech->clear_emails_ok;

        $mech->submit_form_ok({ with_fields => {
            %problem_prepopulated,
            problem_hide => 1,
        }});
        $mech->base_unlike( qr{/report/}, 'redirected to front page' );

        $report->discard_changes;
        is $report->state, 'hidden', 'Is hidden';

        my $email = $mech->get_email;
        is $email->header('To'), '"Test User 2" <test-moderation2@example.com>', 'Sent to correct email';
        my $url = $mech->get_link_from_email($email);
        ok $url, "extracted complain url '$url'";

        $mech->get_ok($url);
        $mech->content_contains('Good bad bad bad');

        # reset
        $report->update({ state => 'confirmed' });
    };

    subtest 'Hide report without sending email' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'tester' => '.' } ]
        }, sub {

            $mech->clear_emails_ok;

            $mech->get_ok($REPORT_URL);
            $mech->submit_form_ok({ with_fields => {
                %problem_prepopulated,
                problem_hide => 1,
            }});
            $mech->base_unlike( qr{/report/}, 'redirected to front page' );

            $report->discard_changes;
            is $report->state, 'hidden', 'Is hidden';

            ok $mech->email_count_is(0), "Email wasn't sent";

            # reset
            $report->update({ state => 'confirmed' });
        }
    };

    subtest 'Try and moderate title when not allowed' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'testtitle'
        }, sub {
            $mech->get_ok($REPORT_URL);
            $mech->submit_form_ok({ with_fields => {
                problem_show_name => 1,
                problem_photo => 1,
                problem_detail => 'Changed detail',
            }});
            $mech->base_like( qr{\Q$REPORT_URL\E} );
            $mech->content_like(qr/Moderated by Bromley Council/);

            $report->discard_changes;
            is $report->title, 'Good bad good';
            is $report->detail, 'Changed detail';
        }
    };

    subtest 'Moderate extra data' => sub {
        my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;
        $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
            %problem_prepopulated,
            'extra.weather' => 'snow',
            'extra.moon' => 'waning full',
            token => $csrf,
        });
        $report->discard_changes;
        is $report->get_extra_metadata('weather'), 'snow';
        is $report->get_extra_metadata('moon'), 'waning full';
        my $mod = $report->moderation_original_data;
        is $mod->get_extra_metadata('moon'), 'waxing full';
        is $mod->get_extra_metadata('weather'), undef;

        my $diff = $mod->extra_diff($report, 'moon');
        is $diff, "wa<del style='background-color:#fcc'>x</del><ins style='background-color:#cfc'>n</ins>ing full", 'Correct diff';
    };

    subtest 'Moderate category' => sub {
        $report->update;
        my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;
        $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
            %problem_prepopulated,
            'category' => 'Lost toys',
            token => $csrf,
        });
        $report->discard_changes;
        is $report->category, 'Lost toys';
    };

    subtest 'Moderate state' => sub {
        my $mods_count = $report->moderation_original_datas->count;
        my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;
        $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
            %problem_prepopulated,
            state => 'confirmed',
            token => $csrf,
        });
        $report->discard_changes;
        is $report->state, 'confirmed', 'state has not changed';
        is $report->comments->count, 0, 'same state, no update';
        is $report->moderation_original_datas->count, $mods_count, 'No moderation entry either';
        $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
            %problem_prepopulated,
            state => 'in progress',
            token => $csrf,
        });
        $report->discard_changes;
        is $report->state, 'in progress', 'state has changed';
        is $report->comments->count, 1, 'a new update added';
        $report->update({ state => 'confirmed' });
        is $report->moderation_original_datas->count, $mods_count, 'No moderation entry, only state changed';
    };

    subtest 'Moderate location' => sub {
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
            ALLOWED_COBRANDS => 'fixmystreet',
        }, sub {
            my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;
            $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
                %problem_prepopulated,
                latitude => '53',
                longitude => '0.01578',
                token => $csrf,
            });
            $report->discard_changes;
            is $report->latitude, 51.4129, 'No change when moved out of area';
            $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
                %problem_prepopulated,
                latitude => '51.4021',
                longitude => '0.01578',
                token => $csrf,
            });
            $report->discard_changes;
            is $report->latitude, 51.4021, 'Updated when same body';
        };
    };
};

$mech->content_lacks('Posted anonymously', 'sanity check');
my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;

subtest 'Edit photos' => sub {
    $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
        %problem_prepopulated,
        photo1 => 'something-wrong',
        token => $csrf,
    });
    $mech->post_ok('http://www.example.org/moderate/report/' . $report->id, {
        %problem_prepopulated,
        photo1 => '',
        upload_fileid => '',
        token => $csrf,
    });
    $report->discard_changes;
    is $report->photo, undef;
};

sub create_update {
    $report->comments->create({
        user      => $user2,
        name      => 'Test User 2',
        anonymous => 'f',
        photo     => '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
        text      => 'update good good bad good',
        state     => 'confirmed',
        mark_fixed => 0,
        confirmed => $dt,
    });
}
my %update_prepopulated = (
    update_show_name => 1,
    update_photo => 1,
    update_text => 'update good good bad good',
);

my $update = create_update();

subtest 'updates' => sub {

    subtest 'Update modify text' => sub {
        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('show-moderation');
        $mech->follow_link_ok({ text_regex => qr/^Moderate this update$/ });
        $mech->content_contains('show-moderation');
        $mech->submit_form_ok({ with_fields => {
            %update_prepopulated,
            update_text => 'update good good good',
        }}) or die $mech->content;
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $update->discard_changes;
        is $update->text, 'update good good good',
    };

    subtest 'Revert text' => sub {
        $mech->submit_form_ok({ with_fields => {
            %update_prepopulated,
            update_revert_text => 1,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $update->discard_changes;
        is $update->text, 'update good good bad good',
    };

    subtest 'Make anonymous' => sub {
        $mech->content_lacks('Posted anonymously')
            or die sprintf '%d (%d)', $update->id, $report->comments->count;

        $mech->submit_form_ok({ with_fields => {
            %update_prepopulated,
            update_show_name => 0,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Posted anonymously');

        $mech->submit_form_ok({ with_fields => {
            %update_prepopulated,
            update_show_name => 1,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Posted anonymously');
    };

    subtest 'Moderate extra data' => sub {
        $update->set_extra_metadata('moon', 'waxing full');
        $update->update;
        my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;
        $mech->post_ok('http://www.example.org/moderate/report/' . $report->id . '/update/' . $update->id, {
            %update_prepopulated,
            'extra.weather' => 'snow',
            'extra.moon' => 'waxing full',
            token => $csrf,
        });
        $update->discard_changes;
        is $update->get_extra_metadata('weather'), 'snow';
    };

    subtest 'Hide photo' => sub {
        $report->update({ photo => undef }); # hide the main photo so we can just look for text in comment

        $mech->get_ok($REPORT_URL);

        $mech->content_contains('Photo of this report')
            or die $mech->content;

        $mech->submit_form_ok({ with_fields => {
            %update_prepopulated,
            update_photo => 0,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Photo of this report');

        $mech->submit_form_ok({ with_fields => {
            %update_prepopulated,
            update_photo => 1,
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Photo of this report');
    };

    subtest 'Hide comment' => sub {
        $mech->content_contains('update good good bad good');

        $mech->submit_form_ok({ with_fields => {
            %update_prepopulated,
            update_hide => 1,
        }});
        $mech->content_lacks('update good good bad good');
    };

    $update->moderation_original_data->delete;
};

my $update2 = create_update();

subtest 'Update 2' => sub {
    $mech->get_ok($REPORT_URL);
    $mech->submit_form_ok({ with_fields => {
        %update_prepopulated,
        update_text => 'update good good good',
    }}) or die $mech->content;

    $update2->discard_changes;
    is $update2->text, 'update good good good',
};

subtest 'Now stop being a staff user' => sub {
    $user->update({ from_body => undef });
    $mech->get_ok($REPORT_URL);
    $mech->content_contains('Moderated by Bromley Council');

    $mech->get_ok("$REPORT_URL/moderate/" . $update->id);
    $mech->content_lacks('Moderate this update');
};

subtest 'And do it as a superuser' => sub {
    $user->update({ is_superuser => 1 });
    $mech->get_ok($REPORT_URL);
    $mech->submit_form_ok({ with_fields => {
        %problem_prepopulated,
        problem_title  => 'Good good',
        problem_detail => 'Good good improved',
    }});
    $mech->content_contains('Moderated by an administrator');
};

subtest 'Check moderation history in admin' => sub {
    $mech->get_ok('/admin/report_edit/' . $report->id);
};
done_testing();
