package FixMyStreet::Email::Incoming;

use Moo;
use Path::Tiny;
use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use mySociety::HandleMail;
use mySociety::SystemMisc qw(print_log);

has cobrand => ( is => 'ro' );
has bouncemgr => ( is => 'ro' );

has data => ( is => 'lazy' );
has lines => ( is => 'lazy' );
has token => ( is => 'lazy' );
has token_parts => ( is => 'lazy' );
has type => ( is => 'lazy' );
has object => ( is => 'lazy' );

sub _build_data {
    my %data = mySociety::HandleMail::get_message();
    return \%data;
}

sub _build_lines { $_[0]->data->{lines} }

sub process {
    my $self = shift;

    if ($self->data->{is_bounce_message}) {
        if ($self->object) {
            $self->handle_bounce_to_verp_address();
        } else {
            print_log('info', "bounce received for don't-care email");
        }
    } else {
        # This is not a bounce message. If it's to a VERP address, pass it on to
        # the message sender; otherwise send an auto-reply
        if ($self->object) {
            $self->handle_non_bounce_to_verp_address();
        } else {
            $self->handle_non_bounce_to_null_address();
        }
    }
}

sub _build_token {
    my $self = shift;
    my $m = $self->data->{message};

    # If we have a special suffix header for the local part suffix, use that.
    # This is set by our exim so we have access to it through the domain name
    # forwarding and routers.
    my $suffix = $m->head()->get("X-Delivered-Suffix");
    if ($suffix) {
        chomp $suffix;
        return substr($suffix, 1);
    }

    # Otherwise, fall back to To header
    my $a = mySociety::HandleMail::get_bounce_recipient($m);

    my $token = mySociety::HandleMail::get_token($a,
        'fms-', FixMyStreet->config('EMAIL_DOMAIN')
    );
    exit 0 unless $token; # Don't care unless we have a token

    return $token;
}

sub _build_token_parts {
    my $self = shift;

    my $verp = $self->token !~ /DO-NOT-REPLY/i;
    if (!$verp) {
        return { verp => 0 };
    }

    my ($type, $id) = FixMyStreet::Email::check_verp_token($self->token);
    exit 0 unless $type;

    return { verp => 1, type => $type, id => $id };
}

sub _build_type { $_[0]->token_parts->{type} }

sub _build_object {
    my $self = shift;

    my $token_parts = $self->token_parts;
    return unless $token_parts->{verp};

    my $rs;
    if ($self->type eq 'report') {
        $rs = FixMyStreet::DB->resultset('Problem');
    } elsif ($self->type eq 'alert') {
        $rs = FixMyStreet::DB->resultset('Alert');
    }

    my $id = $token_parts->{id};
    my $object = $rs->find({ id => $id });
    exit(0) unless $object;

    return $object;
}

sub handle_permanent_bounce {
    my $self = shift;
    if ($self->type eq 'alert') {
        print_log('info', "Received bounce for alert " . $self->object->id . ", unsubscribing");
        $self->object->disable();
    } elsif ($self->type eq 'report') {
        print_log('info', "Received bounce for report " . $self->object->id . ", forwarding to support");
        $self->forward_on_to($self->bouncemgr);
    }
}

sub is_out_of_office {
    my $self = shift;
    my (%attributes) = @_;
    return 1 if $attributes{problem} && $attributes{problem} == mySociety::HandleMail::ERR_OUT_OF_OFFICE;
    my $head = $self->data->{message}->head();
    return 1 if $head->get('X-Autoreply') || $head->get('X-Autorespond');
    my $mc = $head->get('X-POST-MessageClass') || '';
    return 1 if $mc eq '9; Autoresponder';
    my $auto_submitted = $head->get("Auto-Submitted") || '';
    return 1 if $auto_submitted && $auto_submitted !~ /no/;
    my $precedence = $head->get("Precedence") || '';
    return 1 if $precedence =~ /auto_reply/;
    my $subject = $head->get("Subject");
    return 1 if $subject =~ /Auto(matic|mated)?[ -_]?(reply|response|responder)|Thank[ _]you[ _]for[ _](your[ _]email|contacting)|Out of (the )?Office|away from the office|This office is closed until|^Auto: |^E-Mail Response$|^Message Received:|have received your email|Acknowledgement of your email|away from my desk|We got your email/i;
    return 1 if $subject =~ /^Re: (Problem Report|New updates)/i && !$attributes{no_replies};
    return 0;
}

sub handle_bounce_to_verp_address {
    my $self = shift;
    my %attributes = mySociety::HandleMail::parse_bounce($self->lines);
    my $info = '';
    if ($attributes{is_dsn}) {
        # If permanent failure, but not mailbox full
        return $self->handle_permanent_bounce() if $attributes{status} =~ /^5\./ && $attributes{status} ne '5.2.2';
        $info = ", Status $attributes{status}";
    } elsif ($attributes{problem}) {
        my $err_type = mySociety::HandleMail::error_type($attributes{problem});
        return $self->handle_permanent_bounce() if $err_type == mySociety::HandleMail::ERR_TYPE_PERMANENT;
        $info = ", Bounce type $attributes{problem}";
    }

    # Check if the Subject looks like an auto-reply rather than a delivery bounce.
    # If so, treat as if it were a normal email
    my $type = $self->type;
    if ($self->is_out_of_office(%attributes)) {
        print_log('info', "Treating bounce for $type " . $self->object->id . " as auto-reply to sender");
        $self->handle_non_bounce_to_verp_address();
    } elsif (!$info) {
        print_log('info', "Unparsed bounce received for $type " . $self->object->id . ", forwarding to support");
        $self->forward_on_to($self->bouncemgr);
    } else {
        print_log('info', "Ignoring bounce received for $type " . $self->object->id . $info);
    }
}

sub handle_non_bounce_to_verp_address {
    my $self = shift;
    if ($self->type eq 'alert' && !$self->is_out_of_office()) {
        print_log('info', "Received non-bounce for alert " . $self->object->id . ", forwarding to support");
        $self->forward_on_to($self->bouncemgr);
    } elsif ($self->type eq 'report') {
        my $ret = $self->check_for_status_code;
        return if $ret;

        my $contributed_as = $self->object->get_extra_metadata('contributed_as') || '';
        if ($contributed_as eq 'body' || $contributed_as eq 'anonymous_user') {
            print_log('info', "Received non-bounce for report " . $self->object->id . " to anon report, dropping");
        } else {
            print_log('info', "Received non-bounce for report " . $self->object->id . ", forwarding to report creator");
            $self->forward_on_to($self->object->user->email);
        }
    }
}

sub check_for_status_code {
    my $self = shift;
    my $head = $self->data->{message}->head();
    my $subject = $head->get("Subject");

    my $problem = $self->object;
    my $cobrand = $problem->body_handler || $problem->get_cobrand_logged;
    return 0 unless $cobrand->call_hook('handle_email_status_codes');

    my ($code) = $subject =~ /SC(\d+)/i;
    return 0 if !$code && $self->is_out_of_office(no_replies => 1);
    return $self->_status_code_bounce($cobrand, "no SC code") unless $code;

    my $body = $cobrand->body;
    my $updates = Open311::GetServiceRequestUpdates->new(
        system_user => $body->comment_user,
        current_body => $body,
        blank_updates_permitted => 1,
    );

    my %body_ids = map { $_ => 1 } @{$problem->bodies_str_ids};
    my $categories = [ $problem->category, undef ];
    if (!$body_ids{$body->id}) {
        # Not to the body we're using for templates, so don't match on a category
        $categories = undef;
    }

    my $templates = FixMyStreet::DB->resultset("ResponseTemplate")->search({
        'me.body_id' => $body->id,
        'contact.category' => $categories,
    }, {
        order_by => 'contact.category', # So nulls are last
        join => { 'contact_response_templates' => 'contact' },
    });
    my $template = $templates->search({
        auto_response => 1,
        external_status_code => $code,
    })->first;

    return $self->_status_code_bounce($cobrand, "bad code SC$code") unless $template;

    print_log('info', "Received SC code in subject, updating report");

    my $text = $template->text;
    my $request = {
        service_request_id => $problem->id,
        update_id => $head->get("Message-ID"),
        comment_time => DateTime->now,
        status => $template->state || 'fixed - council',
        external_status_code => $code,
        description => $text,
    };
    $updates->process_update($request, $problem);
    return 1;
}

sub _status_code_bounce {
    my ($self, $cobrand, $line) = @_;
    $line = "Report #" . $self->object->id . ", email subject had $line";
    print_log('info', $line);
    my ($rp) = $self->data->{return_path} =~ /^\s*<(.*)>\s*$/;
    my $mail = FixMyStreet::Email::construct_email({
        'Auto-Submitted' => 'auto-replied',
        From => [ $cobrand->contact_email, $cobrand->contact_name ],
        To => $rp,
        Subject => $line,
        _body_ => $line,
    });
    send_mail($mail, $rp);
    return 1;
}

sub handle_non_bounce_to_null_address {
    my $self = shift;
    # Don't send a reply to out of office replies...
    if ($self->is_out_of_office()) {
        print_log('info', "Received non-bounce auto-reply to null address, ignoring");
        return;
    }

    # Send an automatic response
    print_log('info', "Received non-bounce to null address, auto-replying");

    my ( $cobrand, $from_addr, $from_name ) = $self->get_config_for_autoresponse();

    my $template = path(FixMyStreet->path_to("templates", "email", $cobrand, 'reply-autoresponse'))->slurp_utf8;

    # We generate this as a bounce.
    my ($rp) = $self->data->{return_path} =~ /^\s*<(.*)>\s*$/;
    my $mail = FixMyStreet::Email::construct_email({
        'Auto-Submitted' => 'auto-replied',
        From => [ $from_addr, $from_name ],
        To => $rp,
        _body_ => $template,
    });
    send_mail($mail, $rp);
}

# Based on the address the incoming message was sent to, we might want to
# use a cobrand's own reply-autoresponse template.
sub get_config_for_autoresponse {
    my $self = shift;
    # cobrand might have been set from command line, so prefer that if so.
    if ( $self->cobrand ) {
        return ( $self->cobrand, FixMyStreet->config('CONTACT_EMAIL'), FixMyStreet->config('CONTACT_NAME') );
    }

    # Try and find a matching email address in the COBRAND_FEATURES config
    my $recipient = mySociety::HandleMail::get_bounce_recipient($self->data->{message})->address;
    my $features = FixMyStreet->config('COBRAND_FEATURES') || {};
    my $cobrands = $features->{do_not_reply_email} || {};
    for my $moniker ( keys %$cobrands ) {
        if ( $cobrands->{$moniker} eq $recipient ) {
            my $cb = FixMyStreet::Cobrand->get_class_for_moniker($moniker)->new();
            return ( $moniker, $cb->contact_email, $cb->contact_name );
        }
    }

    # No match found, so use default cobrand
    return ( "default", FixMyStreet->config('CONTACT_EMAIL'), FixMyStreet->config('CONTACT_NAME') );
}

sub forward_on_to {
    my $self = shift;
    my $recipient = shift;
    my $text = join("\n", @{$self->lines}) . "\n";
    send_mail($text, $recipient);
}

sub send_mail {
    my ($email, $recipient) = @_;
    unless (FixMyStreet::Email::Sender->try_to_send(
        $email, { from => '<>', to => $recipient }
    )) {
        exit(75);
    }
}

1;
