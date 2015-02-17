use strict;
use warnings;
use Test::More;
use utf8;

use FixMyStreet::TestMech;
use FixMyStreet::App;
use Data::Dumper;

my $mech = FixMyStreet::TestMech->new;

my $BROMLEY_ID = 2482;
my $body = $mech->create_body_ok( $BROMLEY_ID, 'Bromley Council' );

my $dt = DateTime->now;

my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test-moderation@example.com', name => 'Test User' } );
$user->user_body_permissions->delete_all;
$user->discard_changes;

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
        name               => 'Test User',
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
        user_id            => $user->id,
        photo              => $mech->get_photo_data,
    });
}
my $report = create_report();
my $report2 = create_report();

my $REPORT_URL = '/report/' . $report->id ;

subtest 'Auth' => sub {

    subtest 'Unaffiliated user cannot see moderation' => sub {
        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('Moderat');

        $mech->log_in_ok( $user->email );

        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('Moderat');

        $user->update({ from_body => $body->id });

        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('Moderat');

        $mech->get_ok('/contact?m=1&id=' . $report->id);
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
    problem_show_photo => 1,
    problem_title => 'Good bad good',
    problem_detail => 'Good bad bad bad good bad',
);

subtest 'Problem moderation' => sub {

    subtest 'Post modify title and text' => sub {
        $mech->post_ok('/moderate/report/' . $report->id, {
            %problem_prepopulated,
            problem_title  => 'Good good',
            problem_detail => 'Good good improved',
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $report->discard_changes;
        is $report->title, 'Good [...] good';
        is $report->detail, 'Good [...] good [...]improved';
    };

    subtest 'Revert title and text' => sub {
        $mech->post_ok('/moderate/report/' . $report->id, {
            %problem_prepopulated,
            problem_revert_title  => 1,
            problem_revert_detail => 1,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $report->discard_changes;
        is $report->title, 'Good bad good';
        is $report->detail, 'Good bad bad bad good bad';
    };

    subtest 'Make anonymous' => sub {
        $mech->content_lacks('Reported anonymously');

        $mech->post_ok('/moderate/report/' . $report->id, {
            %problem_prepopulated,
            problem_show_name => 0,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Reported anonymously');

        $mech->post_ok('/moderate/report/' . $report->id, {
            %problem_prepopulated,
            problem_show_name => 1,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Reported anonymously');
    };

    subtest 'Hide photo' => sub {
        $mech->content_contains('Photo of this report');

        $mech->post_ok('/moderate/report/' . $report->id, {
            %problem_prepopulated,
            problem_show_photo => 0,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Photo of this report');

        $mech->post_ok('/moderate/report/' . $report->id, {
            %problem_prepopulated,
            problem_show_photo => 1,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Photo of this report');
    };

    subtest 'Hide report' => sub {
        $mech->clear_emails_ok;

        my $resp = $mech->post('/moderate/report/' . $report->id, {
            %problem_prepopulated,
            problem_hide => 1,
        });
        $mech->base_unlike( qr{/report/}, 'redirected to front page' );

        $report->discard_changes;
        is $report->state, 'hidden', 'Is hidden';

        my $email = $mech->get_email;
        my ($url) = $email->body =~ m{(http://\S+)};
        ok $url, "extracted complain url '$url'";

        $mech->get_ok($url);
        $mech->content_contains('Good bad bad bad');

        # reset
        $report->update({ state => 'confirmed' });
    };
};

$mech->content_lacks('Posted anonymously', 'sanity check');

subtest 'Problem 2' => sub {
    my $REPORT2_URL = '/report/' . $report2->id ;
    $mech->post_ok('/moderate/report/' . $report2->id, {
        %problem_prepopulated,
        problem_title  => 'Good good',
        problem_detail => 'Good good improved',
    });
    $mech->base_like( qr{\Q$REPORT2_URL\E} );

    $report2->discard_changes;
    is $report2->title, 'Good [...] good';
    is $report2->detail, 'Good [...] good [...]improved';

    $mech->post_ok('/moderate/report/' . $report2->id, {
        %problem_prepopulated,
        problem_revert_title  => 1,
        problem_revert_detail => 1,
    });
    $mech->base_like( qr{\Q$REPORT2_URL\E} );

    $report2->discard_changes;
    is $report2->title, 'Good bad good';
    is $report2->detail, 'Good bad bad bad good bad';
};

sub create_update {
    $report->comments->create({
        user      => $user,
        name      => 'Test User',
        anonymous => 'f',
        photo     => $mech->get_photo_data,
        text      => 'update good good bad good',
        state     => 'confirmed',
        mark_fixed => 0,
    });
}
my %update_prepopulated = (
    update_show_name => 1,
    update_show_photo => 1,
    update_detail => 'update good good bad good',
);

my $update = create_update();

subtest 'updates' => sub {

    my $MODERATE_UPDATE_URL = sprintf '/moderate/report/%d/update/%d', $report->id, $update->id;

    subtest 'Update modify text' => sub {
        $mech->post_ok( $MODERATE_UPDATE_URL, {
            %update_prepopulated,
            update_detail => 'update good good good',
        }) or die $mech->content;
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $update->discard_changes;
        is $update->text, 'update good good [...] good',
    };

    subtest 'Revert text' => sub {
        $mech->post_ok( $MODERATE_UPDATE_URL, {
            %update_prepopulated,
            update_revert_detail  => 1,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $update->discard_changes;
        $update->discard_changes;
        is $update->text, 'update good good bad good',
    };

    subtest 'Make anonymous' => sub {
        $mech->content_lacks('Posted anonymously')
            or die sprintf '%d (%d)', $update->id, $report->comments->count;

        $mech->post_ok( $MODERATE_UPDATE_URL, {
            %update_prepopulated,
            update_show_name => 0,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Posted anonymously');

        $mech->post_ok( $MODERATE_UPDATE_URL, {
            %update_prepopulated,
            update_show_name => 1,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Posted anonymously');
    };

    subtest 'Hide photo' => sub {
        $report->update({ photo => undef }); # hide the main photo so we can just look for text in comment

        $mech->get_ok($REPORT_URL);

        $mech->content_contains('Photo of this report')
            or die $mech->content;

        $mech->post_ok( $MODERATE_UPDATE_URL, {
            %update_prepopulated,
            update_show_photo => 0,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_lacks('Photo of this report');

        $mech->post_ok( $MODERATE_UPDATE_URL, {
            %update_prepopulated,
            update_show_photo => 1,
        });
        $mech->base_like( qr{\Q$REPORT_URL\E} );

        $mech->content_contains('Photo of this report');
    };

    subtest 'Hide comment' => sub {
        $mech->content_contains('update good good bad good');

        $mech->post_ok( $MODERATE_UPDATE_URL, {
            %update_prepopulated,
            update_hide => 1,
        });
        $mech->content_lacks('update good good bad good');
    };

    $update->moderation_original_data->delete;
};

my $update2 = create_update();

subtest 'Update 2' => sub {
    my $MODERATE_UPDATE2_URL = sprintf '/moderate/report/%d/update/%d', $report->id, $update2->id;
    $mech->post_ok( $MODERATE_UPDATE2_URL, {
        %update_prepopulated,
        update_detail => 'update good good good',
    }) or die $mech->content;

    $update2->discard_changes;
    is $update2->text, 'update good good [...] good',
};

$update->delete;
$update2->delete;
$report->moderation_original_data->delete;
$report->delete;
$report2->delete;

done_testing();
