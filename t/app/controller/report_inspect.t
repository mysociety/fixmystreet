use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $brum = $mech->create_body_ok(2514, 'Birmingham City Council');
my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council', { can_be_devolved => 1 } );
my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' );
my $contact2 = $mech->create_contact_ok( body_id => $oxon->id, category => 'Sheep', email => 'SHEEP', send_method => 'Open311' );
my $contact3 = $mech->create_contact_ok( body_id => $oxon->id, category => 'Badgers', email => 'badgers@example.net' );
my $rp = FixMyStreet::DB->resultset("ResponsePriority")->create({
    body => $oxon,
    name => 'High Priority',
});
FixMyStreet::DB->resultset("ContactResponsePriority")->create({
    contact => $contact,
    response_priority => $rp,
});
my $wodc = $mech->create_body_ok(2420, 'West Oxfordshire District Council');
$mech->create_contact_ok( body_id => $wodc->id, category => 'Horses', email => 'horses@example.net' );


my ($report, $report2, $report3) = $mech->create_problems_for_body(3, $oxon->id, 'Test', {
    category => 'Cows', cobrand => 'fixmystreet', areas => ',2237,2420',
    whensent => \'current_timestamp',
    latitude => 51.847693, longitude => -1.355908,
});
my $report_id = $report->id;
my $report2_id = $report2->id;
my $report3_id = $report3->id;


my $user = $mech->log_in_ok('test@example.com');
$user->set_extra_metadata('categories', [ $contact->id ]);
$user->update( { from_body => $oxon } );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest "test inspect page" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->content_lacks('Save changes');
        $mech->content_lacks('Priority');
        $mech->content_lacks('Traffic management');

        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Save changes');
        $mech->content_contains('Priority');
        $mech->content_lacks('Traffic management');

        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Save changes');
        $mech->content_contains('Priority');
        $mech->content_contains('Traffic management');
    };

    subtest "test basic inspect submission" => sub {
        $mech->submit_form_ok({ button => 'save', with_fields => { traffic_information => 'Yes', state => 'Action scheduled', include_update => undef } });
        $report->discard_changes;
        my $alert = FixMyStreet::App->model('DB::Alert')->find(
            { user => $user, alert_type => 'new_updates', confirmed => 1, }
        );

        is $report->state, 'action scheduled', 'report state changed';
        is $report->get_extra_metadata('traffic_information'), 'Yes', 'report data changed';
        ok defined( $alert ) , 'sign up for alerts';
    };

    subtest "test inspect & instruct submission" => sub {
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_instruct' });
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'planned_reports' });
        $report->state('confirmed');
        $report->update;
        my $reputation = $report->user->get_extra_metadata("reputation");
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => {
            public_update => "This is a public update.", include_update => "1",
            state => 'action scheduled', raise_defect => 1,
        } });
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ with_fields => {
            update => "This is a second public update, of normal update form, no actual change.",
        } });
        $report->discard_changes;
        my $comment = ($report->comments( undef, { order_by => { -desc => 'id' } } )->all)[1]->text;
        is $comment, "This is a public update.", 'Update was created';
        is $report->get_extra_metadata('inspected'), 1, 'report marked as inspected';
        is $report->user->get_extra_metadata('reputation'), $reputation, "User reputation wasn't changed";
        $mech->get_ok("/report/$report_id");
        my $meta = $mech->extract_update_metas;
        like $meta->[0], qr/State changed to: Action scheduled/, 'First update mentions action scheduled';
        like $meta->[2], qr/Posted by .*defect raised/, 'Update mentions defect raised';

        $user->unset_extra_metadata('categories');
        $user->update;
    };

    subtest "test update is required when instructing" => sub {
        $report->unset_extra_metadata('inspected');
        $report->update;
        $report->inspection_log_entry->delete;
        $report->comments->delete_all;
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { public_update => undef, include_update => "1" } });
        is_deeply $mech->page_errors, [ "Please provide a public update for this report." ], 'errors match';
        $report->discard_changes;
        is $report->comments->count, 0, "Update wasn't created";
        is $report->get_extra_metadata('inspected'), undef, 'report not marked as inspected';
    };

    subtest "test location changes" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => 55, longitude => -2 } });
        $mech->content_contains('Invalid location');
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => 51.754926, longitude => -1.256179, include_update => undef } });
        $mech->content_lacks('Invalid location');
        $user->user_body_permissions->search({ body_id => $oxon->id, permission_type => 'planned_reports' })->delete;
    };

    subtest "test duplicate reports are shown" => sub {
        my $old_state = $report->state;
        $report->set_extra_metadata('duplicate_of' => $report2->id);
        $report->state('duplicate');
        $report->update;
        $report2->set_extra_metadata('duplicates' => [ $report->id ]);
        $report2->update;

        $mech->get_ok("/report/$report_id");
        $mech->content_contains($report2->title);

        $mech->get_ok("/report/$report2_id");
        $mech->content_contains($report->title);

        $report->unset_extra_metadata('duplicate_of');
        $report->state($old_state);
        $report->update;
        $report2->unset_extra_metadata('duplicates');
        $report2->update;
    };

    subtest "marking a report as a duplicate with update correctly sets update status" => sub {
        my $old_state = $report->state;
        $report->comments->delete_all;

        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { state => 'Duplicate', duplicate_of => $report2->id, public_update => "This is a duplicate.", include_update => "1" } });
        $report->discard_changes;
        $report2->discard_changes;

        is $report->state, 'duplicate', 'report marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 1, 'update marking report as duplicate was left';

        is $report->get_extra_metadata('duplicate_of'), $report2->id;
        is_deeply $report2->get_extra_metadata('duplicates'), [ $report->id ];
        $report->update({ state => $old_state });
    };

    subtest "changing state does not add another alert" =>sub {
      $mech->get_ok("/report/$report_id");
      $mech->submit_form_ok({ button => 'save', with_fields => { state => 'Investigating', public_update => "We're investigating.", include_update => "1" } });

      my $alert_count = FixMyStreet::App->model('DB::Alert')->search(
          { user_id => $user->id, alert_type => 'new_updates', confirmed => 1, parameter => $report_id }
      )->count();

      is $alert_count, 1 , 'User has only one alert';
    };

    subtest "marking a report as a duplicate doesn't clobber user-provided update" => sub {
        my $old_state = $report->state;
        $report->comments->delete_all;

        $mech->get_ok("/report/$report_id");
        my $update_text = "This text was entered as an update by the user.";
        $mech->submit_form_ok({ button => 'save', with_fields => {
            state => 'Duplicate',
            duplicate_of => $report2->id,
            public_update => $update_text,
            include_update => "1",
        }});
        $report->discard_changes;

        is $report->state, 'duplicate', 'report marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 1, 'update marked report as duplicate';
        $mech->content_contains($update_text);
        $mech->content_lacks("Thank you for your report. This problem has already been reported.");

        $report->update({ state => $old_state });
    };

    subtest "post-inspect redirect is to the right place if URL set" => sub {
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'planned_reports' });
        $mech->get_ok("/report/$report_id");
        my $update_text = "This text was entered as an update by the user.";
        $mech->submit_form_ok({ button => 'save', with_fields => {
            public_update => $update_text,
            include_update => "1",
            post_inspect_url => "/"
        }});
        is $mech->res->code, 200, "got 200";
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/', 'redirected to front page';
        $user->user_body_permissions->search({ body_id => $oxon->id, permission_type => 'planned_reports' })->delete;
    };

    subtest "post-inspect redirect is to the right place if URL not set" => sub {
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'planned_reports' });
        $user->set_extra_metadata(categories => [ $contact->id ]);
        $user->update;
        $mech->get_ok("/report/$report_id");
        my $update_text = "This text was entered as an update by the user.";
        $mech->submit_form_ok({ button => 'save', with_fields => {
            public_update => $update_text,
            include_update => "1",
            post_inspect_url => ""
        }});
        is $mech->res->code, 200, "got 200";
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/around', 'redirected to /around';
        my %params = $mech->uri->query_form;
        is $params{lat}, $report->latitude, "latitude param is correct";
        is $params{lon}, $report->longitude, "longitude param is correct";
        is $params{filter_category}, $contact->category, "categories param is correct";
        $user->user_body_permissions->search({ body_id => $oxon->id, permission_type => 'planned_reports' })->delete;
    };

    subtest "default response priorities display correctly" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Priority</label', 'report priority list present');
        like $mech->content, qr/<select name="priority" id="problem_priority" class="form-control">[^<]*<option value="" selecte/s, 'blank priority option is selected';
        $mech->content_lacks('value="' . $rp->id . '" selected>High', 'non default priority not selected');

        $rp->update({ is_default => 1});
        $mech->get_ok("/report/$report_id");
        unlike $mech->content, qr/<select name="priority" id="problem_priority" class="form-control">[^<]*<option value="" selecte/s, 'blank priority option not selected';
        $mech->content_contains('value="' . $rp->id . '" selected>High', 'default priority selected');
    };

    foreach my $test (
        { type => 'report_edit_priority', priority => 1 },
        { type => 'report_edit_category', category => 1 },
        { type => 'report_inspect', priority => 1, category => 1, detailed => 1 },
    ) {
        subtest "test $test->{type} permission" => sub {
            $user->user_body_permissions->delete;
            $user->user_body_permissions->create({ body => $oxon, permission_type => $test->{type} });
            $mech->get_ok("/report/$report_id");
            $mech->contains_or_lacks($test->{priority}, 'Priority</label>');
            $mech->contains_or_lacks($test->{priority}, '>High');
            $mech->contains_or_lacks($test->{category}, 'Category');
            $mech->contains_or_lacks($test->{detailed}, 'Extra details');
            $mech->submit_form_ok({
                button => 'save',
                with_fields => {
                    $test->{priority} ? (priority => 1) : (),
                    $test->{category} ? (category => 'Cows') : (),
                    $test->{detailed} ? (detailed_information => 'Highland ones') : (),
                }
            });
        };
    }
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'oxfordshire',
}, sub {
    subtest "test negative reputation" => sub {
        my $reputation = $report->user->get_extra_metadata("reputation") || 0;

        $mech->get_ok("/report/$report_id");
        $mech->submit_form( button => 'remove_from_site' );

        $report->discard_changes;
        is $report->user->get_extra_metadata('reputation'), $reputation-1, "User reputation was decreased";
        $report->update({ state => 'confirmed' });
    };

    subtest "test positive reputation" => sub {
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_instruct' });
        $report->unset_extra_metadata('inspected');
        $report->update;
        $report->inspection_log_entry->delete if $report->inspection_log_entry;
        my $reputation = $report->user->get_extra_metadata("reputation") || 0;
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => {
            state => 'in progress', include_update => undef,
        } });
        $report->discard_changes;
        is $report->get_extra_metadata('inspected'), undef, 'report not marked as inspected';

        $mech->submit_form_ok({ button => 'save', with_fields => {
            state => 'action scheduled', include_update => undef,
        } });
        $report->discard_changes;
        is $report->get_extra_metadata('inspected'), undef, 'report not marked as inspected';
        is $report->user->get_extra_metadata('reputation'), $reputation+1, "User reputation was increased";

        $mech->submit_form_ok({ button => 'save', with_fields => {
            state => 'action scheduled', include_update => undef,
            raise_defect => 1,
        } });
        $report->discard_changes;
        is $report->get_extra_metadata('inspected'), 1, 'report marked as inspected';
        $mech->get_ok("/report/$report_id");
        my $meta = $mech->extract_update_metas;
        like $meta->[-1], qr/Updated by .*defect raised/, 'Update mentions defect raised';
    };

    subtest "Oxfordshire-specific traffic management options are shown" => sub {
        $report->update({ state => 'confirmed' });
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { traffic_information => 'Signs and Cones', state => 'Action scheduled', include_update => undef } });
        $report->discard_changes;
        is $report->state, 'action scheduled', 'report state changed';
        is $report->get_extra_metadata('traffic_information'), 'Signs and Cones', 'report data changed';
    };

};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'oxfordshire', 'fixmystreet' ],
    BASE_URL => 'http://fixmystreet.site',
}, sub {
    subtest "test report not resent when category changes if send_method doesn't change" => sub {
        $mech->get_ok("/report/$report3_id");
        $mech->submit_form(button => 'save', with_fields => { category => 'Badgers', include_update => undef, });

        $report3->discard_changes;
        is $report3->category, "Badgers", "Report in correct category";
        isnt $report3->whensent, undef, "Report not marked as unsent";
        is $report3->bodies_str, $oxon->id, "Reported to OCC";
    };

    subtest "test resending when send_method changes" => sub {
        $mech->get_ok("/report/$report3_id");
        # Then change the category to the other category within the same council,
        # which should cause it to be resent because it has a different send method
        $mech->submit_form(button => 'save', with_fields => { category => 'Sheep', include_update => undef, });

        $report3->discard_changes;
        is $report3->category, "Sheep", "Report in correct category";
        is $report3->whensent, undef, "Report marked as unsent";
        is $report3->bodies_str, $oxon->id, "Reported to OCC";
    };

    subtest "test category/body changes" => sub {
        $mech->host('oxfordshire.fixmystreet.site');
        $report->update({ state => 'confirmed' });
        $mech->get_ok("/report/$report_id");
        # Then change the category to the other council in this location,
        # which should cause it to be resent. We clear the host because
        # otherwise testing stays on host() above.
        $mech->clear_host;
        $mech->submit_form(button => 'save', with_fields => { category => 'Horses', include_update => undef, });

        $report->discard_changes;
        is $report->category, "Horses", "Report in correct category";
        is $report->whensent, undef, "Report marked as unsent";
        is $report->bodies_str, $wodc->id, "Reported to WODC";

        is $mech->uri->path, "/report/$report_id", "redirected to correct page";
        is $mech->res->code, 200, "got 200 for final destination";
        is $mech->res->previous->code, 302, "got 302 for redirect";
        # Extra check given host weirdness
        is $mech->res->previous->header('Location'), "http://fixmystreet.site/report/$report_id";
    };
};


END {
    done_testing();
}
