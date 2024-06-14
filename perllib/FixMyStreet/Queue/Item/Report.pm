package FixMyStreet::Queue::Item::Report;

use Moo;
use CronFns;
use DateTime::Format::Pg;

use Utils::OpenStreetMap;

use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::Map;
use FixMyStreet::SendReport;

use constant EMAIL_SENDER_PREFIX => 'FixMyStreet::SendReport::Email';

# The row from the database being processed
has report => ( is => 'ro' );
# The thing dealing with the reports (for feeding back debug/test data)
has manager => ( is => 'ro' );

# The possible ways of sending reports
has senders => ( is => 'lazy', default => sub {
    my $send_report = FixMyStreet::SendReport->new();
    $send_report->get_senders;
});

# The cobrand the report was logged *on*
has cobrand => ( is => 'lazy', default => sub {
    $_[0]->report->get_cobrand_logged;
});

# A cobrand that handles the body to which this report is being sent, or logged cobrand if none
has cobrand_handler => ( is => 'lazy', default => sub {
    my $self = shift;
    $self->cobrand->call_hook(get_body_handler_for_problem => $self->report) || $self->cobrand;
});

# Data to be used in email templates / Open311 sending
has h => ( is => 'rwp' );

# SendReport subclasses to be used to send this report
has reporters => ( is => 'rwp' );

# Run parameters
has verbose => ( is => 'ro');
has nomail => ( is => 'ro' );

sub process {
    my $self = shift;
    my $row = $self->report;

    FixMyStreet::DB->schema->cobrand($self->cobrand);

    my $site = CronFns::site(FixMyStreet->config('BASE_URL'));
    my $states = FixMyStreet::DB::Result::Problem::open_states();
    $states = { map { $_ => 1 } ( 'submitted', 'confirmed', 'in progress', 'feedback pending', 'external', 'wish' ) } if $site eq 'zurich';

    if (!$states->{$row->state} || !$row->bodies_str) {
        $row->update({ send_state => 'processed' });
        $self->log("marking as processed due to non matching state/bodies_str");
        return;
    }

    if ($self->verbose) {
        $self->log("state=" . $row->state . ", bodies_str=" . $row->bodies_str . ($row->cobrand? ", cobrand=" . $row->cobrand : ""));
    }

    # Cobranded and non-cobranded messages can share a database. In this case, the conf file
    # should specify a vhost to send the reports for each cobrand, so that they don't get sent
    # more than once if there are multiple vhosts running off the same database. The email_host
    # call checks if this is the host that sends mail for this cobrand.
    if (! $self->cobrand->email_host()) {
        $self->log("skipping because this host does not send reports for cobrand " . $self->cobrand->moniker);
        return;
    }

    $self->cobrand->set_lang_and_domain($row->lang, 1);
    FixMyStreet::Map::set_map_class($self->cobrand_handler);

    return unless $self->_check_abuse;
    $self->_create_vars;
    $self->_create_reporters or return;
    $self->_send;
    $self->_post_send;
}

sub _check_abuse {
    my $self = shift;
    if ( $self->report->is_from_abuser) {
        $self->report->update( { state => 'hidden' } );
        $self->log("hiding because its sender is flagged as an abuser");
        return;
    } elsif ( $self->report->title =~ /app store test/i ) {
        $self->report->update( { state => 'hidden' } );
        $self->log("hiding because it is an app store test message");
        return;
    }
    return 1;
}

sub _create_vars {
    my $self = shift;

    my $row = $self->report;

    # Template variables for the email
    my $email_base_url = $self->cobrand_handler->base_url_for_report($row);
    my %h = map { $_ => $row->$_ } qw/id title detail name category latitude longitude used_map/;
    $h{report} = $row;
    $h{cobrand} = $self->cobrand;
    $h{cobrand_handler} = $self->cobrand_handler;
    map { $h{$_} = $row->user->$_ || '' } qw/email phone/;
    $h{confirmed} = DateTime::Format::Pg->format_datetime( $row->confirmed->truncate (to => 'second' ) )
        if $row->confirmed;

    $h{query} = $row->postcode;
    $h{url} = $email_base_url . $row->url;
    $h{admin_url} = $row->admin_url($self->cobrand_handler);
    if ($row->photo) {
        $h{has_photo} = _("This web page also contains a photo of the problem, provided by the user.") . "\n\n";
        $h{image_url} = $email_base_url . $row->photos->[0]->{url_full};
        my @all_images = map { $email_base_url . $_->{url_full} } @{ $row->photos };
        $h{all_image_urls} = \@all_images;
    } else {
        $h{has_photo} = '';
        $h{image_url} = '';
    }
    $h{fuzzy} = $row->used_map ? _('To view a map of the precise location of this issue')
        : _('The user could not locate the problem on a map, but to see the area around the location they entered');
    $h{closest_address} = '';

    $h{osm_url} = Utils::OpenStreetMap::short_url($h{latitude}, $h{longitude});
    if ( $row->used_map ) {
        $h{closest_address} = $self->cobrand_handler->find_closest($row);
        $h{osm_url} .= '?m';
    }

    if ( $self->cobrand->allow_anonymous_reports($row->category) &&
         $row->user->email eq $self->cobrand->anonymous_account->{'email'}
     ) {
        $h{anonymous_report} = 1;
    }

    if ($h{category} eq _('Other')) {
        $h{category_footer} = _('this type of local problem');
    } else {
        $h{category_footer} = "'" . $h{category} . "'";
    }

    my $missing;
    if ($row->bodies_missing) {
        my @missing = FixMyStreet::DB->resultset("Body")->search(
            { id => [ split /,/, $row->bodies_missing ] },
            { order_by => 'name' }
        )->get_column('name')->all;
        $missing = join(' / ', @missing) if @missing;
    }
    $h{missing} = '';
    if ($missing) {
        $h{missing} = '[ '
          . sprintf(_('We realise this problem might be the responsibility of %s; however, we don\'t currently have any contact details for them. If you know of an appropriate contact address, please do get in touch.'), $missing)
          . " ]\n\n";
    }

    # If we are in the UK include eastings and northings
    if ( $self->cobrand->country eq 'GB' && !$h{easting} ) {
        ( $h{easting}, $h{northing}, $h{coordsyst} ) = $row->local_coords;
    }

    $self->cobrand->call_hook(process_additional_metadata_for_email => $row, \%h);

    $self->_set_h(\%h);
}

sub _create_reporters {
    my $self = shift;

    my $row = $self->report;
    my @failed_body_ids = @{ $row->send_fail_body_ids };
    my $bodies = FixMyStreet::DB->resultset('Body')->search(
        {   id => (
                @failed_body_ids ? \@failed_body_ids : $row->bodies_str_ids
            )
        },
        { order_by => 'name' },
    );

    my @dear;
    my %email_reporters;
    my @other_reporters;
    while (my $body = $bodies->next) {
        # NOTE
        # Non-email senders only have one body each (or put another way, we
        # assign each body in this loop to its own, unshared sender object).
        #
        # An email sender may have multiple bodies. This is so we can
        # combine bodies into a single 'To' line and send one email for all.
        my $sender_info = $self->cobrand_handler->get_body_sender( $body, $row );
        my $sender_name = "FixMyStreet::SendReport::" . $sender_info->{method};

        if ( ! exists $self->senders->{ $sender_name } ) {
            $self->log(sprintf "No such sender [ $sender_name ] for body %s ( %d )", $body->name, $body->id);
            next;
        }

        $self->log("Adding recipient body " . $body->id . ":" . $body->name . ", " . $sender_info->{method});
        push @dear, $body->name;

        my $reporter = $email_reporters{$sender_name} || $sender_name->new;
        $reporter->add_body( $body, $sender_info->{config} );

        if ( $sender_name =~ /${\EMAIL_SENDER_PREFIX}/ ) {
            $email_reporters{$sender_name} = $reporter;
        } else {
            push @other_reporters, $reporter;
        }
    }

    unless ( @other_reporters
        || keys %email_reporters )
    {
        die 'Report not going anywhere for ID ' . $row->id . '!';
    }

    # For email senders
    my $h = $self->h;
    $h->{bodies_name} = join(_(' and '), @dear);
    if ($h->{category} eq _('Other')) {
        $h->{multiple} = @dear>1 ? "[ " . _("This email has been sent to both councils covering the location of the problem, as the user did not categorise it; please ignore it if you're not the correct council to deal with the issue, or let us know what category of problem this is so we can add it to our system.") . " ]\n\n"
            : '';
    } else {
        $h->{multiple} = @dear>1 ? "[ " . _("This email has been sent to several councils covering the location of the problem, as the category selected is provided for all of them; please ignore it if you're not the correct council to deal with the issue.") . " ]\n\n"
            : '';
    }

    if (FixMyStreet->staging_flag('send_reports', 0)) {
        # on a staging server send emails to ourselves rather than the bodies
        unless (%email_reporters) {
            %email_reporters
                = ( EMAIL_SENDER_PREFIX => ${ \EMAIL_SENDER_PREFIX }->new() );
        }

        @other_reporters = ();
    }

    $self->_set_reporters([@other_reporters, values %email_reporters]);
}

sub _send {
    my $self = shift;

    my $report = $self->report;

    my @add_send_fail_body_ids;
    my @remove_send_fail_body_ids;

    for my $sender ( @{ $self->reporters } ) {
        my $sender_name = ref $sender;
        $self->log( 'Sending using ' . $sender_name );

        # NOTE
        # Non-email senders should only have one body each (see
        # _create_reporters()).
        $sender->send( $self->report, $self->h );

        my @body_ids = map { $_->id } @{ $sender->bodies };
        if ($sender->success) {
            $report->add_send_method($sender_name);
            push @remove_send_fail_body_ids, @body_ids;
        } else {
            push @add_send_fail_body_ids, @body_ids;
        }

        if ( $self->manager ) {
            if ($sender->unconfirmed_data) {
                foreach my $e (keys %{ $sender->unconfirmed_data } ) {
                    foreach my $c (keys %{ $sender->unconfirmed_data->{$e} }) {
                        $self->manager->unconfirmed_data->{$e}{$c}{count} += $sender->unconfirmed_data->{$e}{$c}{count};
                        $self->manager->unconfirmed_data->{$e}{$c}{note} = $sender->unconfirmed_data->{$e}{$c}{note};
                    }
                }
            }
        }
    }

    $self->report->add_send_fail_body_ids(@add_send_fail_body_ids)
        if @add_send_fail_body_ids;

    $self->report->remove_send_fail_body_ids(@remove_send_fail_body_ids)
        if @remove_send_fail_body_ids;
}

sub _post_send {
    my ($self) = @_;

    # Record any errors, whether overall successful or not (if multiple senders, perhaps one failed)
    my @errors;
    my $result = 1;
    for my $sender ( @{ $self->reporters } ) {
        if ($sender->success) {
            $result = 0;
        } else {
            push @errors, $sender->error;
        }
    }
    if (@errors) {
        $self->report->update_send_failed( join( '|', @errors ) );
    } else {
        $self->report->update({ send_state => 'sent' });
    }

    my $send_confirmation_email = $self->cobrand_handler->report_sent_confirmation_email($self->report);
    unless ($result) {
        $self->report->update( {
            whensent => \'statement_timestamp()',
            lastupdate => \'statement_timestamp()',
        } );
        if ($send_confirmation_email && !$self->h->{anonymous_report} &&
            !$self->cobrand_handler->suppress_report_sent_email($self->report)) {
            $self->h->{sent_confirm_id_ref} = $self->report->$send_confirmation_email;
            $self->_send_report_sent_email;
        }
        $self->_add_confirmed_update;
        $self->cobrand_handler->post_report_sent($self->report);
        $self->log("Send successful");
    } else {
        $self->log("Send failed");
    }
}

sub _add_confirmed_update {
    my $self = shift;

    # If an auto-internal update has been created, confirm it
    my $problem = $self->report;
    my $existing = $problem->comments->search({ external_id => 'auto-internal' })->first;
    if ($existing) {
        $existing->confirm;
        $existing->update;
    }
}

sub _send_report_sent_email {
    my $self = shift;

    # Don't send 'report sent' text
    return unless $self->report->user->email_verified;

    my $contributed_as = $self->report->get_extra_metadata('contributed_as') || '';
    return if $contributed_as eq 'body' || $contributed_as eq 'anonymous_user';

    $self->report->send_logged_email($self->h, $self->nomail, $self->cobrand);
}

sub log {
    my ($self, $msg) = @_;
    return unless $self->verbose;
    STDERR->print("[fmsd] [" . $self->report->id . "] $msg\n");
}

1;
