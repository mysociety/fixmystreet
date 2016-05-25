package FixMyStreet::Script::Reports;

use strict;
use warnings;

use CronFns;
use DateTime::Format::Pg;

use Utils;
use Utils::OpenStreetMap;
use mySociety::MaPit;

use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::SendReport;

sub send(;$) {
    my ($site_override) = @_;
    my $rs = FixMyStreet::DB->resultset('Problem');

    # Set up site, language etc.
    my ($verbose, $nomail, $debug_mode) = CronFns::options();

    my $base_url = FixMyStreet->config('BASE_URL');
    my $site = $site_override || CronFns::site($base_url);

    my $states = [ 'confirmed', 'fixed' ];
    $states = [ 'unconfirmed', 'confirmed', 'in progress', 'planned', 'closed', 'investigating' ] if $site eq 'zurich';
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

        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->cobrand)->new();

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
        my $email_base_url = $cobrand->base_url_for_report($row);
        my %h = map { $_ => $row->$_ } qw/id title detail name category latitude longitude used_map/;
        map { $h{$_} = $row->user->$_ || '' } qw/email phone/;
        $h{confirmed} = DateTime::Format::Pg->format_datetime( $row->confirmed->truncate (to => 'second' ) )
            if $row->confirmed;

        $h{query} = $row->postcode;
        $h{url} = $email_base_url . $row->url;
        $h{admin_url} = $row->admin_url($cobrand);
        $h{phone_line} = $h{phone} ? _('Phone:') . " $h{phone}\n\n" : '';
        if ($row->photo) {
            $h{has_photo} = _("This web page also contains a photo of the problem, provided by the user.") . "\n\n";
            $h{image_url} = $email_base_url . $row->photos->[0]->{url_full};
        } else {
            $h{has_photo} = '';
            $h{image_url} = '';
        }
        $h{fuzzy} = $row->used_map ? _('To view a map of the precise location of this issue')
            : _('The user could not locate the problem on a map, but to see the area around the location they entered');
        $h{closest_address} = '';

        $h{osm_url} = Utils::OpenStreetMap::short_url($h{latitude}, $h{longitude});
        if ( $row->used_map ) {
            $h{closest_address} = $cobrand->find_closest( $h{latitude}, $h{longitude}, $row );
            $h{osm_url} .= '?m';
        }

        if ( $cobrand->allow_anonymous_reports &&
             $row->user->email eq $cobrand->anonymous_account->{'email'}
         ) {
            $h{anonymous_report} = 1;
            $h{user_details} = _('This report was submitted anonymously');
        } else {
            $h{user_details} = sprintf(_('Name: %s'), $row->name) . "\n\n";
            $h{user_details} .= sprintf(_('Email: %s'), $row->user->email) . "\n\n";
        }

        $h{easting_northing} = '';

        if ($cobrand->can('process_additional_metadata_for_email')) {
            $cobrand->process_additional_metadata_for_email($row, \%h);
        }

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

            if ( $reporters{ $sender }->should_skip( $row ) ) {
                $skip = 1;
                debug_print("skipped by sender " . $sender_info->{method} . " (might be due to previous failed attempts?)", $row->id) if $debug_mode;
            } else {
                debug_print("OK, adding recipient body " . $body->id . ":" . $body->name . ", " . $sender_info->{method}, $row->id) if $debug_mode;
                push @dear, $body->name;
                $reporters{ $sender }->add_body( $body, $sender_info->{config} );
            }

            # If we are in the UK include eastings and northings, and nearest stuff
            if ( $cobrand->country eq 'GB' && !$h{easting} ) {
                my $coordsyst = 'G';
                my $first_area = $body->body_areas->first->area_id;
                my $area_info = mySociety::MaPit::call('area', $first_area);
                $coordsyst = 'I' if $area_info->{type} eq 'LGD';

                ( $h{easting}, $h{northing} ) = Utils::convert_latlon_to_en( $h{latitude}, $h{longitude}, $coordsyst );

                # email templates don't have conditionals so we need to format this here
                $h{easting_northing} = "Easting/Northing";
                $h{easting_northing} .= " (IE)" if $coordsyst eq 'I';
                $h{easting_northing} .= ": $h{easting}/$h{northing}\n\n";
            }
        }

        unless ( keys %reporters ) {
            die 'Report not going anywhere for ID ' . $row->id . '!';
        }

        next if $skip;

        if ($h{category} eq _('Other')) {
            $h{category_footer} = _('this type of local problem');
            $h{category_line} = '';
        } else {
            $h{category_footer} = "'" . $h{category} . "'";
            $h{category_line} = sprintf(_("Category: %s"), $h{category}) . "\n\n";
        }

        if ( $row->subcategory ) {
            $h{subcategory_line} = sprintf(_("Subcategory: %s"), $row->subcategory) . "\n\n";
        } else {
            $h{subcategory_line} = "\n\n";
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

        if (FixMyStreet->config('STAGING_SITE') && !FixMyStreet->config('SEND_REPORTS_ON_STAGING')) {
            # on a staging server send emails to ourselves rather than the bodies
            %reporters = map { $_ => $reporters{$_} } grep { /FixMyStreet::SendReport::Email/ } keys %reporters;
            unless (%reporters) {
                %reporters = ( 'FixMyStreet::SendReport::Email' => FixMyStreet::SendReport::Email->new() );
            }
        }

        # Multiply results together, so one success counts as a success.
        my $result = -1;

        for my $sender ( keys %reporters ) {
            debug_print("sending using " . $sender, $row->id) if $debug_mode;
            $result *= $reporters{ $sender }->send( $row, \%h );
            if ( $reporters{ $sender }->unconfirmed_counts) {
                foreach my $e (keys %{ $reporters{ $sender }->unconfirmed_counts } ) {
                    foreach my $c (keys %{ $reporters{ $sender }->unconfirmed_counts->{$e} }) {
                        $notgot{$e}{$c} += $reporters{ $sender }->unconfirmed_counts->{$e}{$c};
                    }
                }
                %note = (
                    %note,
                    %{ $reporters{ $sender }->unconfirmed_notes }
                );
            }
        }

        unless ($result) {
            $row->update( {
                whensent => \'current_timestamp',
                lastupdate => \'current_timestamp',
            } );
            if ( $cobrand->report_sent_confirmation_email && !$h{anonymous_report}) {
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
            state => [ 'confirmed', 'fixed' ],
            whensent => undef,
            bodies_str => { '!=', undef },
            send_fail_count => { '>', 0 }
        } );
        while (my $row = $unsent->next) {
            my $base_url = FixMyStreet->config('BASE_URL');
            $sending_errors .= "* " . $base_url . "/report/" . $row->id . ", failed "
                . $row->send_fail_count . " times, last at " . $row->send_fail_timestamp
                . ", reason " . $row->send_fail_reason . "\n";
        }
        if ($sending_errors) {
            print "The following reports had problems sending:\n$sending_errors";
        }
    }
}

sub _send_report_sent_email {
    my $row = shift;
    my $h = shift;
    my $nomail = shift;
    my $cobrand = shift;

    FixMyStreet::Email::send_cron(
        $row->result_source->schema,
        'confirm_report_sent.txt',
        $h,
        {
            To => $row->user->email,
            From => [ FixMyStreet->config('CONTACT_EMAIL'), $cobrand->contact_name ],
        },
        FixMyStreet->config('CONTACT_EMAIL'),
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
