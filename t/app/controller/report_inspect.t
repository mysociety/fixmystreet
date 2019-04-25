use FixMyStreet::TestMech;
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

my $brum = $mech->create_body_ok(2514, 'Birmingham City Council');
my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council', { can_be_devolved => 1 } );
my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' );
my $contact2 = $mech->create_contact_ok( body_id => $oxon->id, category => 'Sheep', email => 'SHEEP', send_method => 'Open311' );
my $contact3 = $mech->create_contact_ok( body_id => $oxon->id, category => 'Badgers', email => 'badgers@example.net' );
my $dt = FixMyStreet::DB->resultset("DefectType")->create({
    body => $oxon,
    name => 'Small Defect', description => "Teeny",
});
FixMyStreet::DB->resultset("ContactDefectType")->create({
    contact => $contact,
    defect_type => $dt,
});
my $rp = FixMyStreet::DB->resultset("ResponsePriority")->create({
    body => $oxon,
    name => 'High Priority',
});
my $rp2 = FixMyStreet::DB->resultset("ResponsePriority")->create({
    body => $oxon,
    name => 'Low Priority',
});
FixMyStreet::DB->resultset("ContactResponsePriority")->create({
    contact => $contact,
    response_priority => $rp,
});
FixMyStreet::DB->resultset("ContactResponsePriority")->create({
    contact => $contact3,
    response_priority => $rp2,
});
my $oxfordcity = $mech->create_body_ok(2421, 'Oxford City Council');
$mech->create_contact_ok( body_id => $oxfordcity->id, category => 'Horses', email => 'horses@example.net' );


my ($report, $report2, $report3) = $mech->create_problems_for_body(3, $oxon->id, 'Test', {
    category => 'Cows', cobrand => 'fixmystreet', areas => ',2237,2421,',
    whensent => \'current_timestamp',
    latitude => 51.754926, longitude => -1.256179,
});
my $report_id = $report->id;
my $report2_id = $report2->id;
my $report3_id = $report3->id;

$mech->create_user_ok('body@example.com', name => 'Body User');
my $user = $mech->log_in_ok('body@example.com');
$user->set_extra_metadata('categories', [ $contact->id ]);
$user->update( { from_body => $oxon } );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest "test inspect page" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->content_lacks('Save changes');
        $mech->content_lacks('Private');
        $mech->content_lacks('Priority');
        $mech->content_lacks('Traffic management');
        $mech->content_lacks('/admin/report_edit/'.$report_id.'">admin</a>)');

        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_mark_private' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Private');
        $mech->content_contains('Save changes');
        $mech->content_lacks('Priority');
        $mech->content_lacks('Traffic management');
        $mech->content_lacks('/admin/report_edit/'.$report_id.'">admin</a>)');

        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Private');
        $mech->content_contains('Save changes');
        $mech->content_contains('Priority');
        $mech->content_lacks('Traffic management');
        $mech->content_lacks('/admin/report_edit/'.$report_id.'">admin</a>)');

        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Save changes');
        $mech->content_contains('Private');
        $mech->content_contains('Priority');
        $mech->content_contains('Traffic management');
        $mech->content_lacks('/admin/report_edit/'.$report_id.'">admin</a>)');
    };

    subtest "council staff can't see admin report edit link on FMS.com" => sub {
        my $report_edit_permission = $user->user_body_permissions->create({
            body => $oxon, permission_type => 'report_edit' });
        $mech->get_ok("/report/$report_id");
        $mech->content_lacks('/admin/report_edit/'.$report_id.'">admin</a>)');
        $report_edit_permission->delete;
    };

    subtest "superusers can see admin report edit link on FMS.com" => sub {
        $user->update({is_superuser => 1});
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('/admin/report_edit/'.$report_id.'">admin</a>)');
        $user->update({is_superuser => 0});
    };

    subtest "test mark private submission" => sub {
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_mark_private' });

        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { non_public => 1 } });
        $report->discard_changes;
        my $alert = FixMyStreet::App->model('DB::Alert')->find(
            { user => $user, alert_type => 'new_updates', confirmed => 1, }
        );

        is $report->state, 'confirmed', 'report state not changed';
        ok $report->non_public, 'report not public';
        ok !defined( $alert ) , 'not signed up for alerts';

        $report->update( { non_public => 0 } );
    };
    subtest "test basic inspect submission" => sub {
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });

        $mech->get_ok("/report/$report_id");
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
    };

    subtest "test areas update when location changes" => sub {
        $report->discard_changes;
        my ($lat, $lon, $areas) = ($report->latitude, $report->longitude, $report->areas);
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => 52.038712, longitude => -1.346397, include_update => undef } });
        $mech->content_lacks('Invalid location');
        $report->discard_changes;
        is $report->areas, ",151767,2237,2419,", 'Areas set correctly';
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => $lat, longitude => $lon, include_update => undef } });
        $report->discard_changes;
        is $report->areas, $areas, 'Areas reset correctly';
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

    subtest "can mark a report as duplicate without supplying a duplicate and a public update" => sub {
        my $old_state = $report->state;
        $report->comments->delete_all;

        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { state => 'Duplicate', include_update => "0" } });

        $mech->content_contains('provide a duplicate ID', "error message about missing duplicate id");
        $report->discard_changes;
        $report2->discard_changes;

        is $report->state, $old_state, 'report not marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 0, 'no update marking report as duplicate was left';

        is $report->get_extra_metadata('duplicate_of'), undef;

        $mech->submit_form_ok({ button => 'save', with_fields => { state => 'Duplicate', public_update => 'This is a duplicate', include_update => "1" } });
        $mech->content_lacks('provide a duplicate ID', "no error message about missing duplicate id");
        $report->discard_changes;
        $report2->discard_changes;

        is $report->state, 'duplicate', 'report marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 1, 'update marking report as duplicate was left';
        is $report->get_extra_metadata('duplicate_of'), undef;
        is_deeply $report2->get_extra_metadata('duplicates'), undef;

        $report->update({ state => $old_state });
    };

    subtest "can mark a report as duplicate without supplying a public update and a duplicate id" => sub {
        my $old_state = $report->state;
        $report->comments->delete_all;

        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { state => 'Duplicate', include_update => "0" } });

        $mech->content_contains('provide a duplicate ID', "error message about missing duplicate id");
        $report->discard_changes;
        $report2->discard_changes;

        is $report->state, $old_state, 'report not marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 0, 'no update marking report as duplicate was left';

        is $report->get_extra_metadata('duplicate_of'), undef;

        $mech->submit_form_ok({ button => 'save', with_fields => { state => 'Duplicate', duplicate_of => $report2->id, include_update => "0" } });
        $mech->content_lacks('provide a duplicate ID', "no error message about missing duplicate id");
        $report->discard_changes;
        $report2->discard_changes;

        is $report->state, 'duplicate', 'report marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 1, 'update marking report as duplicate was left';
        is $report->get_extra_metadata('duplicate_of'), $report2->id;
        is_deeply $report2->get_extra_metadata('duplicates'), [ $report->id ];

        # Check that duplicate does not include shortlist add button (no form in form)
        $mech->get_ok("/report/$report_id");
        $mech->content_lacks('item-list__item__shortlist-add');

        $report->set_extra_metadata('duplicate_of', undef);
        $report->update({ state => $old_state });
        $report2->set_extra_metadata('duplicates', undef);
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

        $mech->get_ok("/report/$report2_id/nearby.json");
        $mech->content_lacks('Add to shortlist');

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
        $mech->get_ok("/report/$report_id"); # Get again as planned_reports permission means redirect to referer...
        $mech->content_contains($update_text);
        $mech->content_lacks("Thank you for your report. This problem has already been reported.");

        $report->update({ state => $old_state });
    };

    subtest "post-inspect redirect is to the right place if URL set" => sub {
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
    };

    subtest "post-inspect redirect is to the right place if URL not set" => sub {
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
                    $test->{priority} ? (priority => $rp->id) : (),
                    $test->{category} ? (category => 'Cows') : (),
                    $test->{detailed} ? (detailed_information => 'Highland ones') : (),
                }
            });
        };
    }

    subtest "check priority not set for category with no priorities" => sub {
        $report->discard_changes;
        $report->update({ category => 'Cows', response_priority_id => undef });
        $report->discard_changes;
        is $report->response_priority, undef, 'response priority not set';
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_category' });
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({
            button => 'save',
            with_fields => {
                priority => $rp->id,
                category => 'Sheep',
            }
        });

        $report->discard_changes;
        is $report->response_priority, undef, 'response priority not set';
    };

    subtest "check can set priority for category when changing from category with no priorities" => sub {
        $report->discard_changes;
        $report->update({ category => 'Sheep', response_priority_id => undef });
        $report->discard_changes;
        is $report->response_priority, undef, 'response priority not set';
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_category' });
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({
            button => 'save',
            with_fields => {
                priority => $rp->id,
                category => 'Cows',
            }
        });

        $report->discard_changes;
        is $report->response_priority->id, $rp->id, 'response priority set';
    };

    subtest "check can set defect type for category when changing from category with no defect types" => sub {
        $report->update({ category => 'Sheep', defect_type_id => undef });
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({
            button => 'save',
            with_fields => {
                include_update => 0,
                defect_type => $dt->id,
                category => 'Cows',
            }
        });
        $report->discard_changes;
        is $report->defect_type->id, $dt->id, 'defect type set';
        $report->update({ defect_type_id => undef });
    };

    subtest "check can't set priority that isn't for a category" => sub {
        $report->discard_changes;
        $report->update({ category => 'Cows', response_priority_id => $rp->id });
        $report->discard_changes;
        is $report->response_priority->id, $rp->id, 'response priority set';
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_category' });
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({
            button => 'save',
            with_fields => {
                priority => $rp2->id,
            }
        });

        $report->discard_changes;
        is $report->response_priority, undef, 'response priority set';
    };

    subtest "check can unset priority" => sub {
        $report->discard_changes;
        $report->update({ category => 'Cows', response_priority_id => $rp->id });
        $report->discard_changes;
        is $report->response_priority->id, $rp->id, 'response priority set';
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_category' });
        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({
            button => 'save',
            with_fields => {
                priority => "",
            }
        });

        $report->discard_changes;
        is $report->response_priority, undef, 'response priority unset';
    };

    subtest "check nearest address display" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->content_lacks('Nearest calculated address', 'No address displayed');

        my $data = {
            resourceSets => [ {
                resources => [ {
                    address => {
                        addressLine => 'Constitution Hill',
                        locality => 'London',
                    }
                } ],
            } ],
        };
        $report->geocode($data);
        $report->update;
        $mech->get_ok("/report/$report_id");
        $mech->content_lacks('Nearest calculated address', 'No address displayed');

        $data = {
            resourceSets => [ {
                resources => [ {
                    name => 'Constitution Hill, London, SW1A',
                    address => {
                        addressLine => 'Constitution Hill',
                        locality => 'London',
                    }
                } ],
            } ],
        };
        $report->geocode($data);
        $report->update;
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Nearest calculated address', 'Address displayed');
        $mech->content_contains('Constitution Hill, London, SW1A', 'Correct address displayed');
    }
};

foreach my $test (
    { cobrand => 'fixmystreet', limited => 0, desc => 'detailed_information has no max length' },
    { cobrand => 'oxfordshire', limited => 1, desc => 'detailed_information has max length'  },
) {

    FixMyStreet::override_config {
      ALLOWED_COBRANDS => $test->{cobrand},
    }, sub {
        my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Oxfordshire');
        $cobrand->mock('available_permissions', sub {
            my $self = shift;

            my $perms = FixMyStreet::Cobrand::Default->available_permissions;

            return $perms;
        });
        subtest $test->{desc} => sub {
            $user->user_body_permissions->delete;
            $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });
            $mech->get_ok("/report/$report_id");
            $mech->submit_form_ok({
                button => 'save',
                with_fields => {
                    include_update => 0,
                    detailed_information => 'XXX164XXX' . 'x' x (164-9)
                }
            });

            $report->discard_changes;
            like $report->get_extra_metadata('detailed_information'), qr/XXX164XXX/, 'detailed information saved';
            $mech->content_lacks('limited to 164 characters', "164 charcters of detailed information ok");
            $mech->content_contains('XXX164XXX', "Detailed information field contains submitted text");

            $mech->submit_form_ok({
                button => 'save',
                with_fields => {
                    include_update => 0,
                    detailed_information => 'XXX165XXX' . 'x' x (164-8)
                }
            });
            if ($test->{limited}) {
                $mech->content_contains('164 characters maximum');
                $mech->content_contains('limited to 164 characters', "165 charcters of detailed information not ok");
                $mech->content_contains('XXX165XXX', "Detailed information field contains submitted text");

                $report->discard_changes;
                like $report->get_extra_metadata('detailed_information'), qr/XXX164XXX/, 'detailed information not saved';
            } else {
                $mech->content_lacks(' characters maximum');
                $mech->content_lacks('limited to 164 characters', "165 charcters of detailed information ok");
                $mech->content_contains('XXX165XXX', "Detailed information field contains submitted text");

                $report->discard_changes;
                like $report->get_extra_metadata('detailed_information'), qr/XXX165XXX/, 'detailed information saved';
            }
        };
    };
}

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'oxfordshire',
}, sub {
    my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Oxfordshire');
    $cobrand->mock('available_permissions', sub {
        my $self = shift;

        my $perms = FixMyStreet::Cobrand::Default->available_permissions;

        return $perms;
    });
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

    subtest "admin link present on inspect page on cobrand" => sub {
        my $report_edit_permission = $user->user_body_permissions->create({
            body => $oxon, permission_type => 'report_edit' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('/admin/report_edit/'.$report_id.'">admin</a>)');
        $report_edit_permission->delete;
    };
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest "test category not updated if fail to include public update" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->submit_form(button => 'save', with_fields => { category => 'Badgers' });

        $report->discard_changes;
        is $report->category, "Cows", "Report in correct category";
        $mech->content_contains('Badgers" selected', 'Changed category still selected');
    };

    subtest "test invalid form maintains Category and priority" => sub {
        $mech->get_ok("/report/$report_id");
        my $expected_fields = {
          state => 'action scheduled',
          category => 'Cows',
          non_public => undef,
          public_update => '',
          priority => $rp->id,
          include_update => '1',
          detailed_information => 'XXX164XXXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          defect_type => '',
          traffic_information => ''
        };
        my $values = $mech->visible_form_values('report_inspect_form');
        is_deeply $values, $expected_fields, 'correct form fields present';

        $mech->submit_form(button => 'save', with_fields => { category => 'Badgers', priority => $rp2->id });

        $expected_fields->{category} = 'Badgers';
        $expected_fields->{priority} = $rp2->id;

        my $new_values = $mech->visible_form_values('report_inspect_form');
        is_deeply $new_values, $expected_fields, 'correct form fields present';
    };

    subtest "test changing category and leaving an update only creates one comment" => sub {
        $report->comments->delete;
        $mech->get_ok("/report/$report_id");
        $mech->submit_form(
            button => 'save',
            with_fields => {
                category => 'Badgers',
                include_update => 1,
                public_update => 'This is a public update',
        });

        $report->discard_changes;
        is $report->category, "Badgers", "Report in correct category";
        is $report->comments->count, 1, "Only leaves one update";
        like $report->comments->first->text, qr/Category changed.*Badgers/, 'update text included category change';
    };

    subtest "test non-public changing" => sub {
        $report->comments->delete;
        is $report->non_public, 0, 'Not set to non-public';
        $mech->get_ok("/report/$report_id");
        $mech->submit_form(button => 'save', with_fields => { include_update => 0, non_public => 1 });
        is $report->comments->count, 0, "No updates left";
        $report->discard_changes;
        is $report->non_public, 1, 'Now set to non-public';
        $mech->submit_form(button => 'save', with_fields => { include_update => 0, non_public => 0 });
        is $report->comments->count, 0, "No updates left";
        $report->discard_changes;
        is $report->non_public, 0, 'Not set to non-public';
    };

    subtest "test saved-at setting" => sub {
        $report->comments->delete;
        $mech->get_ok("/report/$report_id");
        # set the timezone on this so the date comparison below doesn't fail due to mismatched
        # timezones
        my $now = DateTime->now(
            time_zone => FixMyStreet->local_time_zone
        )->subtract(days => 1);
        $mech->submit_form(button => 'save', form_id => 'report_inspect_form',
            fields => { include_update => 1, public_update => 'An update', saved_at => $now->epoch });
        $report->discard_changes;
        is $report->comments->count, 1, "One update";
        is $report->comments->first->confirmed, $now;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'oxfordshire', 'fixmystreet' ],
    BASE_URL => 'http://fixmystreet.site',
}, sub {
    my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Oxfordshire');
    $cobrand->mock('available_permissions', sub {
        my $self = shift;

        my $perms = FixMyStreet::Cobrand::Default->available_permissions;

        return $perms;
    });
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
        is $report->bodies_str, $oxfordcity->id, "Reported to Oxford City";

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
