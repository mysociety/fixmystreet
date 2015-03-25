# TODO
# Overdue alerts

use strict;
use warnings;
use DateTime;
use Test::More;
use JSON;

# Check that you have the required locale installed - the following
# should return a line with de_CH.utf8 in. If not install that locale.
#
#     locale -a | grep de_CH
#
# To generate the translations use:
#
#     commonlib/bin/gettext-makemo FixMyStreet

use FixMyStreet;
my $c = FixMyStreet::App->new();
my $cobrand = FixMyStreet::Cobrand::Zurich->new({ c => $c });
$c->stash->{cobrand} = $cobrand;

# This is a helper method that will send the reports but with the config
# correctly set - notably SEND_REPORTS_ON_STAGING needs to be true.
sub send_reports_for_zurich {
    FixMyStreet::override_config { SEND_REPORTS_ON_STAGING => 1 }, sub {
        # Actually send the report
        $c->model('DB::Problem')->send_reports('zurich');
    };
}
sub reset_report_state {
    my ($report, $created) = @_;
    $report->discard_changes;
    my $extra = $report->extra;
    delete $extra->{moderated_overdue};
    delete $extra->{subdiv_overdue};
    delete $extra->{closed_overdue};
    $report->update({
        extra   => { %$extra },
        state   => 'unconfirmed',
        $created ? ( created => $created ) : (),
    });
}

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Front page test
ok $mech->host("zurich.example.com"), "change host to Zurich";
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok('/');
};
$mech->content_like( qr/zurich/i );

# Set up bodies
my $zurich = $mech->create_body_ok( 1, 'Zurich' );
$zurich->parent( undef );
$zurich->update;
my $division = $mech->create_body_ok( 2, 'Division 1' );
$division->parent( $zurich->id );
$division->send_method( 'Zurich' );
$division->endpoint( 'division@example.org' );
$division->update;
my $subdivision = $mech->create_body_ok( 3, 'Subdivision A' );
$subdivision->parent( $division->id );
$subdivision->send_method( 'Zurich' );
$subdivision->endpoint( 'subdivision@example.org' );
$subdivision->update;
my $external_body = $mech->create_body_ok( 4, 'External Body' );
$external_body->send_method( 'Zurich' );
$external_body->endpoint( 'external_body@example.org' );
$external_body->update;

sub get_export_rows_count {
    my $mech = shift;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/stats?export=1' );
    };
    is $mech->res->code, 200, 'csv retrieved ok';
    is $mech->content_type, 'text/csv', 'content_type correct' and do {
        my @lines = split /\n/, $mech->content;
        return @lines - 1;
    };
    return;
}

my $EXISTING_REPORT_COUNT = 0;

subtest "set up superuser" => sub {
    my $superuser = $mech->log_in_ok( 'super@example.org' );
    # a user from body $zurich is a superuser, as $zurich has no parent id!
    $superuser->update({ from_body => $zurich->id }); 
    $EXISTING_REPORT_COUNT = get_export_rows_count($mech);
    $mech->log_out_ok;
};

my @reports = $mech->create_problems_for_body( 1, $division->id, 'Test', {
    state              => 'unconfirmed',
    confirmed          => undef,
    cobrand            => 'zurich',
});
my $report = $reports[0];

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/report/' . $report->id );
};
$mech->content_contains('&Uuml;berpr&uuml;fung ausstehend');

# Check logging in to deal with this report
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin' );
    is $mech->uri->path, '/auth', "got sent to the sign in page";

    my $user = $mech->log_in_ok( 'dm1@example.org') ;
    $user->from_body( undef );
    $user->update;
    $mech->get_ok( '/admin' );
    is $mech->uri->path, '/my', "got sent to /my";
    $user->from_body( $division->id );
    $user->update;

    $mech->get_ok( '/admin' );
};
is $mech->uri->path, '/admin', "am logged in";

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );
$mech->content_contains( 'Erfasst' );


subtest "changing of categories" => sub {
    # create a few categories (which are actually contacts)
    foreach my $name ( qw/Cat1 Cat2/ ) {
        $mech->create_contact_ok(
            body => $division,
            category => $name,
            email => "$name\@example.org",
        );
    }

    # put report into known category
    my $original_category = $report->category;
    $report->update({ category => 'Cat1' });
    is( $report->category, "Cat1", "Category set to Cat1" );

    # get the latest comment
    my $comments_rs = $report->comments->search({},{ order_by => { -desc => "created" } });
    ok ( !$comments_rs->first, "There are no comments yet" );

    # change the category via the web interface
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { with_fields => { category => 'Cat2' } } );
    };

    # check changes correctly saved
    $report->discard_changes();
    is( $report->category, "Cat2", "Category changed to Cat2 as expected" );

    # Check that a new comment has been created.
    my $new_comment = $comments_rs->first();
    is( $new_comment->text, "Weitergeleitet von Cat1 an Cat2", "category change comment created" );

    # restore report to original category.
    $report->update({category => $original_category });
};

sub get_moderated_count {
    # my %date_params = ( );
    # my $moderated = FixMyStreet::App->model('DB::Problem')->search({
    #     extra => { like => '%moderated_overdue,I1:0%' }, %date_params } )->count;
    # return $moderated;

    # use a separate mech to avoid stomping on test state
    my $mech = FixMyStreet::TestMech->new;
    my $user = $mech->log_in_ok( 'super@example.org' );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get( '/admin/stats' );
    };
    if ($mech->content =~/Innerhalb eines Arbeitstages moderiert: (\d+)/) {
        return $1;
    }
    else {
        fail sprintf "Could not get moderation results (%d)", $mech->status;
        return undef;
    }
}

subtest "report_edit" => sub {

    ok ( ! exists ${$report->extra}{moderated_overdue}, 'Report currently unmoderated' );

    is get_moderated_count(), 0;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->content_contains( 'Unbest&auml;tigt' ); # Unconfirmed email
        $mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
        $mech->get_ok( '/report/' . $report->id );
    };

    $mech->content_contains('Aufgenommen');
    $mech->content_contains('Test Test');
    $mech->content_lacks('photo/' . $report->id . '.jpeg');
    $mech->email_count_is(0);

    $report->discard_changes;

    is ( $report->extra->{moderated_overdue}, 0, 'Report now marked moderated' );
    is get_moderated_count(), 1;


    # Set state back to 10 days ago so that report is overdue
    my $created = $report->created;
    reset_report_state($report, $created->clone->subtract(days => 10));

    is get_moderated_count(), 0;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
        $mech->get_ok( '/report/' . $report->id );
    };
    $report->discard_changes;
    is ( $report->extra->{moderated_overdue}, 1, 'moderated_overdue set correctly when overdue' );
    is get_moderated_count(), 0, 'Moderated count not increased when overdue';

    reset_report_state($report, $created);

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
        $mech->get_ok( '/report/' . $report->id );
    };
    $report->discard_changes;
    is ( $report->extra->{moderated_overdue}, 0, 'Marking confirmed sets moderated_overdue' );
    is ( $report->extra->{closed_overdue}, undef, 'Marking confirmed does NOT set closed_overdue' );
    is get_moderated_count(), 1;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { with_fields => { state => 'hidden' } } );
        $mech->get_ok( '/admin/report_edit/' . $report->id );
    };
    $report->discard_changes;
    is ( $report->extra->{moderated_overdue}, 0, 'Still marked moderated_overdue' );
    is ( $report->extra->{closed_overdue},    0, 'Marking hidden also set closed_overdue' );
    is get_moderated_count(), 1, 'Check still counted moderated'
        or diag $report->get_column('extra');

    reset_report_state($report);

    is ( $report->extra->{moderated_overdue}, undef, 'Sanity check' );
    is get_moderated_count(), 0;

    # Check that setting to 'hidden' also triggers moderation
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { with_fields => { state => 'hidden' } } );
        $mech->get_ok( '/admin/report_edit/' . $report->id );
    };
    $report->discard_changes;
    is ( $report->extra->{moderated_overdue}, 0, 'Marking hidden from scratch sets moderated_overdue' );
    is ( $report->extra->{closed_overdue},    0, 'Marking hidden from scratch also set closed_overdue' );
    is get_moderated_count(), 1;

    is ($cobrand->get_or_check_overdue($report), 0, 'sanity check');
    $report->update({ created => $created->clone->subtract(days => 10) });
    is ($cobrand->get_or_check_overdue($report), 0, 'overdue call not increased');

    reset_report_state($report, $created);
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    # Photo publishing
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'confirmed', publish_photo => 1 } } );
    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('photo/' . $report->id . '.jpeg');

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
    $mech->submit_form_ok( { with_fields => { body_subdivision => $subdivision->id, send_rejected_email => 1 } } );

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

my $user = $mech->log_in_ok( 'sdm1@example.org') ;
$user->update({ from_body => undef });
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin' );
};
is $mech->uri->path, '/my', "got sent to /my";
$user->from_body( $subdivision->id );
$user->update;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin' );
};
is $mech->uri->path, '/admin', "am logged in";

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );
$mech->content_contains( 'In Bearbeitung' );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains( 'Initial internal note' );

    $mech->submit_form_ok( { with_fields => { status_update => 'This is an update.' } } );
    is $mech->uri->path, '/admin/report_edit/' . $report->id, "still on edit page";
    $mech->content_contains('This is an update');
    ok $mech->form_with_fields( 'status_update' );
    $mech->submit_form_ok( { button => 'no_more_updates' } );
    is $mech->uri->path, '/admin/summary', "redirected now finished with report.";

    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('In Bearbeitung');
    $mech->content_contains('Test Test');
};

send_reports_for_zurich();
$email = $mech->get_email;
like $email->header('Subject'), qr/Feedback/, 'subject looks okay';
like $email->header('To'), qr/division\@example.org/, 'to line looks correct';
$mech->clear_emails_ok;

$report->discard_changes;
is $report->state, 'planned', 'Report now in planned state';

$mech->log_out_ok;
$user = $mech->log_in_ok( 'dm1@example.org') ;
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin' );
};

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );

# User confirms their email address
my $extra = $report->extra;
$extra->{email_confirmed} = 1;
$report->extra ( { %$extra } );
$report->update;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_lacks( 'Unbest&auml;tigt' ); # Confirmed email
    $mech->submit_form_ok( { with_fields => { status_update => 'FINAL UPDATE' } } );
    $mech->form_with_fields( 'status_update' );
    $mech->submit_form_ok( { button => 'publish_response' } );

    $mech->get_ok( '/report/' . $report->id );
};
$mech->content_contains('Beantwortet');
$mech->content_contains('Test Test');
$mech->content_contains('FINAL UPDATE');

$email = $mech->get_email;
like $email->header('To'), qr/test\@example.com/, 'to line looks correct';
like $email->header('From'), qr/division\@example.org/, 'from line looks correct';
like $email->body, qr/FINAL UPDATE/, 'body looks correct';
$mech->clear_emails_ok;

# Assign directly to planned, don't confirm email
@reports = $mech->create_problems_for_body( 1, $division->id, 'Second', {
    state              => 'unconfirmed',
    confirmed          => undef,
    cobrand            => 'zurich',
});
$report = $reports[0];

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'planned' } } );
    $mech->get_ok( '/report/' . $report->id );
};
$mech->content_contains('In Bearbeitung');
$mech->content_contains('Second Test');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->content_contains( 'Unbest&auml;tigt' );
    $mech->submit_form_ok( { button => 'publish_response', with_fields => { status_update => 'FINAL UPDATE' } } );

    $mech->get_ok( '/report/' . $report->id );
};
$mech->content_contains('Beantwortet');
$mech->content_contains('Second Test');
$mech->content_contains('FINAL UPDATE');

$mech->email_count_is(0);

# Report assigned to third party

@reports = $mech->create_problems_for_body( 1, $division->id, 'Third', {
    state              => 'unconfirmed',
    confirmed          => undef,
    cobrand            => 'zurich',
});
$report = $reports[0];

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { body_external => $external_body->id } } );
    $mech->get_ok( '/report/' . $report->id );
};
$mech->content_contains('Beantwortet');
$mech->content_contains('Third Test');
$mech->content_contains('Wir haben Ihr Anliegen an External Body weitergeleitet');
send_reports_for_zurich();
$email = $mech->get_email;
like $email->header('Subject'), qr/Weitergeleitete Meldung/, 'subject looks okay';
like $email->header('To'), qr/external_body\@example.org/, 'to line looks correct';
like $email->body, qr/External Body/, 'body has right name';
unlike $email->body, qr/test\@example.com/, 'body does not contain email address';
$mech->clear_emails_ok;

# Test calling back, and third_personal boolean setting
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
}, sub {
    $mech->get_ok( '/admin' );
    is $mech->uri->path, '/admin', "am logged in";
    $mech->content_contains( 'report_edit/' . $report->id );
    $mech->get_ok( '/admin/report_edit/' . $report->id );
    $mech->submit_form_ok( { with_fields => { state => 'unconfirmed' } } );
    $mech->submit_form_ok( { with_fields => { body_external => $external_body->id, third_personal => 1 } } );
    $mech->get_ok( '/report/' . $report->id );
};
$mech->content_contains('Beantwortet');
$mech->content_contains('Third Test');
$mech->content_contains('Wir haben Ihr Anliegen an External Body weitergeleitet');
send_reports_for_zurich();
$email = $mech->get_email;
like $email->header('Subject'), qr/Weitergeleitete Meldung/, 'subject looks okay';
like $email->header('To'), qr/external_body\@example.org/, 'to line looks correct';
like $email->body, qr/External Body/, 'body has right name';
like $email->body, qr/test\@example.com/, 'body does contain email address';
$mech->clear_emails_ok;
$mech->log_out_ok;

subtest "only superuser can see stats" => sub {
    $user = $mech->log_in_ok( 'super@example.org' );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get( '/admin/stats' );
    };
    is $mech->res->code, 200, "superuser should be able to see stats page";
    $mech->log_out_ok;

    $user = $mech->log_in_ok( 'dm1@example.org' );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get( '/admin/stats' );
    };
    is $mech->res->code, 404, "only superuser should be able to see stats page";
    $mech->log_out_ok;
};

subtest "only superuser can edit bodies" => sub {
    $user = $mech->log_in_ok( 'dm1@example.org' );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get( '/admin/body/' . $zurich->id );
    };
    is $mech->res->code, 404, "only superuser should be able to edit bodies";
    $mech->log_out_ok;
};

subtest "only superuser can see 'Add body' form" => sub {
    $user = $mech->log_in_ok( 'dm1@example.org' );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
        MAPIT_URL => 'http://global.mapit.mysociety.org/',
        MAPIT_TYPES  => [ 'O08' ],
        MAPIT_ID_WHITELIST => [ 423017 ],
    }, sub {
        $mech->get_ok( '/admin/bodies' );
    };
    $mech->content_lacks( '<form method="post" action="bodies"' );
    $mech->log_out_ok;
};

subtest "phone number is mandatory" => sub {
    FixMyStreet::override_config {
        MAPIT_TYPES => [ 'O08' ],
        MAPIT_URL => 'http://global.mapit.mysociety.org/',
        ALLOWED_COBRANDS => [ 'zurich' ],
        MAPIT_ID_WHITELIST => [ 274456 ],
        MAPIT_GENERATION => 2,
    }, sub {
        $user = $mech->log_in_ok( 'dm1@example.org' );
        $mech->get_ok( '/report/new?lat=47.381817&lon=8.529156' );
        $mech->submit_form( with_fields => { phone => "" } );
        $mech->content_contains( 'Diese Information wird ben&ouml;tigt' );
        $mech->log_out_ok;
    };
};

subtest "phone number is not mandatory for reports from mobile apps" => sub {
    FixMyStreet::override_config {
        MAPIT_TYPES => [ 'O08' ],
        MAPIT_URL => 'http://global.mapit.mysociety.org/',
        ALLOWED_COBRANDS => [ 'zurich' ],
        MAPIT_ID_WHITELIST => [ 423017 ],
        MAPIT_GENERATION => 4,
    }, sub {
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
        unlike $res->content, qr/Diese Information wird ben&ouml;tigt/, 'response should not contain phone error';
        # Clear out the mailq
        $mech->clear_emails_ok;
    };
};

subtest "problems can't be assigned to deleted bodies" => sub {
    $user = $mech->log_in_ok( 'dm1@example.org' );
    $user->from_body( $zurich->id );
    $user->update;
    $report->state( 'confirmed' );
    $report->update;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
        MAPIT_URL => 'http://global.mapit.mysociety.org/',
        MAPIT_TYPES => [ 'O08' ],
        MAPIT_ID_WHITELIST => [ 423017 ],
    }, sub {
        $mech->get_ok( '/admin/body/' . $external_body->id );
        $mech->submit_form_ok( { with_fields => { deleted => 1 } } );
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->content_lacks( $external_body->name );
    };
    $user->from_body( $division->id );
    $user->update;
    $mech->log_out_ok;
};

subtest "hidden report email are only sent when requested" => sub {
    $user = $mech->log_in_ok( 'dm1@example.org') ;
    $extra = $report->extra;
    $extra->{email_confirmed} = 1;
    $report->extra ( { %$extra } );
    $report->update;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { with_fields => { state => 'hidden', send_rejected_email => 1 } } );
        $mech->email_count_is(1);
        $mech->clear_emails_ok;
        $mech->get_ok( '/admin/report_edit/' . $report->id );
        $mech->submit_form_ok( { with_fields => { state => 'hidden', send_rejected_email => undef } } );
        $mech->email_count_is(0);
        $mech->clear_emails_ok;
        $mech->log_out_ok;
    };
};

subtest "test stats" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'zurich' ],
    }, sub {
        $user = $mech->log_in_ok( 'super@example.org' );

        $mech->get_ok( '/admin/stats' );
        is $mech->res->code, 200, "superuser should be able to see stats page";

        $mech->content_contains('Innerhalb eines Arbeitstages moderiert: 2'); # now including hidden
        $mech->content_contains('Innerhalb von f&uuml;nf Arbeitstagen abgeschlossen: 3');
        # my @data = $mech->content =~ /(?:moderiert|abgeschlossen): \d+/g;
        # diag Dumper(\@data); use Data::Dumper;
        
        my $export_count = get_export_rows_count($mech);
        if (defined $export_count) {
            is $export_count - $EXISTING_REPORT_COUNT, 3, 'Correct number of reports';
            $mech->content_contains('fixed - council');
            $mech->content_contains(',hidden,');
        }

        $mech->log_out_ok;
    };
};

subtest "test admin_log" => sub {
    diag $report->id;
    my @entries = FixMyStreet::App->model('DB::AdminLog')->search({
        object_type => 'problem',
        object_id   => $report->id,
    });
    is scalar @entries, 4, 'State changes logged'; 
    is $entries[-1]->action, 'state change to hidden', 'State change logged as expected';
};

END {
    $mech->delete_body($subdivision);
    $mech->delete_body($division);
    $mech->delete_body($zurich);
    $mech->delete_body($external_body);
    $mech->delete_user( 'dm1@example.org' );
    $mech->delete_user( 'sdm1@example.org' );
    ok $mech->host("www.fixmystreet.com"), "change host back";
    done_testing();
}
