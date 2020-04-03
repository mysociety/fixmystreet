package FixMyStreet::Queue::Item::Report;

use Moo;
use DateTime::Format::Pg;

use Utils::OpenStreetMap;

use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::Map;
use FixMyStreet::SendReport;

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

    FixMyStreet::DB->schema->cobrand($self->cobrand);

    if ($self->verbose) {
        my $row = $self->report;
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

    $self->cobrand->set_lang_and_domain($self->report->lang, 1);
    FixMyStreet::Map::set_map_class($self->cobrand_handler->map_type);

    return unless $self->_check_abuse;
    $self->_create_vars;
    $self->_create_reporters or return;
    my $result = $self->_send;
    $self->_post_send($result);
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
        $h{closest_address} = $self->cobrand->find_closest($row);
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
    my $bodies = FixMyStreet::DB->resultset('Body')->search(
        { id => $row->bodies_str_ids },
        { order_by => 'name' },
    );

    my @dear;
    my %reporters = ();
    while (my $body = $bodies->next) {
        my $sender_info = $self->cobrand->get_body_sender( $body, $row->category );
        my $sender = "FixMyStreet::SendReport::" . $sender_info->{method};

        if ( ! exists $self->senders->{ $sender } ) {
            $self->log(sprintf "No such sender [ $sender ] for body %s ( %d )", $body->name, $body->id);
            next;
        }
        $reporters{ $sender } ||= $sender->new();

        $self->log("Adding recipient body " . $body->id . ":" . $body->name . ", " . $sender_info->{method});
        push @dear, $body->name;
        $reporters{ $sender }->add_body( $body, $sender_info->{config} );
    }

    unless ( keys %reporters ) {
        die 'Report not going anywhere for ID ' . $row->id . '!';
    }

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
        %reporters = map { $_ => $reporters{$_} } grep { /FixMyStreet::SendReport::Email/ } keys %reporters;
        unless (%reporters) {
            %reporters = ( 'FixMyStreet::SendReport::Email' => FixMyStreet::SendReport::Email->new() );
        }
    }

    $self->_set_reporters(\%reporters);
}

sub _send {
    my $self = shift;

    # Multiply results together, so one success counts as a success.
    my $result = -1;

    for my $sender ( keys %{$self->reporters} ) {
        $self->log("Sending using " . $sender);
        $sender = $self->reporters->{$sender};
        my $res = $sender->send( $self->report, $self->h );
        $result *= $res;
        $self->report->add_send_method($sender) if !$res;
        if ( $self->manager ) {
            if ($sender->unconfirmed_data) {
                foreach my $e (keys %{ $sender->unconfirmed_data } ) {
                    foreach my $c (keys %{ $sender->unconfirmed_data->{$e} }) {
                        $self->manager->unconfirmed_data->{$e}{$c}{count} += $sender->unconfirmed_data->{$e}{$c}{count};
                        $self->manager->unconfirmed_data->{$e}{$c}{note} = $sender->unconfirmed_data->{$e}{$c}{note};
                    }
                }
            }
            $self->manager->test_data->{test_req_used} = $sender->open311_test_req_used
                if FixMyStreet->test_mode && $sender->can('open311_test_req_used');
        }
    }

    return $result;
}

sub _post_send {
    my ($self, $result) = @_;

    my $send_confirmation_email = $self->cobrand_handler->report_sent_confirmation_email;
    unless ($result) {
        $self->report->update( {
            whensent => \'current_timestamp',
            lastupdate => \'current_timestamp',
        } );
        if ($send_confirmation_email && !$self->h->{anonymous_report}) {
            $self->h->{sent_confirm_id_ref} = $self->report->$send_confirmation_email;
            $self->_send_report_sent_email;
        }
        $self->log("Send successful");
    } else {
        my @errors;
        for my $sender ( keys %{$self->reporters} ) {
            unless ( $self->reporters->{ $sender }->success ) {
                push @errors, $self->reporters->{ $sender }->error;
            }
        }
        $self->report->update_send_failed( join( '|', @errors ) );
        $self->log("Send failed");
    }
}

sub _send_report_sent_email {
    my $self = shift;

    # Don't send 'report sent' text
    return unless $self->report->user->email_verified;

    my $contributed_as = $self->report->get_extra_metadata('contributed_as') || '';
    return if $contributed_as eq 'body' || $contributed_as eq 'anonymous_user';

    FixMyStreet::Email::send_cron(
        $self->report->result_source->schema,
        'confirm_report_sent.txt',
        $self->h,
        {
            To => $self->report->user->email,
        },
        undef,
        $self->nomail,
        $self->cobrand,
        $self->report->lang,
    );
}

sub log {
    my ($self, $msg) = @_;
    return unless $self->verbose;
    STDERR->print("[fmsd] [" . $self->report->id . "] $msg\n");
}

1;
