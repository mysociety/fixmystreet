package FixMyStreet::Script::Reports;

use strict;
use warnings;

use CronFns;
use DateTime::Format::Pg;
use Moo;

use Utils;
use Utils::OpenStreetMap;

use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::Map;
use FixMyStreet::SendReport;

has verbose => ( is => 'ro' );
has nomail => ( is => 'ro' );
has debug_mode => ( is => 'ro' );

has senders => ( is => 'lazy', default => sub {
    my $send_report = FixMyStreet::SendReport->new();
    $send_report->get_senders;
});

has debug_unsent_count => ( is => 'rw', default => 0 );
has unconfirmed_data => ( is => 'ro', default => sub { {} } );
has test_data => ( is => 'ro', default => sub { {} } );

# Static method, used by send-reports cron script and tests.
# Creates a manager object from provided data and processes it.
sub send(;$) {
    my ($site_override) = @_;
    my $rs = FixMyStreet::DB->resultset('Problem');

    # Set up site, language etc.
    my ($verbose, $nomail, $debug_mode) = CronFns::options();

    my $manager = __PACKAGE__->new(
        verbose => $verbose,
        nomail => $nomail,
        debug_mode => $debug_mode,
    );

    my $base_url = FixMyStreet->config('BASE_URL');
    my $site = $site_override || CronFns::site($base_url);

    my $states = [ FixMyStreet::DB::Result::Problem::open_states() ];
    $states = [ 'submitted', 'confirmed', 'in progress', 'feedback pending', 'external', 'wish' ] if $site eq 'zurich';
    my $unsent = $rs->search( {
        state => $states,
        whensent => undef,
        bodies_str => { '!=', undef },
    } );

    $manager->debug_print("starting to loop through unsent problem reports...");
    while (my $row = $unsent->next) {
        $manager->process($row);
    }

    $manager->end_debug_line;
    $manager->end_summary_unconfirmed;
    $manager->end_summary_failures;

    return $manager->test_data;
}

sub process {
    my $self = shift;
    my $row = shift;

    my $cobrand = $row->get_cobrand_logged;
    FixMyStreet::DB->schema->cobrand($cobrand);

    # Also get a cobrand that handles where a report is going
    my $cobrand_handler = $cobrand->call_hook(get_body_handler_for_problem => $row) || $cobrand;

    if ($self->debug_mode) {
        $self->debug_unsent_count++;
        print "\n";
        $self->debug_print("state=" . $row->state . ", bodies_str=" . $row->bodies_str . ($row->cobrand? ", cobrand=" . $row->cobrand : ""), $row->id);
    }

    # Cobranded and non-cobranded messages can share a database. In this case, the conf file
    # should specify a vhost to send the reports for each cobrand, so that they don't get sent
    # more than once if there are multiple vhosts running off the same database. The email_host
    # call checks if this is the host that sends mail for this cobrand.
    if (! $cobrand->email_host()) {
        $self->debug_print("skipping because this host does not send reports for cobrand " . $cobrand->moniker, $row->id);
        return;
    }

    $cobrand->set_lang_and_domain($row->lang, 1);
    FixMyStreet::Map::set_map_class($cobrand_handler->map_type);
    if ( $row->is_from_abuser) {
        $row->update( { state => 'hidden' } );
        $self->debug_print("hiding because its sender is flagged as an abuser", $row->id);
        return;
    } elsif ( $row->title =~ /app store test/i ) {
        $row->update( { state => 'hidden' } );
        $self->debug_print("hiding because it is an app store test message", $row->id);
        return;
    }

    my $h = $self->_create_vars($row, $cobrand_handler, $cobrand);
    my $reporters = $self->_create_reporters($row, $cobrand, $h) or return;
    my $result = $self->_send($reporters, $row, $h);
    $self->_post_send($result, $row, $h, $cobrand_handler, $cobrand, $reporters);
}

sub _create_vars {
    my ($self, $row, $cobrand_handler, $cobrand) = @_;

    # Template variables for the email
    my $email_base_url = $cobrand_handler->base_url_for_report($row);
    my %h = map { $_ => $row->$_ } qw/id title detail name category latitude longitude used_map/;
    $h{report} = $row;
    $h{cobrand} = $cobrand;
    map { $h{$_} = $row->user->$_ || '' } qw/email phone/;
    $h{confirmed} = DateTime::Format::Pg->format_datetime( $row->confirmed->truncate (to => 'second' ) )
        if $row->confirmed;

    $h{query} = $row->postcode;
    $h{url} = $email_base_url . $row->url;
    $h{admin_url} = $row->admin_url($cobrand_handler);
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
        $h{closest_address} = $cobrand->find_closest($row);
        $h{osm_url} .= '?m';
    }

    if ( $cobrand->allow_anonymous_reports($row->category) &&
         $row->user->email eq $cobrand->anonymous_account->{'email'}
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
    if ( $cobrand->country eq 'GB' && !$h{easting} ) {
        ( $h{easting}, $h{northing}, $h{coordsyst} ) = $row->local_coords;
    }

    $cobrand->call_hook(process_additional_metadata_for_email => $row, \%h);

    return \%h;
}

sub _create_reporters {
    my ($self, $row, $cobrand, $h) = @_;

    my $bodies = FixMyStreet::DB->resultset('Body')->search(
        { id => $row->bodies_str_ids },
        { order_by => 'name' },
    );

    my @dear;
    my %reporters = ();
    my $skip = 0;
    while (my $body = $bodies->next) {
        my $sender_info = $cobrand->get_body_sender( $body, $row->category );
        my $sender = "FixMyStreet::SendReport::" . $sender_info->{method};

        if ( ! exists $self->senders->{ $sender } ) {
            warn sprintf "No such sender [ $sender ] for body %s ( %d )", $body->name, $body->id;
            next;
        }
        $reporters{ $sender } ||= $sender->new();

        if ( $reporters{ $sender }->should_skip( $row, $self->debug_mode ) ) {
            $skip = 1;
            $self->debug_print("skipped by sender " . $sender_info->{method} . " (might be due to previous failed attempts?)", $row->id);
        } else {
            $self->debug_print("OK, adding recipient body " . $body->id . ":" . $body->name . ", " . $sender_info->{method}, $row->id);
            push @dear, $body->name;
            $reporters{ $sender }->add_body( $body, $sender_info->{config} );
        }
    }

    unless ( keys %reporters ) {
        die 'Report not going anywhere for ID ' . $row->id . '!';
    }

    return if $skip;

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

    return \%reporters;
}

sub _send {
    my ($self, $reporters, $row, $h) = @_;

    # Multiply results together, so one success counts as a success.
    my $result = -1;

    for my $sender ( keys %$reporters ) {
        $self->debug_print("sending using " . $sender, $row->id);
        $sender = $reporters->{$sender};
        my $res = $sender->send( $row, $h );
        $result *= $res;
        $row->add_send_method($sender) if !$res;
        if ( $sender->unconfirmed_data) {
            foreach my $e (keys %{ $sender->unconfirmed_data } ) {
                foreach my $c (keys %{ $sender->unconfirmed_data->{$e} }) {
                    $self->unconfirmed_data->{$e}{$c}{count} += $sender->unconfirmed_data->{$e}{$c}{count};
                    $self->unconfirmed_data->{$e}{$c}{note} = $sender->unconfirmed_data->{$e}{$c}{note};
                }
            }
        }
        $self->test_data->{test_req_used} = $sender->open311_test_req_used
            if FixMyStreet->test_mode && $sender->can('open311_test_req_used');
    }

    return $result;
}

sub _post_send {
    my ($self, $result, $row, $h, $cobrand_handler, $cobrand, $reporters) = @_;

    my $send_confirmation_email = $cobrand_handler->report_sent_confirmation_email;
    unless ($result) {
        $row->update( {
            whensent => \'current_timestamp',
            lastupdate => \'current_timestamp',
        } );
        if ($send_confirmation_email && !$h->{anonymous_report}) {
            $h->{sent_confirm_id_ref} = $row->$send_confirmation_email;
            $self->_send_report_sent_email( $row, $h, $cobrand );
        }
        $self->debug_print("send successful: OK", $row->id);
    } else {
        my @errors;
        for my $sender ( keys %$reporters ) {
            unless ( $reporters->{ $sender }->success ) {
                push @errors, $reporters->{ $sender }->error;
            }
        }
        $row->update_send_failed( join( '|', @errors ) );
        $self->debug_print("send FAILED: " . join( '|', @errors ), $row->id);
    }
}

sub end_debug_line {
    my $self = shift;
    return unless $self->debug_mode;

    print "\n";
    if ($self->debug_unsent_count) {
        $self->debug_print("processed all unsent reports (total: " . $self->debug_unsent_count . ")");
    } else {
        $self->debug_print("no unsent reports were found (must have whensent=null and suitable bodies_str & state) -- nothing to send");
    }
}

sub end_summary_unconfirmed {
    my $self = shift;
    return unless $self->verbose || $self->debug_mode;

    my %unconfirmed_data = %{$self->unconfirmed_data};
    print "Council email addresses that need checking:\n" if keys %unconfirmed_data;
    foreach my $e (keys %unconfirmed_data) {
        foreach my $c (keys %{$unconfirmed_data{$e}}) {
            my $data = $unconfirmed_data{$e}{$c};
            print "    " . $data->{count} . " problem, to $e category $c (" . $data->{note} . ")\n";
        }
    }
}

sub end_summary_failures {
    my $self = shift;
    return unless $self->verbose || $self->debug_mode;

    my $sending_errors = '';
    my $unsent = FixMyStreet::DB->resultset('Problem')->search( {
        state => [ FixMyStreet::DB::Result::Problem::open_states() ],
        whensent => undef,
        bodies_str => { '!=', undef },
        send_fail_count => { '>', 0 }
    } );
    while (my $row = $unsent->next) {
        my $base_url = FixMyStreet->config('BASE_URL');
        $sending_errors .= "\n" . '=' x 80 . "\n\n" . "* " . $base_url . "/report/" . $row->id . ", failed "
            . $row->send_fail_count . " times, last at " . $row->send_fail_timestamp
            . ", reason " . $row->send_fail_reason . "\n";
    }
    if ($sending_errors) {
        print "The following reports had problems sending:\n$sending_errors";
    }
}

sub _send_report_sent_email {
    my $self = shift;
    my $row = shift;
    my $h = shift;
    my $cobrand = shift;

    # Don't send 'report sent' text
    return unless $row->user->email_verified;

    my $contributed_as = $row->get_extra_metadata('contributed_as') || '';
    return if $contributed_as eq 'body' || $contributed_as eq 'anonymous_user';

    FixMyStreet::Email::send_cron(
        $row->result_source->schema,
        'confirm_report_sent.txt',
        $h,
        {
            To => $row->user->email,
        },
        undef,
        $self->nomail,
        $cobrand,
        $row->lang,
    );
}

sub debug_print {
    my $self = shift;
    return unless $self->debug_mode;

    my $msg = shift;
    my $id = shift || '';
    $id = "report $id: " if $id;
    print "[] $id$msg\n";
}

1;
