use Test::Trap;
use FixMyStreet::TestMech;
use_ok 'FixMyStreet::Email::Incoming';
use FixMyStreet::Email;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('systemuser@example.org');
my $body = $mech->create_body_ok(2217, 'Buckinghamshire Council', { comment_user => $user, send_extended_statuses => 1, cobrand => 'buckinghamshire' });
my $parish = $mech->create_body_ok(58815, 'Aylesbury Town Council');
my $body_hedge = $mech->create_contact_ok( body_id => $body->id, category => 'Hedge problem', email => 'hedges@example.com' );
$mech->create_contact_ok( body_id => $parish->id, category => 'Hedge problem', email => 'hedges@parish.example.com' );

my ($p) = $mech->create_problems_for_body(1, $body->id, 'Title', { category => 'Hedge problem' });
my $alert = FixMyStreet::DB->resultset("Alert")->create({
    alert_type => 'new_updates',
    user_id => $p->user_id,
});
my $id = $p->id;
my $alert_id = $alert->id;
my $token_report = FixMyStreet::Email::generate_verp_token('report', $id);
my $token_alert = FixMyStreet::Email::generate_verp_token('alert', $alert_id);

# For testing, want to turn this back on and see what we get
mySociety::SystemMisc::log_to_stderr(1);

sub email_from_template {
    my %params = @_;
    $params{RETURNPATH} = $params{RETURNPATH} ? 'from@council.example.net': '';
    my $email = <<'EOF';
Return-Path: <RETURNPATH>
From: someone@example.org
To: fms-TOKEN@example.com
Subject: SUBJECT Re: Problem report
Message-ID: <ABCDEF@GHIJKL>
HEADERS

This is the contents of the message.
EOF
    foreach (keys %params) {
        $email =~ s/$_/$params{$_}/g;
    }
    return $email;
}

sub process {
    my $email = shift;
    open my $stdin, '<', \$email;
    local *STDIN = $stdin;
    my $e = FixMyStreet::Email::Incoming->new( bouncemgr => 'contact@example.org' );
    trap { $e->process };
}

FixMyStreet::override_config {
    EMAIL_DOMAIN => 'example.com',
    ALLOWED_COBRANDS => ['buckinghamshire', 'fixmystreet', 'tfl'],
    COBRAND_FEATURES => {
        do_not_reply_email =>  {
            tfl => 'fms-tfl-do-not-reply@example.com'
        },
    },
}, sub {
    subtest 'A bad token email' => sub {
        my $email = email_from_template(TOKEN => "bad");
        process($email);
        is $trap->exit, 0, 'exited with 0';
    };

    subtest 'A bounce to the do-not-reply address' => sub {
        my $email = email_from_template(RETURNPATH => 0, TOKEN => "DO-NOT-REPLY");
        process($email);
        is $trap->stderr, "incoming.t: bounce received for don't-care email\n";
    };

    subtest 'An email to the do-not-reply address' => sub {
        my $email = email_from_template(RETURNPATH => 1, HEADERS => "X-Delivered-Suffix: -DO-NOT-REPLY");
        process($email);
        is $trap->stderr, "incoming.t: Received non-bounce to null address, auto-replying\n";
        like $mech->get_text_body_from_email, qr/This is an automatic response/;
    };

    subtest 'An email to the cobrand specific do-not-reply address' => sub {
        my $email = email_from_template(RETURNPATH => 1, TOKEN => 'tfl-do-not-reply');
        process($email);
        is $trap->stderr, "incoming.t: Received non-bounce to null address, auto-replying\n";
        like $mech->get_text_body_from_email, qr/from TfL Streetcare/;
    };

    subtest 'An OOO email to the do-not-reply address' => sub {
        my $email = email_from_template(RETURNPATH => 1, TOKEN => "DO-NOT-REPLY", SUBJECT => "Out of Office");
        process($email);
        is $trap->stderr, "incoming.t: Received non-bounce auto-reply to null address, ignoring\n";
        $mech->email_count_is(0);
    };

    subtest 'A bounce to a VERP address' => sub {
        my $email = email_from_template(RETURNPATH => 0, TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Unparsed bounce received for report $id, forwarding to support\n";
        my $env = $mech->get_email_envelope;
        is $env->{to}[0], 'contact@example.org';
        $email = $mech->get_email;
        like $email->as_string, qr/This is the contents/;
        $mech->clear_emails_ok;
    };

    subtest 'An OOO bounce to a VERP address' => sub {
        my $email = email_from_template(RETURNPATH => 0, TOKEN => $token_report, HEADERS => "X-Autoreply: true");
        process($email);
        is $trap->stderr, "incoming.t: Treating bounce for report $id as auto-reply to sender\nincoming.t: Received non-bounce for report $id, forwarding to report creator\n";
        my $env = $mech->get_email_envelope;
        is $env->{to}[0], $p->user->email;
        $email = $mech->get_email;
        like $email->as_string, qr/This is the contents/;
        $mech->clear_emails_ok;
    };

    subtest 'An email to a VERP address' => sub {
        my $email = email_from_template(RETURNPATH => 1, TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Received non-bounce for report $id, forwarding to report creator\n";
        my $env = $mech->get_email_envelope;
        is $env->{to}[0], $p->user->email;
        $email = $mech->get_email;
        like $email->as_string, qr/This is the contents/;
        $mech->clear_emails_ok;
    };

    subtest 'An email to a VERP address, report made as body' => sub {
        $p->set_extra_metadata(contributed_as => 'body');
        $p->update;
        my $email = email_from_template(RETURNPATH => 1, TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Received non-bounce for report $id to anon report, dropping\n";
        $mech->email_count_is(0);
        $p->unset_extra_metadata('contributed_as');
        $p->update;
    };

    subtest 'An email to an alert VERP address' => sub {
        my $email = email_from_template(RETURNPATH => 1, TOKEN => $token_alert);
        process($email);
        is $trap->stderr, "incoming.t: Received non-bounce for alert $alert_id, forwarding to support\n";
        my $env = $mech->get_email_envelope;
        is $env->{to}[0], 'contact@example.org';
        $email = $mech->get_email;
        like $email->as_string, qr/This is the contents/;
        $mech->clear_emails_ok;
    };

    subtest 'An OOO email to an alert VERP address' => sub {
        my $email = email_from_template(RETURNPATH => 1, TOKEN => $token_alert, HEADERS => "Auto-Submitted: yes");
        process($email);
        is $trap->stderr, '';
        $mech->email_count_is(0);
    };

    subtest 'A DSN' => sub {
        my $email = <<EOF;
Return-path: <>
Date: Thu, 11 Sep 2008 05:00:33 -0500
From: someone\@example.org
Message-Id: <message-id\@somewhere.example.org>
To: fms-$token_report\@example.com
Content-Type: multipart/report; report-type=delivery-status;
	boundary="1221127233-13870"
Subject: Returned mail: User unknown

This is a MIME-encapsulated message

--1221127233-13870
Content-type: text/plain; charset=US-ASCII

The original message was received Thu, 11 Sep 2008 05:00:32 -0500
from -

   ----- The following address(es) had permanent fatal errors -----
<anon>; originally to anon (unrecoverable error)
  	The recipient 'anon' is unknown

--1221127233-13870
Content-type: message/delivery-status

Arrival-Date: Thu, 11 Sep 2008 05:00:32 -0500

Original-Recipient: anon
Final-Recipient: anon
Action: failed
Status: 5.0.0
--1221127233-13870
Content-type: message/rfc822


-- Message body has been omitted --

--1221127233-13870--
EOF
        process($email);
        is $trap->stderr, "incoming.t: Received bounce for report $id, forwarding to support\n";
        my $env = $mech->get_email_envelope;
        is $env->{to}[0], 'contact@example.org';
        $email = $mech->get_email;
        $mech->clear_emails_ok;
    };

    subtest 'A remote host bounce to an alert VERP address' => sub {
        my $email = <<EOF;
Return-path: <>
Date: Thu, 11 Sep 2008 05:00:33 -0500
From: someone\@example.org
Message-Id: <message-id\@somewhere.example.org>
To: fms-$token_alert\@example.com
Subject: Returned mail: User unknown

This server does not like recipient.

Remote host said: 500 User does not exist - <@>

EOF
        process($email);
        is $trap->stderr, "incoming.t: Received bounce for alert $alert_id, unsubscribing\n";
        $alert->discard_changes;
        isnt $alert->whendisabled, undef;
    };

    $p->update({ cobrand => 'buckinghamshire' });

    subtest 'Bucks bad status code' => sub {
        my $email = email_from_template(RETURNPATH => 1, SUBJECT => "SC101", TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Report #$id, email subject had bad code SC101\n";
        $p->discard_changes;
        is $p->state, 'confirmed';
        is $p->comments->count, 0;
        $email = $mech->get_email;
        $mech->clear_emails_ok;
        is $email->header('Subject'), "Report #$id, email subject had bad code SC101";
    };

    subtest 'Bucks status code, auto-reply' => sub {
        my $email = email_from_template(RETURNPATH => 1, SUBJECT => "Auto-Reply", TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Received non-bounce for report $id, forwarding to report creator\n";
        my $env = $mech->get_email_envelope;
        is $env->{to}[0], $p->user->email;
        $email = $mech->get_email;
        is $email->header('Subject'), "Auto-Reply Re: Problem report";
        like $email->as_string, qr/This is the contents/;
        $mech->clear_emails_ok;
    };

    subtest 'Bucks status code, just a reply' => sub {
        my $email = email_from_template(RETURNPATH => 1, SUBJECT => "", TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Report #$id, email subject had no SC code\n";
        $email = $mech->get_email;
        $mech->clear_emails_ok;
        is $email->header('Subject'), "Report #$id, email subject had no SC code";
    };

    subtest 'Bucks status code, fixed default' => sub {
        FixMyStreet::DB->resultset("ResponseTemplate")->create({
            body => $body,
            auto_response => 1,
            external_status_code => '123',
            title => '123 fixed',
            text => 'Text of template',
        });
        my $email = email_from_template(RETURNPATH => 1, SUBJECT => "SC123", TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Received SC code in subject, updating report\n";
        $mech->email_count_is(0);
        $p->discard_changes;
        is $p->state, 'fixed - council';
        is $p->comments->count, 1;
        is $p->comments->first->text, "Text of template";
        is $p->comments->first->problem_state, "fixed - council";
        $p->comments->delete;
    };

    $p->update({ cobrand => 'fixmystreet' });

    subtest 'Bucks status code, closed status' => sub {
        FixMyStreet::DB->resultset("ResponseTemplate")->create({
            body => $body,
            auto_response => 1,
            external_status_code => '456',
            state => 'closed',
            title => '456 closed',
            text => 'Text of template',
        });
        my $email = email_from_template(RETURNPATH => 1, SUBJECT => "SC456", TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Received SC code in subject, updating report\n";
        $mech->email_count_is(0);
        $p->discard_changes;
        is $p->state, 'closed';
        is $p->comments->count, 1;
        is $p->comments->first->text, "Text of template";
        is $p->comments->first->problem_state, "closed";
        $p->comments->delete;
    };

    subtest 'Parish report, fallback template' => sub {
        my $template = FixMyStreet::DB->resultset("ResponseTemplate")->create({
            body => $body,
            auto_response => 1,
            external_status_code => '789',
            title => '789 (for the category)',
            text => 'This is a message from the body',
        });
        $template->contact_response_templates->find_or_create({
            contact_id => $body_hedge->id,
        });
        # And one with no contacts, which is the fallback
        FixMyStreet::DB->resultset("ResponseTemplate")->create({
            body => $body,
            auto_response => 1,
            external_status_code => '789',
            title => '789 (fallback)',
            text => 'This is a message from the parish',
        });

        my ($p) = $mech->create_problems_for_body(1, $parish->id, 'Title', { category => 'Hedge problem', cobrand => 'buckinghamshire' });
        my $id = $p->id;
        my $token_report = FixMyStreet::Email::generate_verp_token('report', $id);

        my $email = email_from_template(RETURNPATH => 1, SUBJECT => "SC789", TOKEN => $token_report);
        process($email);
        is $trap->stderr, "incoming.t: Received SC code in subject, updating report\n";
        $mech->email_count_is(0);
        $p->discard_changes;
        is $p->comments->count, 1;
        is $p->comments->first->text, "This is a message from the parish";
        $p->comments->delete;
    };

};

done_testing;
