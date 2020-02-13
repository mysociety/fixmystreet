package FixMyStreet::Script::Reports;

use strict;
use warnings;

use CronFns;
use DateTime::Format::Pg;

use Utils;
use Utils::OpenStreetMap;

use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::Map;
use FixMyStreet::SendReport;

sub send(;$) {
    my ($site_override) = @_;
    my $rs = FixMyStreet::DB->resultset('Problem');

    # Set up site, language etc.
    my ($verbose, $nomail, $debug_mode) = CronFns::options();
    my $test_data;

    my $base_url = FixMyStreet->config('BASE_URL');
    my $site = $site_override || CronFns::site($base_url);

    my $states = [ FixMyStreet::DB::Result::Problem::open_states() ];
    $states = [ 'submitted', 'confirmed', 'in progress', 'feedback pending', 'external', 'wish' ] if $site eq 'zurich';
    my $unsent = $rs->search( {
        state => $states,
        whensent => undef,
        bodies_str => { '!=', undef },
    } );
    my (%notgot, %note);

    my $send_report = FixMyStreet::SendReport->new();
    my $senders = $send_report->get_senders;

    my $debug_unsent_count = 0;
    debug_print("starting to loop through unsent problem reports...") if $debug_mode;
    while (my $row = $unsent->next) {

        my $cobrand = $row->get_cobrand_logged;
        FixMyStreet::DB->schema->cobrand($cobrand);

        # Also get a cobrand that handles where a report is going
        my $cobrand_handler = $cobrand->call_hook(get_body_handler_for_problem => $row) || $cobrand;

        if ($debug_mode) {
            $debug_unsent_count++;
            print "\n";
            debug_print("state=" . $row->state . ", bodies_str=" . $row->bodies_str . ($row->cobrand? ", cobrand=" . $row->cobrand : ""), $row->id);
        }

        # Cobranded and non-cobranded messages can share a database. In this case, the conf file
        # should specify a vhost to send the reports for each cobrand, so that they don't get sent
        # more than once if there are multiple vhosts running off the same database. The email_host
        # call checks if this is the host that sends mail for this cobrand.
        if (! $cobrand->email_host()) {
            debug_print("skipping because this host does not send reports for cobrand " . $cobrand->moniker, $row->id) if $debug_mode;
            next;
        }

        $cobrand->set_lang_and_domain($row->lang, 1);
        FixMyStreet::Map::set_map_class($cobrand_handler->map_type);
        if ( $row->is_from_abuser) {
            $row->update( { state => 'hidden' } );
            debug_print("hiding because its sender is flagged as an abuser", $row->id) if $debug_mode;
            next;
        } elsif ( $row->title =~ /app store test/i ) {
            $row->update( { state => 'hidden' } );
            debug_print("hiding because it is an app store test message", $row->id) if $debug_mode;
            next;
        }

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

        $cobrand->call_hook(process_additional_metadata_for_email => $row, \%h);

        my $bodies = FixMyStreet::DB->resultset('Body')->search(
            { id => $row->bodies_str_ids },
            { order_by => 'name' },
        );

        my $missing;
        if ($row->bodies_missing) {
            my @missing = FixMyStreet::DB->resultset("Body")->search(
                { id => [ split /,/, $row->bodies_missing ] },
                { order_by => 'name' }
            )->get_column('name')->all;
            $missing = join(' / ', @missing) if @missing;
        }

        my $send_confirmation_email = $cobrand_handler->report_sent_confirmation_email;

        my @dear;
        my %reporters = ();
        my $skip = 0;
        while (my $body = $bodies->next) {
            my $sender_info = $cobrand->get_body_sender( $body, $row->category );
            my $sender = "FixMyStreet::SendReport::" . $sender_info->{method};

            if ( ! exists $senders->{ $sender } ) {
                warn sprintf "No such sender [ $sender ] for body %s ( %d )", $body->name, $body->id;
                next;
            }
            $reporters{ $sender } ||= $sender->new();

            if ( $reporters{ $sender }->should_skip( $row, $debug_mode ) ) {
                $skip = 1;
                debug_print("skipped by sender " . $sender_info->{method} . " (might be due to previous failed attempts?)", $row->id) if $debug_mode;
            } else {
                debug_print("OK, adding recipient body " . $body->id . ":" . $body->name . ", " . $sender_info->{method}, $row->id) if $debug_mode;
                push @dear, $body->name;
                $reporters{ $sender }->add_body( $body, $sender_info->{config} );
            }

            # If we are in the UK include eastings and northings
            if ( $cobrand->country eq 'GB' && !$h{easting} ) {
                ( $h{easting}, $h{northing}, $h{coordsyst} ) = $row->local_coords;
            }
        }

        unless ( keys %reporters ) {
            die 'Report not going anywhere for ID ' . $row->id . '!';
        }

        next if $skip;

        if ($h{category} eq _('Other')) {
            $h{category_footer} = _('this type of local problem');
        } else {
            $h{category_footer} = "'" . $h{category} . "'";
        }

        $h{bodies_name} = join(_(' and '), @dear);
        if ($h{category} eq _('Other')) {
            $h{multiple} = @dear>1 ? "[ " . _("This email has been sent to both councils covering the location of the problem, as the user did not categorise it; please ignore it if you're not the correct council to deal with the issue, or let us know what category of problem this is so we can add it to our system.") . " ]\n\n"
                : '';
        } else {
            $h{multiple} = @dear>1 ? "[ " . _("This email has been sent to several councils covering the location of the problem, as the category selected is provided for all of them; please ignore it if you're not the correct council to deal with the issue.") . " ]\n\n"
                : '';
        }
        $h{missing} = '';
        if ($missing) {
            $h{missing} = '[ '
              . sprintf(_('We realise this problem might be the responsibility of %s; however, we don\'t currently have any contact details for them. If you know of an appropriate contact address, please do get in touch.'), $missing)
              . " ]\n\n";
        }

        if (FixMyStreet->staging_flag('send_reports', 0)) {
            # on a staging server send emails to ourselves rather than the bodies
            %reporters = map { $_ => $reporters{$_} } grep { /FixMyStreet::SendReport::Email/ } keys %reporters;
            unless (%reporters) {
                %reporters = ( 'FixMyStreet::SendReport::Email' => FixMyStreet::SendReport::Email->new() );
            }
        }

        # Multiply results together, so one success counts as a success.
        my $result = -1;

        my @methods;
        for my $sender ( keys %reporters ) {
            debug_print("sending using " . $sender, $row->id) if $debug_mode;
            $sender = $reporters{$sender};
            my $res = $sender->send( $row, \%h );
            $result *= $res;
            push @methods, $sender if !$res;
            if ( $sender->unconfirmed_counts) {
                foreach my $e (keys %{ $sender->unconfirmed_counts } ) {
                    foreach my $c (keys %{ $sender->unconfirmed_counts->{$e} }) {
                        $notgot{$e}{$c} += $sender->unconfirmed_counts->{$e}{$c};
                    }
                }
                %note = (%note, %{ $sender->unconfirmed_notes });
            }
            $test_data->{test_req_used} = $sender->open311_test_req_used
                if FixMyStreet->test_mode && $sender->can('open311_test_req_used');
        }

        # Add the send methods now because e.g. Open311
        # send() calls $row->discard_changes
        foreach (@methods) {
            $row->add_send_method($_);
        }

        unless ($result) {
            $row->update( {
                whensent => \'current_timestamp',
                lastupdate => \'current_timestamp',
            } );
            if ($send_confirmation_email && !$h{anonymous_report}) {
                $h{sent_confirm_id_ref} = $row->$send_confirmation_email;
                _send_report_sent_email( $row, \%h, $nomail, $cobrand );
            }
            debug_print("send successful: OK", $row->id) if $debug_mode;
        } else {
            my @errors;
            for my $sender ( keys %reporters ) {
                unless ( $reporters{ $sender }->success ) {
                    push @errors, $reporters{ $sender }->error;
                }
            }
            $row->update_send_failed( join( '|', @errors ) );
            debug_print("send FAILED: " . join( '|', @errors ), $row->id) if $debug_mode;
        }
    }
    if ($debug_mode) {
        print "\n";
        if ($debug_unsent_count) {
            debug_print("processed all unsent reports (total: $debug_unsent_count)");
        } else {
            debug_print("no unsent reports were found (must have whensent=null and suitable bodies_str & state) -- nothing to send");
        }
    }

    if ($verbose || $debug_mode) {
        print "Council email addresses that need checking:\n" if keys %notgot;
        foreach my $e (keys %notgot) {
            foreach my $c (keys %{$notgot{$e}}) {
                print "    " . $notgot{$e}{$c} . " problem, to $e category $c (" . $note{$e}{$c}. ")\n";
            }
        }
        my $sending_errors = '';
        my $unsent = $rs->search( {
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

    return $test_data;
}

sub _send_report_sent_email {
    my $row = shift;
    my $h = shift;
    my $nomail = shift;
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
        $nomail,
        $cobrand,
        $row->lang,
    );
}

sub debug_print {
    my $msg = shift;
    my $id = shift || '';
    $id = "report $id: " if $id;
    print "[] $id$msg\n";
}

1;
