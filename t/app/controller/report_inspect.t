use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $brum = $mech->create_body_ok(2514, 'Birmingham City Council', id => 2514);
my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council', id => 2237);
my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' );
my $rp = FixMyStreet::DB->resultset("ResponsePriority")->create({
    body => $oxon,
    name => 'High Priority',
});
FixMyStreet::DB->resultset("ContactResponsePriority")->create({
    contact => $contact,
    response_priority => $rp,
});
my $wodc = $mech->create_body_ok(2420, 'West Oxfordshire District Council', id => 2420);
$mech->create_contact_ok( body_id => $wodc->id, category => 'Horses', email => 'horses@example.net' );


my ($report, $report2) = $mech->create_problems_for_body(2, $oxon->id, 'Test', {
    category => 'Cows', cobrand => 'fixmystreet', areas => ',2237,2420',
    whensent => \'current_timestamp',
    latitude => 51.847693, longitude => -1.355908,
});
my $report_id = $report->id;
my $report2_id = $report2->id;


my $user = $mech->log_in_ok('test@example.com');
$user->update( { from_body => $oxon } );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.mysociety.org/',
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
        $mech->submit_form_ok({ button => 'save', with_fields => { traffic_information => 'Yes', state => 'Planned' } });
        $report->discard_changes;
        is $report->state, 'planned', 'report state changed';
        is $report->get_extra_metadata('traffic_information'), 'Yes', 'report data changed';
    };

    subtest "test inspect & instruct submission" => sub {
        $report->unset_extra_metadata('inspected');
        $report->update;
        my $reputation = $report->user->get_extra_metadata("reputation") || 0;
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { public_update => "This is a public update.", save_inspected => "1" } });
        $report->discard_changes;
        is $report->comments->first->text, "This is a public update.", 'Update was created';
        is $report->get_extra_metadata('inspected'), 1, 'report marked as inspected';
        is $report->user->get_extra_metadata('reputation'), $reputation+1, "User reputation was increased";
    };

    subtest "test update is required when instructing" => sub {
        $report->unset_extra_metadata('inspected');
        $report->update;
        $report->comments->delete_all;
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { public_update => undef, save_inspected => "1" } });
        is_deeply $mech->page_errors, [ "Please provide a public update for this report." ], 'errors match';
        $report->discard_changes;
        is $report->comments->count, 0, "Update wasn't created";
        is $report->get_extra_metadata('inspected'), undef, 'report not marked as inspected';
    };

    subtest "test location changes" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => 55, longitude => -2 } });
        $mech->content_contains('Invalid location');
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => 51.754926, longitude => -1.256179 } });
        $mech->content_lacks('Invalid location');
    };

    subtest "test duplicate reports are shown" => sub {
        my $old_state = $report->state;
        $report->set_extra_metadata('duplicate_of' => $report2->id);
        $report->state('duplicate');
        $report->update;

        $mech->get_ok("/report/$report_id");
        $mech->content_contains($report2->title);

        $mech->get_ok("/report/$report2_id");
        $mech->content_contains($report->title);

        $report->unset_extra_metadata('duplicate_of');
        $report->state($old_state);
        $report->update;
    };

    subtest "marking a report as a duplicate with update correctly sets update status" => sub {
        my $old_state = $report->state;
        $report->comments->delete_all;

        $mech->get_ok("/report/$report_id");
        $mech->submit_form_ok({ button => 'save', with_fields => { state => 'Duplicate', duplicate_of => $report2->id, public_update => "This is a duplicate.", save_inspected => "1" } });
        $report->discard_changes;

        is $report->state, 'duplicate', 'report marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 1, 'update marking report as duplicate was left';

        $report->update({ state => $old_state });
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
            save_inspected => "1",
        }});
        $report->discard_changes;

        is $report->state, 'duplicate', 'report marked as duplicate';
        is $report->comments->search({ problem_state => 'duplicate' })->count, 1, 'update marked report as duplicate';
        $mech->content_contains($update_text);
        $mech->content_lacks("Thank you for your report. This problem has already been reported.");

        $report->update({ state => $old_state });
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
    MAPIT_URL => 'http://mapit.mysociety.org/',
    ALLOWED_COBRANDS => 'oxfordshire',
}, sub {
    subtest "test negative reputation" => sub {
        my $reputation = $report->user->get_extra_metadata("reputation");

        $mech->get_ok("/report/$report_id");
        $mech->submit_form( button => 'remove_from_site' );

        $report->discard_changes;
        is $report->user->get_extra_metadata('reputation'), $reputation-1, "User reputation was decreased";
    };
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.mysociety.org/',
    ALLOWED_COBRANDS => [ 'oxfordshire', 'fixmystreet' ],
    BASE_URL => 'http://fixmystreet.site',
}, sub {
    subtest "test category/body changes" => sub {
        $mech->host('oxfordshire.fixmystreet.site');
        $report->update({ state => 'confirmed' });
        $mech->get_ok("/report/$report_id");
        # Then change the category to the other council in this location,
        # which should cause it to be resent. We clear the host because
        # otherwise testing stays on host() above.
        $mech->clear_host;
        $mech->submit_form(button => 'save', with_fields => { category => 'Horses' });

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
    $mech->delete_body($oxon);
    $mech->delete_body($brum);
    done_testing();
}
