# TODO
# Overdue alerts

use utf8;
use DateTime;
use Email::MIME;
use File::Temp;
use LWP::Protocol::PSGI;
use Test::LongString;
use Test::MockModule;
use Path::Tiny;
use t::Mock::MapItZurich;
use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Check that you have the required locale installed - the following
# should return a line with de_CH.utf8 in. If not install that locale.
#
#     locale -a | grep de_CH
#
# To generate the translations use:
#
#     commonlib/bin/gettext-makemo FixMyStreet

use FixMyStreet;
my $cobrand = FixMyStreet::Cobrand::Zurich->new();
$cobrand->db_state_migration;

my $sample_file = path(__FILE__)->parent->parent->child("app/controller/sample.jpg");
ok $sample_file->exists, "sample file $sample_file exists";

sub send_reports_for_zurich {
    FixMyStreet::Script::Reports::send();
}
sub reset_report_state {
    my ($report, $created) = @_;
    $report->discard_changes;
    $report->unset_extra_metadata('moderated_overdue');
    $report->unset_extra_metadata('subdiv_overdue');
    $report->unset_extra_metadata('closed_overdue');
    $report->unset_extra_metadata('closure_status');
    $report->whensent(undef);
    $report->state('submitted');
    $report->created($created) if $created;
    $report->category('Other');
    $report->update;
}

my $UPLOAD_DIR = File::Temp->newdir();
FixMyStreet::override_config {
    STAGING_FLAGS => { send_reports => 1 },
    BASE_URL => 'https://www.zurich',
    ALLOWED_COBRANDS => 'zurich',
    MAPIT_URL => 'http://mapit.zurich/',
    MAPIT_TYPES => [ 'O08' ],
    MAPIT_ID_WHITELIST => [ 423017 ],
    MAP_TYPE => 'Zurich,OSM',
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {

# Front page test
ok $mech->host("zurich.example.com"), "change host to Zurich";
$mech->get_ok('/');
$mech->content_like( qr/zurich/i );

# Set up bodies
my $zurich = $mech->create_body_ok( 1, 'Zurich' );
my $division = $mech->create_body_ok( 423017, 'Division 1', {
    parent => $zurich->id, send_method => 'Zurich', endpoint => 'division@example.org' } );
my $division2 = $mech->create_body_ok( 423017, 'Division 2', {
    parent => $zurich->id, send_method => 'Zurich', endpoint => 'division2@example.org' } );
my $subdivision = $mech->create_body_ok( 3, 'Subdivision A',
    { parent => $division->id, send_method => 'Zurich', endpoint => 'subdivision@example.org' } );
my $external_body = $mech->create_body_ok( 4, 'External Body',
    { send_method => 'Zurich', endpoint => 'external_body@example.net' } );
my $external_body2 = $mech->create_body_ok( 4, 'Another Body External',
    { send_method => 'Zurich', endpoint => 'external_body2@example.net' } );

sub get_export_rows_count {
    my $mech = shift;
    my $extra = shift || '';
    $mech->get_ok( '/admin/stats?export=1' . $extra);
    is $mech->res->code, 200, 'csv retrieved ok';
    is $mech->content_type, 'text/csv', 'content_type correct' and do {
        my @lines = split /\n/, $mech->content;
        return @lines - 1;
    };
    return;
}

my $EXISTING_REPORT_COUNT = 0;

my $superuser;
subtest "set up superuser" => sub {
    $superuser = $mech->log_in_ok( 'super@example.org' );
    # a user from body $zurich is a superuser, as $zurich has no parent id!
    $superuser->update({ name => 'Superuser', from_body => $zurich->id });
    $EXISTING_REPORT_COUNT = get_export_rows_count($mech);
    $mech->log_out_ok;
};

my @reports = $mech->create_problems_for_body( 1, $division->id, 'Test', {
    state              => 'submitted',
    confirmed          => undef,
    cobrand            => 'zurich',
    areas => ',423017,',
});
my $report = $reports[0];

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Überprüfung ausstehend')
    or die $mech->content;

my $json = $mech->get_ok_json( '/report/ajax/' . $report->id );
is $json->{report}->{title}, "Überprüfung ausstehend", "correct title";
is $json->{report}->{state}, "submitted", "correct state";

$report->state('fixed - council');
$report->set_extra_metadata(public_response => 'Freundliche Grüsse');
$report->update;
$json = $mech->get_ok_json( '/report/ajax/' . $report->id );
is $json->{report}->{state}, "closed", "correct state";
is $json->{updates}->{details}, "Freundliche Grüsse", "correct public response";

$report->update({ state => 'submitted' });

subtest "Banners are displayed correctly" => sub {
    for my $test (
        {
            description => 'new report',
            state => 'submitted',
            banner_id => 'closed',
            banner_text => 'Erfasst'
        },
        {
            description => 'confirmed report',
            state => 'confirmed',
            banner_id => 'closed',
            banner_text => 'Aufgenommen',
        },
        {
            description => 'fixed report',
            state => 'fixed - council',
            banner_id => 'fixed',
            banner_text => 'Beantwortet',
        },
        {
            description => 'closed report',
            state => 'external',
            banner_id => 'fixed',
            banner_text => 'Beantwortet',
        },
        {
            description => 'in progress report',
            state => 'in progress',
            banner_id => 'progress',
            banner_text => 'In Bearbeitung',
        },
        {
            description => 'planned report',
            state => 'feedback pending',
            banner_id => 'progress',
            banner_text => 'In Bearbeitung',
        },
        {
            description => 'jurisdiction unknown',
            state => 'jurisdiction unknown',
            banner_id => 'fixed',
            banner_text => 'Zust\x{e4}ndigkeit unbekannt',
        },
    ) {
        subtest "banner for $test->{description}" => sub {
            $report->state( $test->{state} );
            $report->update;

            $mech->get_ok("/report/" . $report->id);
            is $mech->uri->path, "/report/" . $report->id, "at /report/" . $report->id;
            my $banner = $mech->extract_problem_banner;
            if ( $banner->{text} ) {
                $banner->{text} =~ s/^ //g;
                $banner->{text} =~ s/ $//g;
            }

            if ( $test->{banner_id} ) {
                ok $banner->{class} =~ /banner--$test->{banner_id}/i, 'banner class';
            } else {
                is $banner->{class}, $test->{banner_id}, 'banner class';
            }

            if ($test->{banner_text}) {
                like_string( $banner->{text}, qr/$test->{banner_text}/i, 'banner text is ' . $test->{banner_text} );
            } else {
                is $banner->{text}, $test->{banner_text}, 'banner text';
            }

        };
    }
    $report->update({ state => 'submitted' });
};

my $user;
subtest 'check logging in to deal with this report' => sub {
    $mech->get_ok( '/admin' );
    is $mech->uri->path, '/auth', "got sent to the sign in page";

    $user = $mech->log_in_ok( 'dm1@example.org') ;
    $user->from_body( undef );
    $user->update;
    ok $mech->get( '/admin' );
    is $mech->res->code, 403, 'Got 403';
    $user->from_body( $division->id );
    $user->update;

    $mech->get_ok( '/admin' );
    is $mech->uri->path, '/admin', "am logged in";

    $mech->content_contains( 'report_edit/' . $report->id );
    $mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );
    $mech->content_contains( 'Erfasst' );
};

subtest "changing of categories" => sub {
    # create a few categories (which are actually contacts)
    foreach my $name ( qw/Cat1 Cat2/ ) {
        $mech->create_contact_ok(
            body => $division,
            category => $name,
            email => "$name\@example.org",
        );
    }

    # full Categories dropdown is hidden for submitted reports
    $report->update({ state => 'confirmed' });

    # put report into known category
    my $original_category = $report->category;
    $report->update({ category => 'Cat1' });
    is( $report->category, "Cat1", "Category set to Cat1" );

    # get the latest comment
    my $comments_rs = $report->comments->search({},{ order_by => { -desc => "created" } });
    ok ( !$comments_rs->first, "There are no comments yet" );

    # change the category via the web interface
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { category => 'Cat2' } } );

    # check changes correctly saved
    $report->discard_changes();
    is( $report->category, "Cat2", "Category changed to Cat2 as expected" );

    # Check that a new comment has been created.
    my $new_comment = $comments_rs->first();
    is( $new_comment->text, "Weitergeleitet von Cat1 an Cat2", "category change comment created" );

    # restore report to original category.
    $report->update({category => $original_category });
};

subtest "private categories" => sub {
    $mech->log_in_ok( 'super@example.org' );
    $mech->get_ok('/admin/bodies');
    $mech->follow_link_ok({ text => 'Division 1' });
    $mech->submit_form_ok({ with_fields => {
        category => 'Allgemein',
        state => 'inactive',
        email => 'allgemein@example.org',
        'extra[admin_label]' => 'StadtPeople',
        'extra[abbreviation]' => 'STA',
        note => 'New',
    }});
    $mech->follow_link_ok({ text => 'Allgemein' });
    $mech->content_contains('<option value="inactive" selected>');
    $mech->content_like(qr/admin_label.*?StadtPeople/);

    $mech->get_ok( '/around?lat=47.381817&lon=8.529156' );
    $mech->content_lacks('StadtPeople');
    $mech->content_contains('Allgemein');
    $mech->get_ok( '/report/new?lat=47.381817&lon=8.529156' );
    $mech->content_lacks('StadtPeople');
    $mech->content_lacks('Allgemein');

    $report->update({ category => 'Allgemein' });
    $mech->get_ok('/report/' . $report->id);
    $mech->content_lacks('StadtPeople');
    $mech->content_contains('Allgemein');

    $mech->get_ok('/admin/report_edit/' . $report->id);
    $mech->content_contains('<option value="Allgemein">StadtPeople (STA)</option>');
};

sub get_moderated_count {
    # my %date_params = ( );
    # my $moderated = FixMyStreet::DB->resultset('Problem')->search({
    #     extra => { like => '%moderated_overdue,I1:0%' }, %date_params } )->count;
    # return $moderated;

    # use a separate mech to avoid stomping on test state
    my $mech = FixMyStreet::TestMech->new;
    $mech->log_in_ok( 'super@example.org' );

    $mech->get( '/admin/stats' );
    if ($mech->content =~/Innerhalb eines Arbeitstages moderiert: (\d+)/) {
        return $1;
    } else {
        fail sprintf "Could not get moderation results (%d)", $mech->status;
        return undef;
    }
}

subtest "report_edit" => sub {

    reset_report_state($report);
    ok ( ! $report->get_extra_metadata('moderated_overdue'), 'Report currently unmoderated' );
    is get_moderated_count(), 0;

    $mech->log_in_ok( 'dm1@example.org') ;
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains( 'Unbestätigt' ); # Unconfirmed email
    $mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
    $mech->get_ok( '/report/' . $report->id );

    $report->discard_changes();

    $mech->content_contains('Aufgenommen');
    $mech->content_contains('Test Test');
    $mech->content_lacks('photo/' . $report->id . '.0.jpeg');
    $mech->email_count_is(0);

    $report->discard_changes;

    is ( $report->get_extra_metadata('moderated_overdue'), 0, 'Report now marked moderated' );
    is get_moderated_count(), 1;

    # Set state back to 10 days ago so that report is overdue
    my $created = $report->created;
    reset_report_state($report, $created->clone->subtract(days => 10));

    is get_moderated_count(), 0;

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
    $mech->get_ok( '/report/' . $report->id );

    $report->discard_changes;
    is ( $report->get_extra_metadata('moderated_overdue'), 1, 'moderated_overdue set correctly when overdue' );
    is get_moderated_count(), 0, 'Moderated count not increased when overdue';

    reset_report_state($report, $created);

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
    $mech->get_ok( '/report/' . $report->id );
    $report->discard_changes;
    is ( $report->get_extra_metadata('moderated_overdue'), 0, 'Marking confirmed sets moderated_overdue' );
    is ( $report->get_extra_metadata('closed_overdue'), undef, 'Marking confirmed does NOT set closed_overdue' );
    is get_moderated_count(), 1;

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'hidden' } } );
    $mech->get_ok( '/report/' . $report->id, 'still visible as response not published yet' );

    $report->discard_changes;
    is ( $report->get_extra_metadata('moderated_overdue'), 0, 'Still marked moderated_overdue' );
    is ( $report->get_extra_metadata('closed_overdue'),    undef, "Marking hidden doesn't set closed_overdue..." );
    is ( $report->state, 'feedback pending', 'Marking hidden actually sets state to feedback pending');
    is ( $report->get_extra_metadata('closure_status'), 'hidden', 'Marking hidden sets closure_status to hidden');
    is get_moderated_count(), 1, 'Check still counted moderated'
        or diag $report->get_column('extra');

    # publishing actually sets hidden
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->form_with_fields( 'status_update' );
    $mech->submit_form_ok( { button => 'publish_response' } );
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $report->discard_changes;

    is ( $report->get_extra_metadata('closed_overdue'),    0, "Closing as hidden sets closed_overdue..." );
    is ( $report->state, 'hidden', 'Closing as hidden sets state to hidden');
    is ( $report->get_extra_metadata('closure_status'), undef, 'Closing as hidden unsets closure_status');

    $mech->submit_form_ok( { with_fields => { new_internal_note => 'Initial internal note.' } } );
    $report->discard_changes;
    is ( $report->state, 'hidden', 'Another internal note does not reopen');

    $mech->get( '/report/' . $report->id);
    is $mech->res->code, 410;

    reset_report_state($report);
    is ( $report->get_extra_metadata('moderated_overdue'), undef, 'Sanity check' );
    is get_moderated_count(), 0;

    # Check that setting to 'hidden' also triggers moderation
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'hidden' } } );
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->form_with_fields( 'status_update' );
    $mech->submit_form_ok( { button => 'publish_response' } );

    $report->discard_changes;
    is ( $report->get_extra_metadata('moderated_overdue'), 0, 'Marking hidden from scratch sets moderated_overdue' );
    is ( $report->get_extra_metadata('closed_overdue'),    0, 'Marking hidden from scratch also set closed_overdue' );
    is get_moderated_count(), 1;

    is ($cobrand->get_or_check_overdue($report), 0, 'sanity check');
    $report->update({ created => $created->clone->subtract(days => 10) });
    is ($cobrand->get_or_check_overdue($report), 0, 'overdue call not increased');

    reset_report_state($report, $created);
};

# Give the report three photos
my @files = map { $_ x 40 . ".jpeg" } (1..3);
$sample_file->copy(path($UPLOAD_DIR, $_)) for @files;
$report->photo(join(',', @files));
$report->update;

subtest 'Photo publishing' => sub {
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'confirmed', publish_photo_1 => 1 } } );
    $mech->get_ok( '/around?lat=' . $report->latitude . ';lon=' . $report->longitude);
    $mech->content_lacks('photo/' . $report->id . '.0.fp.jpeg');
    $mech->content_contains('photo/' . $report->id . '.1.fp.jpeg');
    $mech->content_lacks('photo/' . $report->id . '.2.fp.jpeg');
    $mech->get_ok( '/report/' . $report->id );
    $mech->content_lacks('photo/' . $report->id . '.0.jpeg');
    $mech->content_contains('photo/' . $report->id . '.1.jpeg');
    $mech->content_lacks('photo/' . $report->id . '.2.jpeg');

    # Internal notes
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { new_internal_note => 'Initial internal note.' } } );
    $mech->submit_form_ok( { with_fields => { new_internal_note => 'Another internal note.' } } );
    $mech->content_contains( 'Initial internal note.' );
    $mech->content_contains( 'Another internal note.' );

    # Original description
    $mech->submit_form_ok( { with_fields => { detail => 'Edited details text.' } } );
    $mech->content_contains( 'Edited details text.' );
    $mech->content_contains( 'Originaltext: &ldquo;Test Test 1 for ' . $division->id . ' Detail&rdquo;' );

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { body_subdivision => $subdivision->id } } );

    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('In Bearbeitung');
    $mech->content_contains('Test Test');
};

send_reports_for_zurich();
my $email = $mech->get_email;
like $email->header('Subject'), qr/Neue Meldung/, 'subject looks okay';
like $email->header('To'), qr/subdivision\@example.org/, 'to line looks correct';
$mech->clear_emails_ok;

$mech->log_out_ok;

subtest 'SDM' => sub {
    my $user = $mech->log_in_ok( 'sdm1@example.org') ;
    $user->update({ from_body => undef });
    ok $mech->get( '/admin' );
    is $mech->res->code, 403, 'Got 403';
    $user->from_body( $subdivision->id );
    $user->update;

    $mech->get_ok( '/admin' );
    is $mech->uri->path, '/admin', "am logged in";

    $mech->content_contains( 'report_edit/' . $report->id );
    $mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );
    $mech->content_contains( 'In Bearbeitung' );

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains( 'Initial internal note' );

    $mech->submit_form_ok( { with_fields => { status_update => 'This is an update.' } } );
    is $mech->uri->path, '/admin/report_edit/' . $report->id, "still on edit page";
    $mech->content_contains('This is an update');
    ok $mech->form_with_fields( 'status_update' );
    $mech->submit_form_ok( { button => 'no_more_updates' } );
    is $mech->uri->path, '/admin/summary', "redirected now finished with report.";

    # Can still view the edit page but can't change anything
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('<input disabled');
    $mech->submit_form_ok( { with_fields => { status_update => 'This is a disallowed update.' } } );
    $mech->content_lacks('This is a disallowed update');

    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('In Bearbeitung');
    $mech->content_contains('Test Test');

    send_reports_for_zurich();
    $email = $mech->get_email;
    like $email->header('Subject'), qr/Feedback/, 'subject looks okay';
    like $email->header('To'), qr/division\@example.org/, 'to line looks correct';
    $mech->clear_emails_ok;

    $report->discard_changes;
    is $report->state, 'feedback pending', 'Report now in feedback pending state';

    subtest 'send_back' => sub {
        $report->update({ bodies_str => $subdivision->id, state => 'in progress' });
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { form_number => 2, button => 'send_back' } );
        $report->discard_changes;
        is $report->state, 'confirmed', 'Report sent back to confirmed state';
        is $report->bodies_str, $division->id, 'Report sent back to division';
    };

    subtest 'not contactable' => sub {
        $report->update({ bodies_str => $subdivision->id, state => 'in progress' });
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { button => 'not_contactable', form_number => 2 } );
        $report->discard_changes;
        is $report->state, 'feedback pending', 'Report sent back to Rueckmeldung ausstehend state';
        is $report->get_extra_metadata('closure_status'), 'not contactable', 'Report sent back to not_contactable state';
        is $report->bodies_str, $division->id, 'Report sent back to division';
    };

    $mech->log_out_ok;
};

subtest 'Test publishing of final update by DM' => sub {
    $user = $mech->log_in_ok( 'dm1@example.org');
    $mech->get_ok( '/admin' );

    reset_report_state($report);
    $report->update({ state => 'feedback pending' });

    $mech->content_contains( 'report_edit/' . $report->id );
    $mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );

    # User confirms their email address
    $report->set_extra_metadata(email_confirmed => 1);
    $report->confirmed(DateTime->now);
    $report->update;

    # Quick RSS check here, while we have a report
    $mech->get_ok('/rss/problems');

    my $module = Test::MockModule->new('FixMyStreet::Geocode::Zurich');
    $module->mock(admin_district => sub { 'Admin district' });

    $mech->get_ok( '/admin/report_edit/' . $report->id );

    $mech->content_contains('Admin district');

    $mech->content_lacks( 'Unbestätigt' ); # Confirmed email
    $mech->submit_form_ok( { with_fields => { status_update => 'FINAL UPDATE' } } );
    $mech->form_with_fields( 'status_update' );
    $mech->submit_form_ok( { button => 'publish_response' } );

    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('Beantwortet');
    $mech->content_contains('Test Test');
    $mech->content_contains('FINAL UPDATE');

    $email = $mech->get_email;
    like $email->header('To'), qr/test\@example.com/, 'to line looks correct';
    like $email->header('From'), qr/do-not-reply\@example.org/, 'from line looks correct';
    like $email->body, qr/FINAL UPDATE/, 'body looks correct';
    $mech->clear_emails_ok;
};

subtest "Assign feedback pending (via confirmed), don't confirm email, no email sent" => sub {
    @reports = $mech->create_problems_for_body( 1, $division->id, 'Second', {
        state              => 'submitted',
        confirmed          => undef,
        cobrand            => 'zurich',
        areas => ',423017,',
    });
    $report = $reports[0];

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'feedback pending' } } );
    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('In Bearbeitung');
    $mech->content_contains('Second Test');

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains( 'Unbestätigt' );
    $mech->form_with_fields( 'status_update' );
    $mech->submit_form_ok( { button => 'publish_response', with_fields => { status_update => 'FINAL UPDATE' } } );

    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('Beantwortet');
    $mech->content_contains('Second Test');
    $mech->content_contains('FINAL UPDATE');

    $mech->email_count_is(0);
    $report->discard_changes;
    is $report->get_extra_metadata('admin_send_email_template'), 'problem-closed.txt', 'correct email marked for sending';
};

subtest "Confirming report sends admin email" => sub {
    my $token = FixMyStreet::DB->resultset('Token')->create({ scope => 'problem', data => $report->id });
    $mech->get_ok('/P/' . $token->token);
    $report->discard_changes;
    is $report->get_extra_metadata('admin_send_email_template'), undef, 'template no longer set';

    $email = $mech->get_email;
    like $email->header('To'), qr/test\@example.com/, 'to line looks correct';
    like $email->header('From'), qr/do-not-reply\@example.org/, 'from line looks correct';
    like $email->body, qr/FINAL UPDATE/, 'body looks correct';
    $mech->clear_emails_ok;
};

# Report assigned to third party

@reports = $mech->create_problems_for_body( 1, $division->id, 'Third', {
    state              => 'submitted',
    confirmed          => undef,
    cobrand            => 'zurich',
    areas => ',423017,',
});
$report = $reports[0];

subtest "external report triggers email" => sub {
    my $EXTERNAL_MESSAGE = 'Look Ma, no hands!';

    # required to see body_external field
    $report->state('feedback pending');
    $report->set_extra_metadata('closure_status' => 'external');
    # Set the public_response manually here because the default one will have line breaks that get escaped as HTML, causing the comparison to fail.
    $report->set_extra_metadata('public_response' => 'Freundliche Gruesse Ihre Stadt Zuerich');
    $report->update;

    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->form_with_fields( 'publish_response' );
    $mech->submit_form_ok( {
        button => 'publish_response',
        with_fields => {
            body_external => $external_body->id,
            external_message => $EXTERNAL_MESSAGE,
        } });
    $report->discard_changes;
    $mech->get_ok( '/report/' . $report->id );

    is ($report->state, 'external', 'Report was closed correctly');
    $mech->content_contains('Beantwortet')
        or die $mech->content;
    $mech->content_contains('Third Test');
    $mech->content_contains($report->get_extra_metadata('public_response')) or die $mech->content;
    send_reports_for_zurich();
    $email = $mech->get_email;
    like $email->header('Subject'), qr/Weitergeleitete Meldung/, 'subject looks okay';
    like $email->header('To'), qr/external_body\@example.net/, 'to line looks correct';
    like $email->body, qr/External Body/, 'body has right name';
    like $email->body, qr/$EXTERNAL_MESSAGE/, 'external_message was passed on';
    unlike $email->body, qr/test\@example.com/, 'body does not contain email address';
    $mech->clear_emails_ok;

    subtest "Test third_personal boolean setting" => sub {
        $mech->get_ok( '/admin' );
        # required to see body_external field
        $report->state('feedback pending');
        $report->set_extra_metadata('closure_status' => 'external');
        $report->set_extra_metadata('public_response' => 'Freundliche Gruesse Ihre Stadt Zuerich');
        $report->update;

        is $mech->uri->path, '/admin', "am logged in";
        $mech->content_contains( 'report_edit/' . $report->id );
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->form_with_fields( 'publish_response' );
        $mech->submit_form_ok( {
            button => 'publish_response',
            with_fields => {
                body_external => $external_body->id,
                third_personal => 1,
            } });
        $mech->get_ok( '/report/' . $report->id );
        $mech->content_contains('Beantwortet');
        $mech->content_contains('Third Test');
        $mech->content_contains($report->get_extra_metadata('public_response'));
        send_reports_for_zurich();
        $email = $mech->get_email;
        like $email->header('Subject'), qr/Weitergeleitete Meldung/, 'subject looks okay';
        like $email->header('To'), qr/external_body\@example.net/, 'to line looks correct';
        like $email->body, qr/External Body/, 'body has right name';
        like $email->body, qr/test\@example.com/, 'body does contain email address';
        $mech->clear_emails_ok;
    };

    subtest "Test external wish sending" => sub {
        # set as wish
        $report->discard_changes;
        $report->state('feedback pending');
        $report->set_extra_metadata('closure_status' => 'wish');
        $report->update;
        is ($report->state, 'feedback pending', 'Sanity check') or die;

        $mech->get_ok( '/admin/report_edit/' . $report->id );

        $mech->form_with_fields( 'publish_response' );
        $mech->submit_form_ok( {
            button => 'publish_response',
            with_fields => {
                body_external => $external_body->id,
                external_message => $EXTERNAL_MESSAGE,
            } });
        # Wishes publicly viewable
        $mech->get_ok( '/report/' . $report->id );
        $mech->content_contains('Freundliche Gruesse Ihre Stadt Zuerich');
        send_reports_for_zurich();
        $email = $mech->get_email;
        like $email->header('Subject'), qr/Weitergeleitete Meldung/, 'subject looks okay';
        like $email->header('To'), qr/external_body\@example.net/, 'to line looks correct';
        like $email->body, qr/External Body/, 'body has right name';
        like $email->body, qr/$EXTERNAL_MESSAGE/, 'external_message was passed on';
        like $email->body, qr/test\@example.com/, 'body contains email address';
        $mech->clear_emails_ok;
    };

    subtest "Closure email includes public response" => sub {
        my $PUBLIC_RESPONSE = "This is the public response to your report. Freundliche Gruesse.";
        # set as extern
        reset_report_state($report);
        $report->state('feedback pending');
        $report->set_extra_metadata('closure_status' => 'external');
        $report->set_extra_metadata('email_confirmed' => 1);
        $report->unset_extra_metadata('public_response');
        $report->update;
        is ($report->state, 'feedback pending', 'Sanity check') or die;

        $mech->get_ok( '/admin/report_edit/' . $report->id );

        $mech->form_with_fields( 'publish_response' );
        $mech->submit_form_ok( {
            button => 'publish_response',
            with_fields => {
                body_external => $external_body->id,
                external_message => $EXTERNAL_MESSAGE,
                status_update => $PUBLIC_RESPONSE,
            } });

        $email = $mech->get_email;
        my $report_id = $report->id;
        like Encode::decode('MIME-Header', $email->header('Subject')), qr/Meldung #$report_id/, 'subject looks okay';
        like $email->header('To'), qr/test\@example.com/, 'to line looks correct';
        like $email->body, qr/$PUBLIC_RESPONSE/, 'public_response was passed on' or die $email->body;
        $mech->clear_emails_ok;
    };
    $report->comments->delete; # delete the comments, as they confuse later tests
};

subtest "superuser and dm can see stats" => sub {
    $mech->log_out_ok;
    $user = $mech->log_in_ok( 'super@example.org' );

    $mech->get( '/admin/stats' );
    is $mech->res->code, 200, "superuser should be able to see stats page";
    $mech->log_out_ok;

    $user = $mech->log_in_ok( 'dm1@example.org' );
    $mech->get( '/admin/stats' );
    is $mech->res->code, 200, "dm can now also see stats page";
};

subtest "only superuser can edit bodies" => sub {
    $mech->get( '/admin/body/' . $zurich->id );
    is $mech->res->code, 403, "only superuser should be able to edit bodies";
};

subtest "only superuser can see 'Add body' form" => sub {
    $mech->get_ok( '/admin/bodies' );
    $mech->content_contains('External Body');
    $mech->content_lacks( '<form method="post" action="bodies"' );
};

subtest "phone number is mandatory" => sub {
    $mech->get_ok( '/report/new?lat=47.381817&lon=8.529156' );
    $mech->submit_form( with_fields => { phone => "" } );
    $mech->content_contains( 'Diese Information wird benötigt' );
};

my $internal;
subtest 'test flagged users make internal reports' => sub {
    $user->update({ flagged => 1 });
    $mech->submit_form( with_fields => { phone => "01234", category => 'Cat1', detail => 'Details' } );
    $internal = FixMyStreet::DB->resultset('Problem')->search(undef, { order_by => { -desc => 'id' }, rows => 1 })->single;
    is $internal->non_public, 1;
    $mech->clear_emails_ok;
};

subtest 'internal report admin display' => sub {
    $mech->get_ok('/admin/summary');
    $mech->content_lacks('href="report_edit/' . $internal->id);
    $mech->get_ok('/admin/summary?internal=1');
    $mech->content_contains('href="report_edit/' . $internal->id);
};

subtest 'test no email sent if closed' => sub {
    $internal->state('feedback pending');
    $internal->set_extra_metadata('email_confirmed' => 1);
    $internal->update;

    $mech->get_ok( '/admin/report_edit/' . $internal->id );
    $mech->submit_form_ok( {
        button => 'publish_response',
        with_fields => {
            status_update => 'Testing no email sent',
        } });

    $internal->discard_changes;
    is $internal->state, 'fixed - council';
    $mech->email_count_is(0);
};

subtest 'SDM closing internal report' => sub {
    $mech->log_in_ok('sdm1@example.org');
    $internal->update({ bodies_str => $subdivision->id, state => 'confirmed' });
    $mech->get_ok('/admin/report_edit/' . $internal->id);
    $mech->submit_form_ok( { form_number => 2, button => 'no_more_updates' } );
    $internal->discard_changes;
    is $internal->state, 'fixed - council', 'State updated';
};

subtest 'remove internal flag' => sub {
    $internal->update({ bodies_str => $subdivision->id, state => 'confirmed' });
    $mech->get_ok('/admin/report_edit/' . $internal->id);
    $mech->submit_form_ok( { form_number => 2, button => 'stop_internal' } );
    $internal->discard_changes;
    is $internal->non_public, 0;
    $internal->delete;
    $mech->log_out_ok;
};

subtest "phone number is not mandatory for reports from mobile apps" => sub {
    $mech->post_ok( '/report/new/mobile?lat=47.381817&lon=8.529156' , {
        service => 'iPhone',
        detail => 'Problem-Bericht',
        lat => 47.381817,
        lon => 8.529156,
        email => 'user@example.org',
        pc => '',
        name => '',
        category => 'bad category',
    });
    my $res = $mech->response;
    ok $res->header('Content-Type') =~ m{^application/json\b}, 'response should be json';
    unlike $res->content, qr/Diese Information wird benötigt/, 'response should not contain phone error';
    # Clear out the mailq
    $mech->clear_emails_ok;
};

subtest "link external body to category" => sub {
    $mech->log_in_ok( 'super@example.org' );
    $mech->get_ok( '/admin/body/' . $zurich->id );
    $mech->content_lacks('extra[category]');
    $mech->get_ok( '/admin/body/' . $division->id );
    $mech->content_lacks('extra[category]');
    $mech->get_ok( '/admin/body/' . $subdivision->id );
    $mech->content_lacks('extra[category]');
    $mech->get_ok( '/admin/body/' . $external_body->id );
    $mech->content_contains('extra[category]');
    $mech->submit_form_ok({ with_fields => { 'extra[category]' => 'Cat1' } });
    $mech->content_contains('<option value="Cat1" selected>');
    $external_body->discard_changes;
    is $external_body->get_extra_metadata('category'), 'Cat1';
};

subtest "shows correct external bodies" => sub {
    $report->discard_changes;
    $report->state('feedback pending');
    $report->set_extra_metadata('closure_status' => 'external');
    $report->update;
    $user = $mech->log_in_ok( 'dm1@example.org' );
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_like(qr/<option[^>]*>External Body<\/option>\s*<option[^>]*>Another Body External<\/option>/); # Test order

    $user = $mech->log_in_ok( 'dm2@example.org' );
    $user->update({ from_body => $division2->id });
    $report->update({ bodies_str => $division2->id });
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains('Another Body External');
    $mech->content_lacks('External Body');
    $report->update({ bodies_str => $division->id });
};

subtest "problems can't be assigned to deleted bodies" => sub {
    $user = $mech->log_in_ok( 'dm1@example.org' );
    $user->from_body( $zurich->id );
    $user->update;
    $report->state( 'confirmed' );
    $report->update;
    $mech->get_ok( '/admin/body/' . $external_body->id );
    $mech->submit_form_ok( { with_fields => { deleted => 1 } } );
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_lacks( $external_body->name )
        or do {
            diag $mech->content;
            diag $external_body->name;
            die;
        };
    $user->from_body( $division->id );
    $user->update;
    $mech->log_out_ok;
};

subtest "photo must be supplied for categories that require it" => sub {
    FixMyStreet::DB->resultset('Contact')->find_or_create({
        body => $division,
        category => "Graffiti - photo required",
        email => "graffiti\@example.org",
        state => 'confirmed',
        editor => "editor",
        whenedited => DateTime->now(),
        note => "note for graffiti",
        extra => { photo_required => 1 }
    });
    $mech->get_ok('/report/new?lat=47.381817&lon=8.529156');
    $mech->submit_form_ok({ with_fields => {
        detail => 'Problem-Bericht',
        username_register => 'user@example.org',
        category => 'Graffiti - photo required',
    }});
    is $mech->res->code, 200, "missing photo shouldn't return anything but 200";
    $mech->content_contains(_("Photo is required."), 'response should contain photo error message');
};

subtest "test stats" => sub {
    $user = $mech->log_in_ok( 'super@example.org' );

    $mech->get_ok( '/admin/stats' );
    is $mech->res->code, 200, "superuser should be able to see stats page";

    $mech->content_contains('Innerhalb eines Arbeitstages moderiert: 3');
    $mech->content_contains('Innerhalb von fünf Arbeitstagen abgeschlossen: 3');
    # my @data = $mech->content =~ /(?:moderiert|abgeschlossen): \d+/g;
    # diag Dumper(\@data); use Data::Dumper;

    $report->update({ non_public => 1 });

    my $export_count = get_export_rows_count($mech);
    if (defined $export_count) {
        is $export_count - $EXISTING_REPORT_COUNT, 3, 'Correct number of reports';
        $mech->content_contains('fixed - council');
    }

    $mech->content_contains('Hydranten-Nr.,"Interne meldung"');
    $mech->content_contains('"This is the public response to your report. Freundliche Gruesse.",,,,,1', "Internal report is marked as such");
    $report->update({ non_public => 0 });

    $export_count =  get_export_rows_count($mech, '&ym=' . DateTime->now->strftime("%m.%Y"));
    is $export_count - $EXISTING_REPORT_COUNT, 3, 'Correct number of reports when filtering by month';
};

subtest "test admin_log" => sub {
    my @entries = FixMyStreet::DB->resultset('AdminLog')->search({
        object_type => 'problem',
        object_id   => $report->id,
    });

    # XXX: following is dependent on all of test up till now, rewrite to explicitly
    # test which things need to be logged!
    is scalar @entries, 4, 'State changes logged';
    is $entries[-1]->action, 'state change to external', 'State change logged as expected';
};

subtest 'email images to external partners' => sub {
    reset_report_state($report);

    my $photo = path(__FILE__)->parent->child('zurich-logo_portal.x.jpg')->slurp_raw;
    my $photoset = FixMyStreet::App::Model::PhotoSet->new({
        data_items => [ $photo ],
    });
    my $fileid = $photoset->data;

    $report->set_extra_metadata('publish_photo' => { 0 => 1 });
    # The below email comparison must not have an external message.
    $report->unset_extra_metadata('external_message');
    $report->update({
        state => 'external',
        photo => $fileid,
        external_body => $external_body->id,
    });

    $mech->clear_emails_ok;
    send_reports_for_zurich();

    my @emails = $mech->get_email;
    my $email_as_string = $mech->get_first_email(@emails);
    my ($boundary) = $email_as_string =~ /boundary="([A-Za-z0-9.]*)"/ms;
    my $email = Email::MIME->new($email_as_string);

    my $expected_email_content = path(__FILE__)->parent->child('zurich_attachments.txt')->slurp;

    my $REPORT_ID = $report->id;
    $expected_email_content =~ s{Subject: (.*?)\r?\n}{
        my $subj = Encode::decode('MIME-Header', $1);
        $subj =~ s{REPORT_ID}{$REPORT_ID}g;
        'Subject: ' . Email::MIME::Encode::mime_encode($subj, "utf-8", 9) . "\n";
    }eg;
    $expected_email_content =~ s{REPORT_ID}{$REPORT_ID}g;
    $expected_email_content =~ s{BOUNDARY}{$boundary}g;
    my $expected_email = Email::MIME->new($expected_email_content);

    my @email_parts;
    $email->walk_parts(sub {
        my ($part) = @_;
        push @email_parts, [ { $part->header_pairs }, $part->body ];
    });
    my @expected_email_parts;
    $expected_email->walk_parts(sub {
        my ($part) = @_;
        push @expected_email_parts, [ { $part->header_pairs }, $part->body ];
    });
    is_deeply \@email_parts, \@expected_email_parts, 'MIME email text ok'
        or do {
            (my $test_name = $0) =~ s{/}{_}g;
            my $path = path("test-output-$test_name.tmp");
            $path->spew($email_as_string);
            diag "Saved output in $path";
        };
};

subtest 'Status update shown as appropriate' => sub {
    # ALL closed states must hide the public_response edit, and public ones
    # must show the answer in blue.
    for (['feedback pending', 1, 0, 0],
            ['fixed - council', 0, 1, 0],
            ['external', 0, 1, 0],
            ['hidden', 0, 0, 1])
        {
        my ($state, $update, $public, $user_response) = @$_;
        $report->update({ state => $state });
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->contains_or_lacks($update, "name='status_update'");
        $mech->contains_or_lacks($public || $user_response, '<div class="admin-official-answer">');

        if ($public) {
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_contains('Antwort</h4>');
        }
    }
};

subtest 'time_spent' => sub {
    my $report = $reports[0];

    is $report->get_time_spent, 0, '0 minutes spent';
    $report->update({ state => 'in progress' });
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->form_with_fields( 'time_spent' );
    $mech->submit_form_ok( {
        with_fields => {
            time_spent => 10,
        } });
    is $report->get_time_spent, 10, '10 minutes spent';
};

$mech->log_out_ok;

subtest 'users at the top level can be edited' => sub {
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok('/admin/users/' . $superuser->id );
    $mech->content_contains('name="flagged">');
    $mech->submit_form_ok({ with_fields => { flagged => 1 } });
    $superuser->discard_changes;
    is $superuser->flagged, 1, 'Marked as flagged';
    $mech->get_ok('/admin/users/' . $superuser->id );
    $mech->content_contains('name="flagged" checked');
    $mech->submit_form_ok({ with_fields => { flagged => 0 } });
    $superuser->discard_changes;
    is $superuser->flagged, 0, 'Unmarked';
};

subtest 'A visit to /reports is okay' => sub {
    $mech->get_ok('/reports');
    $mech->content_contains('<option value="Cat1">');
};

subtest 'CSV export includes lastupdate for problem' => sub {
    $mech->get_ok( '/admin/stats?export=1' );
    is $mech->res->code, 200, 'csv retrieved ok';
    my @rows = $mech->content_as_csv;
    is $rows[0]->[3], 'Last Updated', "Last Updated field has correct column heading";
    isnt $rows[1]->[3], '', "Last Updated field isn't blank";
};

};

done_testing();
