=head1 NAME

FixMyStreet::Cobrand::Bexley::Waste - code specific to Bexley WasteWorks

=head1 SYNOPSIS

Bexley integrates with Whitespace for its waste data.

Address lookup is handled in L<BexleyAddresses>.

=cut

package FixMyStreet::Cobrand::Bexley::Waste;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::Waste';

use BexleyAddresses;
use DateTime;
use DateTime::Format::W3CDTF;
use FixMyStreet;
use FixMyStreet::App::Form::Waste::Request::Bexley;
use FixMyStreet::Template;
use Integrations::Whitespace;
use Lingua::EN::Inflect qw( NUMWORDS );
use Sort::Key::Natural qw(natkeysort_inplace);

has 'whitespace' => (
    is => 'lazy',
    default => sub { Integrations::Whitespace->new(%{shift->feature('whitespace')}) },
);

=head2 Constants

=over 4

=cut

=item * WORKING_DAYS_WINDOW

Recent collections are defined as being 3 or fewer working days ago.

=cut

use constant WORKING_DAYS_WINDOW => 3;

=item * WHITESPACE_UNDEF_DATE

C<0001-01-01T00:00:00> represents an undefined date in Whitespace.

=back

=cut

use constant WHITESPACE_UNDEF_DATE => '0001-01-01T00:00:00';
use constant MISSED_COLLECTION_SERVICE_PROPERTY_ID => 68;
use constant REQUEST_SERVICE_PROPERTY_ID => 69;

sub fetch_whitespace_data {
    my ($self, $method, $uprn) = @_;

    my $c = $self->{c};

    my $async = $c->action eq 'waste/bin_days'
        && $c->req->method eq 'GET';

    my $data = $self->whitespace->call_api(
        $c,
        $self->council_url,
        "bin_days_page:$uprn",
        $async,
        GetSiteInfo        => [$uprn],
        GetSiteCollections => [$uprn],
    );

    return $data->{"$method $uprn"};
}

sub clear_cached_lookups_property {
    my ($self, $uprn) = @_;

    # Need to call this before clearing GUID
    $self->clear_cached_lookups_bulky_slots($uprn);

    $self->{c}->waste_cache_delete($self->council_url . ":whitespace:bin_days_page:$uprn");
}

sub clear_cached_lookups_bulky_slots {
    my ( $self, $uprn ) = @_;

    $self->{c}->waste_cache_delete($self->council_url . ":whitespace:available_bulky_slots:$uprn");
}

sub waste_fetch_events {
    my ( $self, $params ) = @_;

    my $gsr_updates = Open311::GetServiceRequestUpdates->new(
        current_body => $self->body,
        system_user => $self->body->comment_user,
    );

    my $reports = $self->problems->search(
        {   external_id => { like => 'Whitespace%' },
            state => [ FixMyStreet::DB::Result::Problem->open_states() ],
        },
        { order_by => 'id' },
    );

    while ( my $report = $reports->next ) {
        print 'Fetching data for report ' . $report->id . "\n" if $params->{verbose};

        my $worksheet_id = $report->external_id =~ s/Whitespace-//r;
        my $request = $self->construct_waste_open311_update($params, {
            id => $worksheet_id,
            report => $report,
        });
        next if !$request->{status} || $request->{status} eq 'confirmed'; # Still in initial state
        next unless $self->waste_check_last_update($params, $report, $request->{status});

        $request->{comment_time} = DateTime->now->set_time_zone( FixMyStreet->local_time_zone );

        print
            "  Updating report to state '$request->{status}' - '$request->{description}' ($request->{external_status_code})\n"
            if $params->{verbose};

        $gsr_updates->process_update(
            $request,
            $report,
        );
    }
}

sub construct_waste_open311_update {
    my ($self, $params, $worksheet) = @_;

    my $report = $worksheet->{report} || $self->problems->find($worksheet->{ref});
    return unless $report;

    $worksheet = $self->whitespace->GetFullWorksheetDetails($worksheet->{id});

    my ($service_id, $config_key);
    if ($report->category eq 'Report missed collection') {
        $service_id = MISSED_COLLECTION_SERVICE_PROPERTY_ID;
        $config_key = 'missed_collection_state_mapping';
    } else {
        $service_id = REQUEST_SERVICE_PROPERTY_ID;
        if ($report->category eq 'Request new container') {
            $config_key = 'container_delivery_state_mapping';
        } elsif ($report->category eq 'Request container removal') {
            $config_key = 'container_removal_state_mapping';
        }
    }

    # Get info for missed collection
    my $properties;
    for my $service_properties (
        @{  $worksheet->{WSServiceProperties}{WorksheetServiceProperty}
                // []
        }
    ) {
        next unless $service_properties->{ServicePropertyID} == $service_id;
        $properties = $service_properties;
    }

    my $whitespace_state_string = $properties->{ServicePropertyValue} || '';

    my $config = $self->feature('whitespace');
    my $new_state = $config->{$config_key}{$whitespace_state_string};
    unless ($new_state) {
        print "  No new state, skipping\n" if $params->{verbose};
        return;
    }

    my $request = {
        description => $new_state->{text},
        status => $new_state->{fms_state},
        update_id => 'waste',
        external_status_code => $whitespace_state_string,
        prefer_template => 1,
        report => $report,
    };
    return $request;
}

sub waste_check_last_update {
    my ( $self, $params, $report, $state ) = @_;

    my $last_update = $report->comments->search(
        { external_id => 'waste', },
    )->order_by('-id')->first;

    if ( $last_update && $state eq $last_update->problem_state ) {
        print "  Latest update matches fetched state, skipping\n" if $params->{verbose};
        return;
    }

    return 1;
}

sub bin_addresses_for_postcode {
    my ($self, $postcode) = @_;

    my $addresses = BexleyAddresses::addresses_for_postcode($postcode);

    my @data =
        map {
            my $address_string = BexleyAddresses::build_address_string($_);
            {
                value => $_->{uprn},
                label => FixMyStreet::Template::title( $address_string )
            };
        } @$addresses;

    return \@data;
}

sub look_up_property {
    my ( $self, $uprn ) = @_;

    my $site = $self->fetch_whitespace_data('GetSiteInfo', $uprn);

    # We assume USRN is the same between parent and child addresses
    my $usrn = BexleyAddresses::usrn_for_uprn($uprn);

    # We need to call GetAccountSiteID to get parent UPRN
    my %parent_property;
    if ( my $site_parent_id = $site->{Site}{SiteParentID} ) {
        my $parent_data = $self->whitespace->GetAccountSiteID($site_parent_id);
        %parent_property = (
            parent_property => {
                # NOTE 'AccountSiteUPRN' returned from GetSiteInfo,      but
                #      'AccountSiteUprn' returned from GetAccountSiteID
                id   => $parent_data->{AccountSiteUprn},
                uprn => $parent_data->{AccountSiteUprn},
                usrn => $usrn,
            }
        );
    }

    # Check if today or any of the next 7 days are bank holidays
    my $upcoming_bank_holiday = 0;
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    for (-7..14) {
        my $dt = DateTime->now->add(days => $_);
        if ($wd->is_public_holiday($dt)) {
            $upcoming_bank_holiday = 1;
            last;
        }
    }

    # Add query string parameter for showing bank holiday message
    if ($self->{c}->get_param('show_bank_holiday_message')) {
        $upcoming_bank_holiday = 1;
    }

    my $address = BexleyAddresses::address_for_uprn($uprn);

    return {
        # 'id' is same as 'uprn' for Bexley, but since the wider wasteworks code
        # (e.g. FixMyStreet/App/Controller/Waste.pm) calls 'id' in some cases
        # and 'uprn' in others, we set both here
        id => $site->{AccountSiteUPRN},
        uprn => $site->{AccountSiteUPRN},
        usrn => $usrn,
        address => FixMyStreet::Template::title($address->{address}),
        latitude => $site->{Site}->{SiteLatitude},
        longitude => $site->{Site}->{SiteLongitude},
        upcoming_bank_holiday => $upcoming_bank_holiday,
        show_bulky_waste => $self->bulky_allowed_property($address),
        %parent_property,
    };
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    my $uprn = $property->{uprn};
    my $site_services = $self->fetch_whitespace_data('GetSiteCollections', $uprn);

    # Get parent property services if no services found
    if ( !@{ $site_services // [] }
        && $property->{parent_property} )
    {
        $uprn = $property->{parent_property}{uprn};
        $site_services = $self->fetch_whitespace_data('GetSiteCollections', $uprn);

        # A property is only communal if it has a parent property AND doesn't
        # have its own list of services
        $property->{is_communal} = 1;
    }

    # TODO Call these in parallel
    $property->{open_reports}
        = $self->_open_reports($property);
    $property->{recent_collections} = $self->_recent_collections($property);

    my ( $property_logs, $street_logs, $completed_or_attempted_collections )
        = $self->_in_cab_logs($property);
    $property->{completed_or_attempted_collections}
        = $completed_or_attempted_collections;
    $property->{red_tags} = $property_logs;
    $property->{service_updates} = $street_logs;

    # Set certain things outside of services loop
    my $containers = $self->_containers($property);
    my $now_dt = DateTime->now->set_time_zone( FixMyStreet->local_time_zone );

    my %frequency_types;
    my @site_services_filtered;
    my %seen_containers;
    my $whitespace_paper_bin;
    for my $service (@$site_services) {
        next if !$service->{NextCollectionDate};

        my $container = $containers->{ $service->{ServiceItemName} };
        next unless $container;

        # There may be duplicate container types; skip if container has been
        # seen before.
        # EXCEPTION for assisted collections, which are handled further down.
        my $assisted_collection = $service->{ServiceName}
            && $service->{ServiceName} eq 'Assisted Collection' ? 1 : 0;
        next
            if !$assisted_collection
            && $seen_containers{ $container->{name} };

        my $next_dt = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $service->{NextCollectionDate} );
        };
        if ($@) {
            warn $@;
            next;
        }

        my $from_dt = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $service->{SiteServiceValidFrom} );
        };
        if ($@) {
            warn $@;
            next;
        }
        next if $now_dt < $from_dt;

        if ( $service->{SiteServiceValidTo} ne WHITESPACE_UNDEF_DATE ) {
            my $to_dt = eval {
                DateTime::Format::W3CDTF->parse_datetime(
                    $service->{SiteServiceValidTo} );
            };
            if ($@) {
                warn $@;
                next;
            }
            next if $now_dt > $to_dt;
        }

        # Get the last collection date from recent collections.
        #
        # Some services may have two collections a week; these are concatenated
        # together in $service->{RoundSchedule}. We need to split them so we
        # can look them up individually in $property->{recent_collections}.
        my @round_schedules = split /, /, $service->{RoundSchedule};

        my $last_dt;
        for (@round_schedules) {
            my $dt_to_check = $property->{recent_collections}{$_};

            if (
                $dt_to_check
                && (  !$last_dt
                    || $dt_to_check > $last_dt )
                )
            {
                $last_dt = $dt_to_check;
            }
        }

        my ($round) = split / /, $service->{RoundSchedule};

        # 'Next collection date' could be today; successful collection logs
        # will tell us if the collection has already been made
        my $completed_or_attempted_collection_dt
            = $property->{completed_or_attempted_collections}{$round};
        my $collected_today = $completed_or_attempted_collection_dt
            && $now_dt->delta_days($completed_or_attempted_collection_dt)
            ->in_units('days') == 0
            ? 1 : 0;
        my $scheduled_for_today = $now_dt->ymd eq $next_dt->ymd;

        my $min_dt = $self->_subtract_working_days(WORKING_DAYS_WINDOW);
        # If the last expected collection was more than three days ago and
        # it's not scheduled for collection today, then we don't consider
        # it to have been collected today.
        if ($last_dt && $last_dt < $min_dt && !$scheduled_for_today) {
            $collected_today = 0;
        }

        my $filtered_service = {
            id             => $service->{SiteServiceID},
            service_id     => $service->{ServiceItemName},
            service_name        => $container->{name},
            service_description => $container->{description},
            service_description_contains_html =>
                $container->{description_contains_html},
            round_schedule => $service->{RoundSchedule},
            round          => $round,
            next => {
                date              => $service->{NextCollectionDate},
                ordinal           => ordinal( $next_dt->day ),
                changed           => 0,
                is_today          => $scheduled_for_today,
                already_collected => $collected_today,
            },
            assisted_collection => $assisted_collection,
            uprn => $uprn,
            garden_waste => $container->{description} eq 'Garden waste' ? 1 : 0,
        };

        if ($last_dt) {
            $filtered_service->{last} = {
                date    => $last_dt,
                ordinal => ordinal( $last_dt->day ),
            };
        }

        # Set some flags on property as well; these are used for missed
        # collection location options
        $property->{has_assisted} = 1
            if !$property->{has_assisted}
            && $filtered_service->{assisted_collection};
        $property->{above_shop} = 1
            if $filtered_service->{service_id} eq 'MDR-SACK';

        $whitespace_paper_bin = 1
            if $filtered_service->{service_id} eq 'PC-180';

        # Frequency of collection
        if ( @round_schedules > 1 ) {
            $filtered_service->{schedule} = 'Twice Weekly';
        } elsif ( $round_schedules[0] =~ /Wk (\d+)$/ ) {
            $frequency_types{fortnightly} //= $1;
            $filtered_service->{schedule} = 'Fortnightly';
        } else {
            $frequency_types{weekly} //= 1;
            $filtered_service->{schedule} = 'Weekly';
        }

        foreach (
            { type => 'missed', open => 'report_open', details => 'report_details' },
            { type => 'delivery', open => 'delivery_open', details => 'delivery_details' },
            { type => 'removal', open => 'removal_open', details => 'removal_details' },
        ) {
            my $container_id = _parent_for_container($filtered_service->{service_id});
            my $details = $property->{open_reports}{$_->{type}}{$container_id};

            if ($details) {
                $filtered_service->{$_->{details}} = $details;
                $filtered_service->{$_->{open}} = $details->{open};
            } else {
                $filtered_service->{$_->{open}} = 0;
            }
        }

        $filtered_service->{report_locked_out} = 0;
        $filtered_service->{report_locked_out_reason} = '';
        my $log_reason_prefix = $self->get_in_cab_logs_reason_prefix($filtered_service->{service_id});
        if ($log_reason_prefix) {
            my @relevant_logs = grep { $_->{reason} =~ /^$log_reason_prefix/ && $_->{round} =~ /\Q$filtered_service->{round}\E/ } @$property_logs;
            if (@relevant_logs) {
                $filtered_service->{report_locked_out} = 1;
                $filtered_service->{report_locked_out_reason} = $relevant_logs[0]->{reason};
            }

        }

        $filtered_service->{report_allowed}
            = $self->can_report_missed( $property, $filtered_service );

        push @site_services_filtered, $filtered_service;
        $seen_containers{ $container->{name} } = 1;
    }

    $property->{frequency_types} = \%frequency_types;

    # Provide calendar link if fortnightly collections
    if ( my $id = $frequency_types{fortnightly} ) {
        $id = 'Wk-' . $id;
        my $links = $self->{c}->cobrand->feature('waste_calendar_links');
        $self->{c}->stash->{calendar_link} = [
            {   href => $links->{$id},
                text => 'View and download collection calendar',
            }
        ];
    }

    @site_services_filtered = $self->_remove_service_if_assisted_exists(@site_services_filtered);

    @site_services_filtered = $self->service_sort(@site_services_filtered);

    # Garden subscription.
    # This call removes Whitespace service if there is no contract in Agile.
    $property->{garden_current_subscription}
        = $self->garden_current_subscription(\@site_services_filtered);
    $property->{has_garden_subscription} = 1
        if $property->{garden_current_subscription};

    # To begin with we assume the property is eligible to sign up to GGW...
    $property->{garden_signup_eligible} = 1;
    # unless it's got a parent property AND no services of its own (communal),
    # or it already has a subscription in Agile
    # or it has sacks
    if (   $property->{is_communal}
        || $property->{has_garden_subscription}
        || !$whitespace_paper_bin
    ) {
        $property->{garden_signup_eligible} = 0;
    }

    $self->_set_request_containers( $property, @site_services_filtered );

    return \@site_services_filtered;
}

=head2 waste_suggest_retry_on_no_property_data

Whitespace sometimes returns no data for a valid property, so we
show a page suggesting the user retries later, rather than 404.

=cut

sub waste_suggest_retry_on_no_property_data { 1 }

=head2 _remove_service_if_assisted_exists

Whitespace returns a standard bin service alongside an assisted collection service where
an assisted collection is in place.

This results in a duplication of bin services on the bin page so, if there is an assisted collection
for a service, we will use that and remove the standard service it corresponds to.

In case there is no corresponding assisted collection for a service we will show the standard
collection for that service.

=cut

sub _remove_service_if_assisted_exists {
    my ($self, @services) = @_;

    my %service_by_service_id = map { $_->{service_id} => $_ } grep { !$_->{assisted_collection} } @services;
    %service_by_service_id = (%service_by_service_id, map { $_->{service_id} => $_ } grep { $_->{assisted_collection} } @services);

    return values %service_by_service_id;
}

# Returns hashref of 'ServiceItemName's (FO-140, GA-140, etc.), each mapped
# to details of an open missed collection report or container request
sub _open_reports {
    my ( $self, $property ) = @_;

    my @uprns = ($property->{uprn});
    push @uprns, $property->{parent_property}{uprn} if $property->{parent_property};

    my %open_reports;

    foreach my $uprn (@uprns) {
        my $worksheets = $self->whitespace->GetSiteWorksheets($uprn);

        for my $ws (@$worksheets) {
            next
                unless $ws->{WorksheetStatusName} eq 'Open'
                && $ws->{WorksheetSubject} =~ /^Missed|Deliver|Collect/;

            my $type = $ws->{WorksheetSubject} =~ /^Missed/ ? 'missed'
                : $ws->{WorksheetSubject} =~ /Deliver/ ? 'delivery' : 'removal';

            # Check if it exists in our DB
            my $external_id = 'Whitespace-' . $ws->{WorksheetID};
            my $report
                = $self->problems->search( { external_id => $external_id } )
                ->first;

            next unless $report;

            # Skip if there is already a report stashed against the service item
            # name
            my $service_item_name
                = $report->get_extra_field_value('service_item_name') // '';
            $service_item_name = _parent_for_container($service_item_name);
            next if $open_reports{$type}{$service_item_name};

            my $latest_comment
                = $report->comments->search(
                    {},
                    { order_by => { -desc => 'id' } },
            )->first;

            my $report_details = {
                id          => $report->id,
                external_id => $report->external_id,
                open        => $report->is_open,
                reported    => (
                    $ws->{WorksheetStartDate} eq WHITESPACE_UNDEF_DATE ?
                    '' : $ws->{WorksheetStartDate}
                ),
                will_be_completed => (
                    $ws->{WorksheetEscallatedDate} eq WHITESPACE_UNDEF_DATE ?
                    '' : $ws->{WorksheetEscallatedDate}
                ),
                latest_comment =>
                    ( $latest_comment ? $latest_comment->text : '' ),
            };

            $open_reports{$type}{$service_item_name} = $report_details;
        }
    }

    return \%open_reports;
}

# Returns a hash of recent collections, mapping Round + Schedule to collection
# date.
# NOTE These denote *scheduled* recent collections; *actual* recent
# collections are recorded in the in-cab logs.
sub _recent_collections {
    my ( $self, $property ) = @_;

    # Get collections for the last 29 days; the API call appears to return
    # 29 days of data
    my $dt_today = DateTime->today( time_zone => FixMyStreet->local_time_zone );
    my $dt_from = $dt_today->clone->subtract( days => 29 );

    # TODO GetCollectionByUprnAndDatePlus would be preferable as it supports
    # an end date, but Bexley's live API does not seem to support it. So we
    # have to filter out future dates below.
    my $collections = $self->whitespace->GetCollectionByUprnAndDate(
        $property->{uprn},
        $dt_from->stringify,
    );

    # Collection dates are in 'dd/mm/yyyy hh:mm:ss' format.
    my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y %T' );
    my %recent_collections;
    for (@$collections) {
        my $dt = $parser->parse_datetime( $_->{Date} );

        # Today's collections may not have happened yet, and we don't want any future collections.
        next if $dt->truncate( to => 'day' ) >= $dt_today;

        # Concatenate Round and Schedule, to be matched against a service's
        # RoundSchedule later
        my $round_schedule = $_->{Round} . ' ' . $_->{Schedule};

        # Check for existing date and use the most recent
        if ( my $existing = $recent_collections{ $round_schedule } ) {
            $dt = $dt > $existing ? $dt : $existing;
        }

        $recent_collections{ $round_schedule } = $dt;
    }

    return \%recent_collections;
}

# Returns a hashref of recent in-cab logs for the property, split by USRN and
# UPRN
sub _in_cab_logs {
    my ( $self, $property ) = @_;

    # Logs are recorded against parent properties, not children
    $property = $property->{parent_property} if $property->{parent_property};

    my $dt_from = $self->_subtract_working_days(WORKING_DAYS_WINDOW);
    my $cab_logs;
    if ( !$self->{c}->stash->{cab_logs} ) {
        # Property should always have a USRN, but return UPRN logs in case not
        $cab_logs
            = $property->{usrn}
            ? $self->whitespace->GetInCabLogsByUsrn(
                $property->{usrn},
                $dt_from->stringify,
            ) : $self->whitespace->GetInCabLogsByUprn(
                $property->{uprn},
                $dt_from->stringify,
            );

        $self->{c}->stash->{cab_logs} = $cab_logs;
    } else {
        $cab_logs = $self->{c}->stash->{cab_logs};
    }

    my @property_logs;
    my @street_logs;
    my %completed_or_attempted_collections;
    my %seen_logs;

    return ( \@property_logs, \@street_logs, \%completed_or_attempted_collections )
        unless $cab_logs;

    for (@$cab_logs) {
        my $logdate = DateTime::Format::Strptime->new( pattern => '%Y-%m-%dT%H:%M:%S' )->parse_datetime( $_->{LogDate} );

        # There aren't necessarily round completion logs; the presence of any
        # log against a round code should be taken as a sign that the round
        # has been completed or at least attempted for the property.
        # Overwrite entry for given round if a later logdate is found.
        $completed_or_attempted_collections{ $_->{RoundCode} } = $logdate
            if !$completed_or_attempted_collections{ $_->{RoundCode} }
            || $completed_or_attempted_collections{ $_->{RoundCode} } < $logdate;

        # Gather property-level and street-level exceptions
        if ( $_->{Reason} && $_->{Reason} ne 'N/A' ) {
            if ( $_->{Uprn} && $_->{Uprn} eq $property->{uprn} ) {
                # Create a unique key for this log entry based on the actual event details
                # using just the date portion of LogDate since multiple logs for the same
                # event might have different timestamps on the same day
                my $date_only = $logdate->ymd;
                my $log_key = join(':', $_->{Reason}, $_->{RoundCode}, $date_only);
                next if $seen_logs{$log_key}++;

                push @property_logs, {
                    uprn   => $_->{Uprn},
                    round  => $_->{RoundCode},
                    reason => $_->{Reason},
                    date   => $logdate,
                    ordinal => ordinal( $logdate->day ),
                };
            }
        }
    }

    return ( \@property_logs, \@street_logs,
        \%completed_or_attempted_collections );
}

sub can_report_missed {
    my ( $self, $property, $service ) = @_;

    # Cannot make a report if there is already an open one for this service
    return 0 if $property->{open_reports}{missed}{ $service->{service_id} };

    # Prevent reporting if there are service updates
    return 0 if @{ $property->{service_updates} // [] };

    # Prevent reporting if there are red tags on the service
    # Red tags are matched to services based on prefix
    return 0 if $service->{report_locked_out};

    my $config = $self->feature('whitespace');

    # Needs to be within 3 working days of the last completed round, today
    # not included.
    # NOTE last expected collection is the 'ideal'/expected collection date,
    # not actual. So we need to check cab logs below for actual collection date, unless
    # the 'use_expected_collection_datetime' flag is set.
    my $last_expected_collection_dt = $service->{last} && $service->{last}{date};

    if ($last_expected_collection_dt) {
        # TODO We can probably get successful collections directly off the
        # property rather than query _in_cab_logs again
        my ( undef, undef, $completed_or_attempted_collections )
            = $self->_in_cab_logs($property);

        my $logged_time_for_round;
        if (!$config->{use_expected_collection_datetime}) {
            # If there is a log for this collection, that is when
            # the round was completed so we can make a report if
            # we're within that time.
            $logged_time_for_round
                = $completed_or_attempted_collections->{ $service->{round} };
        } else {
            # A flag has been set for us to ignore in-cab logs and
            # treat the expected collection date time as the actual collection time.
            # This is useful for debugging missed collections on staging where there are no
            # in-cab logs.
            $logged_time_for_round = $last_expected_collection_dt;
        }

        # log time needs to be greater than or equal to 3 working days ago,
        # less than today
        my $min_dt = $self->_subtract_working_days(WORKING_DAYS_WINDOW);
        my $today_dt
            = DateTime->today( time_zone => FixMyStreet->local_time_zone );
        my $now_dt
            = DateTime->now( time_zone => FixMyStreet->local_time_zone );

        # We need to check if the last collection was made over
        # WORKING_DAYS_WINDOW ago because some collections are weekly and some
        # fortnightly, but they share a round code prefix.
        return 0 if $last_expected_collection_dt < $min_dt && !$service->{next}{is_today};

        return (   $logged_time_for_round < $now_dt
                && $logged_time_for_round >= $min_dt ) ? 1 : 0
            if $logged_time_for_round;

        $service->{last}{is_delayed} =
            ($last_expected_collection_dt < $today_dt && $last_expected_collection_dt >= $min_dt)
            || ($service->{next}{is_today} && $now_dt->hour >= 17) ? 1 : 0;
    }

    # At this point, missed report is not allowed because
    # a) collection is marked as delayed
    # OR
    # b) collection was been made over WORKING_DAYS_WINDOW ago
    # OR
    # c) new service, so no last collection expected
    return 0;
}

# Bexley want services to be ordered by next collection date.
# Sub-order by service name for consistent display.
sub service_sort {
    my ( $self, @services ) = @_;

    return sort {
            $a->{next}{date} cmp $b->{next}{date}
        ||  $a->{service_name} cmp $b->{service_name}
    } @services;
}

sub bin_future_collections {
    my $self = shift;

    my $services = $self->{c}->stash->{service_data};
    return [] unless $services;

    # There may be more than one service associated with a round.
    # Additionally, more than one round-schedule may be associated with a
    # service, e.g. 'RES-NOR Fri, RES-NOR Tue', so we need to split these out.
    my %srv_for_round;
    for my $srv (@$services) {
        my @round_schedules = split /, /, $srv->{round_schedule};
        for (@round_schedules) {
            push @{ $srv_for_round{$_} }, $srv;
        }
    }

    # TODO GetCollectionByUprnAndDatePlus would be preferable as it supports
    # an end date, so we could just do a single search for the whole year. But
    # Bexley's live API does not seem to support it. So we have to use
    # several calls to GetCollectionByUprnAndDate instead, which only returns
    # a month's worth of data.
    my $year = 1900 + (localtime)[5];
    my @rounds;
    for my $month ( 1 .. 12 ) {
        push @rounds, @{ $self->whitespace->GetCollectionByUprnAndDate(
            $self->{c}->stash->{property}{uprn},
            "$year-$month-01T00:00:00",
        ) };
    }
    return [] unless @rounds;

    # Dates need to be converted from 'dd/mm/yyyy hh:mm:ss' format
    my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y %T' );

    my %seen_rnd_schedule_date;
    my @events;
    for my $rnd ( @rounds ) {
        # There is a possibility that in our multiple calls to
        # GetCollectionByUprnAndDate we have picked up duplicate data (e.g.
        # the search from June 1st may have returned data from the beginning
        # of July too). So we need to dedupe.
        my $rnd_schedule = $rnd->{Round} . ' ' . $rnd->{Schedule};
        my $rnd_schedule_date = $rnd_schedule . ' ' . $rnd->{Date};

        next if $seen_rnd_schedule_date{$rnd_schedule_date};

        # Try to match Round-Schedule against services
        my $srv = $srv_for_round{$rnd_schedule};
        next unless $srv;

        my $dt = $parser->parse_datetime( $rnd->{Date} );

        for (@$srv) {
            my $summary = $_->{service_name};
            if (!$_->{service_description_contains_html}) {
                $summary .= " ($_->{service_description})";
            }
            push @events, {
                date    => $dt,
                desc    => '',
                summary => $summary,
            };
        }

        $seen_rnd_schedule_date{$rnd_schedule_date} = 1;
    }

    return \@events;
}

sub image_for_unit {
    my ( $self, $unit ) = @_;

    my $property = $self->{c}->stash->{property};

    my $is_communal = $property->{is_communal};

    my $images = {
        'FO-140'   => 'communal-food-wheeled-bin',     # Food 140 ltr Bin
        'FO-23'    => 'food-waste',                    # Food 23 ltr Caddy
        'GA-140'   => 'garden-waste-brown-bin',        # Garden 140 ltr Bin
        'GA-240'   => 'garden-waste-brown-bin',        # Garden 240 ltr Bin
        'GL-660'   => 'green-euro-bin',                # Glass 660 ltr Bin
        'GL-1100'  => 'green-euro-bin',                # Glass 1100 ltr Bin
        'GL-1280'  => 'green-euro-bin',                # Glass 1280 ltr Bin
        'GL-55'    => 'recycle-black-box',             # Glass 55 ltr Box
        'MDR-SACK' => 'recycle-bag',                   # Mixed Dry Recycling Sack
        'PC-180'   => 'recycling-bin-blue-lid',        # Paper & card 180 ltr wheeled bin
        'PC-55'    => 'blue-recycling-box',            # Paper & card 55 ltr box
        'PA-1100'  => 'communal-blue-euro',            # Paper & Cardboard & Cardbaord 1100 ltr Bin
        'PA-1280'  => 'communal-blue-euro',            # Paper & Cardboard 1280 ltr Bin
        'PA-140'   => 'communal-blue-euro',            # Paper & Cardboard 140 ltr Bin
        'PA-240'   => 'communal-blue-euro',            # Paper & Cardboard 240 ltr Bin
        'PA-55'    => 'recycle-green-box',             # Paper & Cardboard 55 ltr Box
        'PA-660'   => 'communal-blue-euro',            # Paper & Cardboard 660 ltr Bin
        'PA-940'   => 'communal-blue-euro',            # Paper & Cardboard 940 ltr Bin
        'PL-1100'  => 'plastics-wheeled-bin',          # Plastic 1100 ltr Bin
        'PL-1280'  => 'plastics-wheeled-bin',          # Plastic 1280 ltr Bin
        'PL-140'   => 'plastics-wheeled-bin',          # Plastic 140 ltr Bin
        'PL-55'    => 'recycle-maroon-box',            # Plastic 55 ltr Box
        'PL-660'   => 'plastics-wheeled-bin',          # Plastic 660 ltr Bin
        'PL-940'   => 'plastics-wheeled-bin',          # Plastic 940 ltr Bin
        'PG-1100'  => 'plastics-wheeled-bin',          # Plastics & glass 1100 ltr euro bin
        'PG-1280'  => 'plastics-wheeled-bin',          # Plastics & glass 1280 ltr euro bin
        'PG-360'   => 'plastics-wheeled-bin',          # Plastics & glass 360 ltr wheeled bin
        'PG-55'    => 'white-recycling-box',           # Plastics & glass 55 ltr box
        'PG-660'   => 'plastics-wheeled-bin',          # Plastics & glass 660 ltr euro bin
        'PG-940'   => 'plastics-wheeled-bin',          # Plastics & glass 940 ltr chamberlain bin
        'RES-1100' => 'non-recyclable-wheeled-bin',    # Residual 1100 ltr bin
        'RES-1280' => 'non-recyclable-wheeled-bin',    # Residual 1280 ltr bin
        'RES-140'  => 'non-recyclable-wheeled-bin',    # Residual 140 ltr bin
        'RES-180'  => 'general-waste-green-bin',       # Residual 180 ltr bin
        'RES-660'  => 'non-recyclable-wheeled-bin',    # Residual 660 ltr bin
        'RES-720'  => 'non-recyclable-wheeled-bin',    # Residual 720 ltr bin
        'RES-940'  => 'non-recyclable-wheeled-bin',    # Residual 940 ltr bin
        'RES-CHAM' => 'non-recyclable-wheeled-bin',    # Residual Chamberlain
        'RES-DBIN' => 'non-recyclable-wheeled-bin',    # Residual Dustbin
        'RES-SACK' => 'black-non-recyclable-bag',      # Residual Sack

        # Plastics & glass 240 ltr wheeled bin
        'PG-240' => (
            $is_communal
            ? 'plastics-wheeled-bin'
            : 'recycling-bin-white-lid'
        ),
        # Residual 240 ltr bin
        'RES-240'  => (
            $is_communal
            ? 'non-recyclable-wheeled-bin'
            : 'general-waste-green-bin'
        ),
    };

    my $service_id = $unit->{service_id};

    return '/i/waste-containers/bulky-white' if $service_id eq 'bulky';
    return '/i/waste-containers/bexley/' . $images->{$service_id};
}

sub bin_day_format { '%A %-d %B %Y' }

sub waste_images_2x_unavailable { 1 }

# TODO This logic is copypasted across multiple files; get it into one place
my %irregulars = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 11 => 'th', 12 => 'th', 13 => 'th');
sub ordinal {
    my $n = shift;
    $irregulars{$n % 100} || $irregulars{$n % 10} || 'th';
}

sub _containers {
    my ( $self, $property ) = @_;

    my $is_communal = $property->{is_communal};

    my $clear_sack_desc = <<HTML;
For:
<ul>
<li>paper and cardboard</li>
<li>plastic bottles</li>
<li>glass bottles and jars</li>
<li>food and drinks cans</li>
</ul>
HTML

    return {
        'FO-140' => {
            name => 'Communal Food Bin',
            description => 'Food waste',
        },
        'FO-23' => {
            name => 'Brown Caddy',
            description => 'Food waste',
        },
        'GA-140' => {
            name => 'Brown Wheelie Bin',
            description => 'Garden waste',
        },
        'GA-240' => {
            name => 'Brown Wheelie Bin',
            description => 'Garden waste',
        },
        'GL-1100' => {
            name        => 'Green Recycling Bin',
            description => 'Glass bottles and jars',
        },
        'GL-1280' => {
            name        => 'Green Recycling Bin',
            description => 'Glass bottles and jars',
        },
        'GL-55' => {
            name        => 'Black Recycling Box',
            description => 'Glass bottles and jars',
        },
        'GL-660' => {
            name        => 'Green Recycling Bin',
            description => 'Glass bottles and jars',
        },
        'MDR-SACK' => {
            name                      => 'Clear Sacks',
            description               => $clear_sack_desc,
            description_contains_html => 1,
        },
        'PA-1100' => {
            name        => 'Blue Recycling Bin',
            description => 'Paper and card',
        },
        'PA-1280' => {
            name        => 'Blue Recycling Bin',
            description => 'Paper and card',
        },
        'PA-140' => {
            name        => 'Blue Recycling Bin',
            description => 'Paper and card',
        },
        'PA-240' => {
            name        => 'Blue Recycling Bin',
            description => 'Paper and card',
        },
        'PA-55' => {
            name        => 'Green Recycling Box',
            description => 'Paper and card',
        },
        'PA-660' => {
            name        => 'Blue Recycling Bin',
            description => 'Paper and card',
        },
        'PA-940' => {
            name        => 'Blue Recycling Bin',
            description => 'Paper and card',
        },
        'PC-180' => {
            name        => 'Blue Lidded Wheelie Bin',
            description => 'Paper and card',
        },
        'PC-55' => {
            name        => 'Blue Recycling Box',
            description => 'Paper and card',
        },
        'PG-1100' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics, cans and glass',
        },
        'PG-1280' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics, cans and glass',
        },
        'PG-240' => (
            $is_communal
            ? {
                name        => 'White / Silver Recycling Bin',
                description => 'Plastics, cans and glass',
            }
            : {
                name        => 'White Lidded Wheelie Bin',
                description => 'Plastics, cans and glass',
            }
        ),
        'PG-360' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics, cans and glass',
        },
        'PG-55' => {
            name        => 'White Recycling Box',
            description => 'Plastics, cans and glass',
        },
        'PG-660' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics, cans and glass',
        },
        'PG-940' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics, cans and glass',
        },
        'PL-1100' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics and cans',
        },
        'PL-1280' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics and cans',
        },
        'PL-140' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics and cans',
        },
        'PL-55' => {
            name        => 'Maroon Recycling Box',
            description => 'Plastics and cans',
        },
        'PL-660' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics and cans',
        },
        'PL-940' => {
            name        => 'White / Silver Recycling Bin',
            description => 'Plastics and cans',
        },
        'RES-1100' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-1280' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-140' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-180' => {
            name        => 'Green Wheelie Bin',
            description => 'Non-recyclable waste',
        },
        'RES-240' => (
            $is_communal
            ? {
                name        => 'Communal Refuse Bin(s)',
                description => 'Non-recyclable waste',
            }
            : {
                name        => 'Green Wheelie bin',
                description => 'Non-recyclable waste',
            }
        ),
        'RES-660' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-720' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-940' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-CHAM' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-DBIN' => {
            name        => 'Communal Refuse Bin(s)',
            description => 'Non-recyclable waste',
        },
        'RES-SACK' => {
            name        => 'Black Sacks',
            description => 'Non-recyclable waste',
        },
    };
}

# Weekends and bank holidays are not counted as working days
sub _subtract_working_days {
    my ( $self, $day_count, $dt ) = @_;

    # Default to today
    $dt = DateTime->today( time_zone => FixMyStreet->local_time_zone )
        unless $dt;

    my $wd = FixMyStreet::WorkingDays->new(
        public_holidays => FixMyStreet::Cobrand::UK::public_holidays() );

    return $wd->sub_days( $dt, $day_count );
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $property = $c->stash->{property};
    my $address = $property->{address};
    my $service_id = $c->stash->{services}{$id}{service_id};
    my $service_name = $c->stash->{services}{$id}{service_name};
    my $uprn = $c->stash->{services}{$id}{uprn};
    my $containers = $self->_containers($property);
    my $service_description = $containers->{$service_id}->{description};
    $service_description = 'Various' if $service_description =~ /<li>/;
    $data->{title} = "$service_name ($service_description)";
    $data->{detail} = "$data->{title}\n\n$address";
    $c->set_param('uprn', $uprn);
    $c->set_param('service_id', $id);
    $c->set_param('location_of_containers', $data->{bin_location}) if $data->{bin_location};
    $c->set_param('service_item_name', $service_id);
    $c->set_param('assisted_yn', $property->{has_assisted} ? 'Yes' : 'No');
}

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;

    push @$field_list, $self->_bin_location_field;
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;

    my $property = $self->{c}->stash->{property};
    my $address = $property->{address};
    $data->{title} = $data->{category};

    my $detail;
    foreach (sort grep { /^extra_/ } keys %$data) {
        my $extra = $data->{$_};
        if (ref $extra eq 'ARRAY') {
            my $value = join('; ', @$extra);
            $detail .= "$value\n\n";
        } else {
            $detail .= "$extra\n\n";
        }
    }
    $detail .= $address;
    $data->{detail} = $detail;

    $data->{extra_complaint_type} = $property->{is_communal} ? 'WFEE' : 'WRBDEL';
}

sub _bin_location_field {
    my $self = shift;

    my $c        = $self->{c};
    my $property = $c->stash->{property};

    my $type =
          $property->{is_communal} ? 'communal'
        : $property->{above_shop} ? 'above_shop'
        : $c->stash->{is_staff} || $property->{has_assisted} ? 'staff_or_assisted'
        : '';

    my $options = _bin_location_options()->{$type};

    if ($options) {
        $options = [
            ( '', '---Please select---' ),
            map { $_, $_ } @$options
        ];

        return ( bin_location => {
            type    => 'Select',
            label   => 'Bin location',
            options => $options,
            required => 1,
            tags => { label_as_heading => 1 },
        } );
    } else {
        return ( bin_location => {
            type    => 'Hidden',
            default => 'Front of property',
        } );
    }
}

sub _bin_location_options {
    return {
        staff_or_assisted => [
            'Front boundary of property',
            'Rear of property',
            'Side of property',
            'By the door',
            'Top of the driveway',
        ],
        communal => [
            'Front of property',
            'Inside the bin-store',
            'Inside the chute room',
            'In the car park',
            'In front of the block',
            'At the rear of the block',
            'To the side of the block',
            'In the under croft',
            'In the drying area',
            'Rear of property',
        ],
        above_shop => [
            'Front of property',
            'Next to front entrance',
            'Next to rear entrance',
            'Inside the bin-store',
            'Inside dustbin',
            'On first-floor balcony',
            'At the bottom of the steps',
            'Next to refuse bins',
        ],
    };
}

sub in_cab_logs_reason_prefixes {
    {
        'Clear Sacks' => ['MDR-SACK', 'CW-SACK'],
        'Paper & Card' => ['PA-1100', 'PA-1280', 'PA-140', 'PA-240', 'PA-55', 'PA-660', 'PA-940', 'PC-180', 'PC-55'],
        'Food' => ['FO-140', 'FO-23'],
        'Garden' => ['GA-140', 'GA-240'], # TODO Call Garden.pm->garden_service_ids to make sure these IDs are consistent
        'Plastics & Glass' => ['PG-1100', 'PG-1280', 'PG-240', 'PG-360', 'PG-55', 'PG-660', 'PG-940', 'PL-1100', 'PL-1280', 'PL-140', 'PL-55', 'PL-660', 'PL-940'],
        'Glass' => ['GL-1100', 'GL-1280', 'GL-55', 'GL-660'],
        'Refuse' => ['RES-1100', 'RES-1280', 'RES-140', 'RES-180', 'RES-240', 'RES-660', 'RES-720', 'RES-940', 'RES-CHAM', 'RES-DBIN', 'RES-SACK'],
    }
}

sub get_in_cab_logs_reason_prefix {
    my ($self, $service_name) = @_;

    my $prefixes = in_cab_logs_reason_prefixes();

    foreach my $prefix (keys %$prefixes) {
        if (grep { $_ eq $service_name } @{$prefixes->{$prefix}}) {
            return $prefix;
        }
    }

    return '';
}

# Container maintenance

sub construct_bin_request_form {
    my ( $self, $c ) = @_;

    my $request_type = $c->get_param('request_type');

    my $full_field_list;
    my $page_list;
    my $first_page;

    my $above_shop
        = $self->{c}->stash->{property}{above_shop} ? 1 : 0;
    my %bin_location_field = $above_shop ? () : $self->_bin_location_field;

    if ( $request_type eq 'delivery' ) {
        # Household size page needs to appear first, if applicable
        $first_page
            = $c->stash->{property}{household_size_check}
            ? 'household_size'
            : 'request';

        my $delivery_field_list
            = $self->_construct_bin_request_form_delivery($c);
        my $removal_field_list
            = $self->_construct_bin_request_form_removal($c);

        push @$delivery_field_list, %bin_location_field;

        # Not all properties have containers eligible for removal
        my $include_removal = @$removal_field_list;

        # Above-shop properties get a single default reason, so no need to send
        # them to reason selection. They need to be sent to letterbox location
        # selection instead.
        my $next
            = $include_removal
            ? 'request_removal'
            : ( $above_shop ? 'letterbox_location' : 'request_reason' );

        unshift @$removal_field_list, (
            no_removal => {
                type         => 'Checkbox',
                label        => 'None',
                option_label => 'I do not need any bins to be removed',
            }
        ) if $include_removal;

        $page_list = [
            request => {
                intro => 'container_delivery_intro.html',
                fields => [ grep { ! ref $_ } @$delivery_field_list, 'continue' ],
                title => 'Which bins do you need?',
                check_unique_id => 0,
                next => $next,
                update_field_list => sub {
                    my $form = shift;
                    my $fields
                        = $self->waste_request_form_update_field_list($form);
                    return $fields;
                },
            },
        ];
        $full_field_list = [ @$delivery_field_list ];

        if ( $include_removal ) {
            push @$page_list, (
                request_removal => {
                    intro => 'container_removal_intro.html',
                    fields => [ grep { ! ref $_ } @$removal_field_list, 'continue' ],
                    title => 'Which bins do you need to be removed?',
                    check_unique_id => 0,
                    next => ( $above_shop ? 'about_you' : 'request_reason' ),
                },
            );
            push @$full_field_list, @$removal_field_list;
        }

    } else {
        $first_page = 'request_removal';
        $full_field_list = $self->_construct_bin_request_form_removal($c);

        push @$full_field_list, %bin_location_field;

        $page_list = [
            request_removal => {
                intro  => 'container_removal_intro.html',
                fields => [ grep { ! ref $_ } @$full_field_list, 'continue' ],
                title => 'Which bins do you need to be removed?',
                check_unique_id => 0,
                next => 'request_reason',
            },
        ];

    }

    return (
        field_list => $full_field_list,
        first_page => $first_page,
        page_list  => $page_list,
    );
}

sub _construct_bin_request_form_delivery {
    my ( $self, $c ) = @_;

    my $field_list = [];

    my $property = $c->stash->{property};
    my $open_reports = $property->{open_reports}{delivery};

    for my $container ( @{ $property->{containers_for_delivery} } )
    {
        my $open_key = $container->{service_item_name} || $container->{name};
        my $disabled = $open_reports->{$open_key} ? 1 : 0;
        if ( $container->{subtypes} ) {
            my $id = $container->{name} =~ s/ /-/gr;

            push @$field_list, "parent-$id" => {
                type         => 'Checkbox',
                label        => $container->{name},
                option_label => $container->{description},
                tags         => { toggle => "form-bin-size-$id-row" },
                disabled     => $disabled,
            };

            push @$field_list, "bin-size-$id" => {
                type    => 'Select',
                label   => 'Bin Size',
                tags    => { initial_hidden => 1 },
                options => [
                    map {
                        label     => $_->{size},
                            value => $_->{service_item_name},
                    },
                    @{ $container->{subtypes} }
                ],
                required_when => { "parent-$id" => 1 },
            };
        } else {
            my $id = $container->{service_item_name} =~ s/ /-/gr;

            push @$field_list, "container-$id" => {
                type         => 'Checkbox',
                label        => $container->{name},
                option_label => $container->{description},
                tags         => { toggle => "form-quantity-$id-row" },
                disabled     => $disabled,
            };

            my $max = $container->{max} || 1;
            if ( $max > 1 ) {
                push @$field_list,
                    "quantity-$id" => {
                    type  => 'Select',
                    label => 'Quantity',
                    tags  => {
                        hint => "You can request a maximum of "
                            . NUMWORDS($max)
                            . ( $container->{name} eq 'Recycling Box Lids' ? ' lids' : ' bins' ),
                        initial_hidden => 1,
                    },
                    options => [
                        map { { value => $_, label => $_ } } ( 1 .. $max ),
                    ],
                    required_when => { "container-$id" => 1 },
                    };
            }
        }
    }

    return $field_list;
}

sub _construct_bin_request_form_removal {
    my ( $self, $c ) = @_;

    my $property = $c->stash->{property};
    return [] unless @{ $property->{containers_for_removal} };

    my $field_list = [];

    my $open_reports = $property->{open_reports}{removal};
    my %service_names_to_ids
            = map { $_->{service_name} => $_->{service_id} }
            @{ $self->{c}->stash->{service_data} };

    for my $container (
        @{ $property->{containers_for_removal} } )
    {
        my $open_key = $container->{service_item_name} || $container->{name};
        my $disabled = $open_reports->{$open_key} ? 1 : 0;

        if ($container->{subtypes}) {
            my $id = $container->{name} =~ s/ /-/gr;
            $id .= '-removal';

            push @$field_list, "parent-$id" => {
                type         => 'Checkbox',
                label        => $container->{name},
                option_label => $container->{description},
                tags         => { toggle => "form-bin-size-$id-row" },
                disabled     => $disabled,
            };

            push @$field_list, "bin-size-$id" => {
                type    => 'Select',
                label   => 'Bin Size',
                tags    => { initial_hidden => 1 },
                options => [
                    map {
                        label     => $_->{size},
                            value => $_->{service_item_name},
                    },
                    @{ $container->{subtypes} }
                ],
                required_when => { "parent-$id" => 1 },
            };

        } else {
            my $id = $container->{service_item_name} . '-removal';

            push @$field_list, "container-$id" => {
                type         => 'Checkbox',
                label        => $container->{name},
                option_label => $container->{description},
                tags => { toggle => "form-quantity-$id-row" },
                disabled => $disabled,
            };

            my $max = $container->{max} || 1;
            if ( $max > 1 ) {
                push @$field_list, "quantity-$id" => {
                    type => 'Select',
                    label => 'Quantity',
                    tags => {
                        hint => "You can request removal of a maximum of " . NUMWORDS($max) . " bins",
                        initial_hidden => 1,
                    },
                    options => [
                        map { { value => $_, label => $_ } }
                            ( 1 .. $max ),
                    ],
                    required_when => { "container-$id" => 1 },
                };
            }

        }
    }

    return $field_list;
}

sub waste_request_form_update_field_list {
    my ( $self, $form ) = @_;
    my $data = $form->saved_data;
    my $fields = {};

    # Change green wheelie bin size options depending on
    # household size
    if ( my $household_size = $data->{household_size} ) {
        my $field_name = 'bin-size-Green-Wheelie-Bin';
        my @original_options = $form->field($field_name)->options;

        return $fields if $household_size eq '5 or more'; # Allow all bin sizes

        if ( $household_size < 3 ) {
            # Small bin only
            $fields->{$field_name}{default}
                = $original_options[0]{value};
            $fields->{$field_name}{widget} = 'Hidden';
        } else {
            # 3 - 4 people: Allow small and medium bin
            $fields->{$field_name}{options} = [
                @original_options[0,1]
            ];
        }
    }

    return $fields;
}

sub waste_munge_request_form_data {
    my ( $self, $data ) = @_;

    # Populate subtype for any parent containers with a bin size
    for ( keys %$data ) {
        my ($parent_id) = /^parent-(.*)/;

        next unless $parent_id && $data->{"parent-$parent_id"};

        my $subtype_id = $data->{"bin-size-$parent_id"};

        if ($subtype_id) {
            $parent_id =~ /-removal/
                ? $data->{"container-$subtype_id-removal"} = 1
                : $data->{"container-$subtype_id"} = 1;
        }
    }
}

sub waste_munge_request_data {
    my ( $self, $id, $data ) = @_;

    my $c  = $self->{c};

    my $type = 'delivery';
    if ( $id =~ /-removal$/ ) {
        $type = 'removal';
    }

    my $service;

    my $containers
        = $type eq 'delivery'
        ? $c->stash->{property}{containers_for_delivery}
        : $c->stash->{property}{containers_for_removal};

    for my $ctr (@$containers) {
        # Removal options from form have a '-removal' suffix
        my $original_id = $id =~ s/-removal$//r;

        $service = $ctr
            if $original_id eq ( $ctr->{service_item_name} // '' );

        last if $service;

        if ( @{ $ctr->{subtypes} // [] } ) {
            # The service we are looking for may be the subtype of
            # a parent
            # (e.g. 'RES-140' under 'Green Wheelie Bin')
            for my $subtype ( @{ $ctr->{subtypes} } ) {
                if ( $original_id eq $subtype->{service_item_name} ) {
                    $service = $subtype;
                    # Use parent name
                    $service->{name} = $ctr->{name};
                    last;
                }
            }
        }

        last if $service;

        # Some containers have an original service_item_name (ID) with spaces.
        # E.g. 'Deliver Box lids 55L'.
        # We need to unhyphen string that was hyphenated in
        # construct_bin_request_form().
        my $id_spaced = $original_id =~ s/-/ /gr;

        if ( $id_spaced eq ( $ctr->{service_item_name} // '' ) ) {
            $service = $ctr;
        }

        last if $service;
    }

    if ( $type eq 'delivery' ) {
        $data->{title}    = "Request new $service->{name}";
        $data->{category} = $data->{category_delivery};
    } else {
        $data->{title}    = "Request removal of $service->{name}";
        $data->{category} = $data->{category_removal};
    }

    my $reason;
    my $letterbox_location;
    my $bin_location;
    if ( $c->stash->{property}{above_shop} ) {
        $reason = 'I need more sacks';
        $letterbox_location = $data->{letterbox_location};
    } else {
        $reason = $data->{request_reason};
        $bin_location = $data->{bin_location};
    }

    my $address = $c->stash->{property}{address};
    my $quantity = $data->{"quantity-$id"} || 1;
    my $household_size = $data->{household_size};
    $data->{detail} = "$data->{title}\n\n$address";
    $data->{detail} .= "\n\nReason: $reason";
    $data->{detail} .= "\n\nQuantity: $quantity";
    $data->{detail} .= "\n\nHousehold size: $household_size"
        if $household_size;
    $data->{detail} .= "\n\nLocation of letterbox: $letterbox_location"
        if $letterbox_location;

    my $assisted_yn = $c->stash->{property}{has_assisted} ? 'Yes' : 'No';

    $c->set_param( 'uprn',              $c->stash->{property}{uprn} );
    $c->set_param( 'service_item_name', $service->{service_item_name} );
    $c->set_param( 'quantity',          $quantity );
    $c->set_param( 'assisted_yn', $assisted_yn );
    $c->set_param( 'location_of_letterbox', $letterbox_location || '' );
    $c->set_param( 'location_of_containers', $bin_location || '' );
}

sub _set_request_containers {
    my ( $self, $property, @services ) = @_;

    return if $property->{is_communal};

    my %all_service_ids = map { $_->{service_id} => 1 } @services;

    my @containers_for_delivery;
    my @containers_for_removal;
    my $boxes_done;

    for my $service ( @services ) {
        # NB: 'service_id' here is equivalent to Whitespace ServiceItemName
        # ('service_item_name' in _containers_for_requests())
        my $service_id = $service->{service_id};
        my $round_schedule = $service->{round_schedule};
        my $container_info;
        my $name;

        if (   $service_id eq 'RES-140'
            || $service_id eq 'RES-180'
            || $service_id eq 'RES-240' )
        {
            $name = 'Green Wheelie Bin';
            $container_info
                = _containers_for_requests()->{$name};
            push @containers_for_delivery, $container_info;
            push @containers_for_removal,  $container_info;

            $service->{delivery_allowed} = 1;
            $service->{removal_allowed}  = 1;
            $service->{parent_name} = $name;

            $property->{has_wheelie_bins} //= 1;

        } elsif ( $service_id eq 'PC-140'
            || $service_id eq 'PC-180'
            || $service_id eq 'PC-240' )
        {
            $name = 'Blue Lidded Wheelie Bin';
            $container_info
                = _containers_for_requests()->{$name};
            push @containers_for_delivery, $container_info;
            push @containers_for_removal,  $container_info;

            $service->{delivery_allowed} = 1;
            $service->{removal_allowed}  = 1;
            $service->{parent_name} = $name;

            $property->{has_wheelie_bins} //= 1;

        } elsif ( $service_id eq 'PG-140'
            || $service_id eq 'PG-180'
            || $service_id eq 'PG-240' )
        {
            $name = 'White Lidded Wheelie Bin';
            $container_info
                = _containers_for_requests()->{$name};
            push @containers_for_delivery, $container_info;
            push @containers_for_removal,  $container_info;

            $service->{delivery_allowed} = 1;
            $service->{removal_allowed}  = 1;
            $service->{parent_name} = $name;

            $property->{has_wheelie_bins} //= 1;

        } elsif ( $service_id eq 'FO-23' ) {
            my $food_waste
                = _containers_for_requests()->{'Food Waste'};
            for ( @$food_waste ) {
                # NOTE We always offer Kitchen Caddy as a deliverable
                # container even though it is never shown on the bin days page
                push @containers_for_delivery, $_;
                push @containers_for_removal, $_
                    if $_->{service_id_removal};
            }

            $service->{delivery_allowed} = 1;
            $service->{removal_allowed}  = 1;

        } elsif ( $service_id eq 'MDR-SACK' ) {
            $container_info
                = _containers_for_requests()->{'Clear Sacks'};
            push @containers_for_delivery, $container_info;

            $service->{delivery_allowed} = 1;

        } elsif ( $round_schedule =~ /BOX/ ) {
            $name = 'Recycling Boxes';
            my $boxes = _containers_for_requests()->{$name};

            for ( @$boxes ) {
                # Any box with service_id_delivery is eligible for delivery
                # even if property doesn't have that box currently.
                if ( $_->{service_id_delivery} ) {
                    push @containers_for_delivery, $_ unless $boxes_done;

                    $service->{delivery_allowed} = 1
                        if $service->{service_id} eq $_->{service_item_name};
                }

                # Conversely, property must have a given box already for
                # it to be removable.
                if ( $_->{service_id_removal} ) {
                    push @containers_for_removal, $_
                        if $all_service_ids{ $_->{service_item_name} }
                        && !$boxes_done;

                    $service->{removal_allowed} = 1
                        if $service->{service_id} eq $_->{service_item_name};
                }
            }

            # Any property with boxes can also order lids
            unless ($boxes_done) {
                push @containers_for_delivery,
                    _containers_for_requests()->{'Recycling Box Lids'};

                $property->{has_boxes} = 1;
            }

            $boxes_done = 1;

        }

        $property->{household_size_check} = 1
            if $container_info->{household_size_check};
    }

    $property->{containers_for_delivery} = \@containers_for_delivery;
    $property->{containers_for_removal}  = \@containers_for_removal;
}

sub requests_for_display {
    my ( $self, $data ) = @_;

    my @requested_deliveries;
    my @requested_removals;

    my %by_id
        = %{ $self->_request_containers_by_id( $self->{c}->stash->{property} ) };

    for my $id ( keys %by_id ) {
        my $hyphen_id = $id =~ s/ /-/gr;

        if ( $data->{"container-$hyphen_id-removal"} ) {
            # Deref so we don't mutate the original in %by_id
            my %container = %{ $by_id{$id} };
            $container{quantity} = $data->{"quantity-$hyphen_id-removal"};
            push @requested_removals, \%container;
        }
        if ( $data->{"container-$hyphen_id"} ) {
            # Deref so we don't mutate the original in %by_id
            my %container = %{ $by_id{$id} };
            $container{quantity} = $data->{"quantity-$hyphen_id"};
            push @requested_deliveries, \%container;
        }
    }

    # TODO This is very similar to waste_munge_request_form_data(); is
    # there a way to consolidate all of this data munging?
    for ( keys %$data ) {
        my ($parent_id) = /^parent-(.*)/;
        next unless $parent_id && $data->{"parent-$parent_id"};

        my $subtype_id = $data->{"bin-size-$parent_id"};
        my %container = %{ $by_id{$subtype_id} };
        $parent_id =~ /-removal/
            ? ( push @requested_removals, \%container )
            : ( push @requested_deliveries, \%container );
    }

    return \@requested_deliveries, \@requested_removals;
}

sub _request_containers_by_id {
    my ( $self, $property ) = @_;

    my %by_id;

    my @all_for_requests = (
        @{ $property->{containers_for_delivery} },
        @{ $property->{containers_for_removal} },
    );

    for my $container (@all_for_requests) {
        if ( $container->{subtypes} ) {
            for ( @{ $container->{subtypes} } ) {
                $by_id{ $_->{service_item_name} } = {
                    name             => $container->{name},
                    description      => $container->{description},
                    size_description => $_->{size},
                };
            }
        } else {
            $by_id{ $container->{service_item_name} } = {
                name        => $container->{name},
                description => $container->{description},
            };
        }
    }

    return \%by_id;
}

sub _containers_for_requests {
    return {
        'Green Wheelie Bin' => {
            name                 => 'Green Wheelie Bin',
            description          => 'Non-recyclable waste',
            household_size_check => 1,
            subtypes    => [
                {   size                => 'Small 140 litre',
                    service_item_name   => 'RES-140',
                    service_id_delivery => '272',
                    service_id_removal  => '205',
                },
                {   size                => 'Medium 180 litre',
                    service_item_name   => 'RES-180',
                    service_id_delivery => '273',
                    service_id_removal  => '206',
                },
                {   size                => 'Large 240 litre',
                    service_item_name   => 'RES-240',
                    service_id_delivery => '274',
                    service_id_removal  => '207',
                },
            ],
        },
        'Blue Lidded Wheelie Bin' => {
            name        => 'Blue Lidded Wheelie Bin',
            description => 'Paper and card',
            subtypes    => [
                {   size                => 'Small 140 litre',
                    service_item_name   => 'PC-140',
                    service_id_delivery => '325',
                    service_id_removal  => '333',
                },
                {   size                => 'Medium 180 litre',
                    service_item_name   => 'PC-180',
                    service_id_delivery => '326',
                    service_id_removal  => '334',
                },
                {   size                => 'Large 240 litre',
                    service_item_name   => 'PC-240',
                    service_id_delivery => '327',
                    service_id_removal  => '335',
                },
            ],
        },
        'White Lidded Wheelie Bin' => {
            name        => 'White Lidded Wheelie Bin',
            description => 'Plastics, cans and glass',
            subtypes    => [
                {   size                => 'Small 140 litre',
                    service_item_name   => 'PG-140',
                    service_id_delivery => '329',
                    service_id_removal  => '337',
                },
                {   size                => 'Medium 180 litre',
                    service_item_name   => 'PG-180',
                    service_id_delivery => '330',
                    service_id_removal  => '338',
                },
                {   size                => 'Large 240 litre',
                    service_item_name   => 'PG-240',
                    service_id_delivery => '331',
                    service_id_removal  => '339',
                },
            ],
        },

        'Recycling Boxes' => [
            {   name               => 'Green Recycling Box',
                description        => 'Paper and card',
                service_item_name  => 'PA-55',
                service_id_removal => '181',
                max                => 3,
            },
            {   name               => 'Maroon Recycling Box',
                description        => 'Plastics and cans',
                service_item_name  => 'PL-55',
                service_id_removal => '192',
                max                => 3,
            },
            {   name               => 'Black Recycling Box',
                description        => 'Glass bottles and jars',
                service_item_name  => 'GL-55',
                service_id_removal => '166',
                max                => 3,
            },
            {   name                => 'White Recycling Box',
                description         => 'Plastics, cans and glass',
                service_item_name   => 'PG-55',
                service_id_delivery => '328',
                service_id_removal  => '336',
                max                 => 3,
            },
            {   name                => 'Blue Recycling Box',
                description         => 'Paper and card',
                service_item_name   => 'PC-55',
                service_id_delivery => '324',
                service_id_removal  => '332',
                max                 => 3,
            },
        ],

        'Clear Sacks' => {
            name                => 'Clear Sacks',
            description         => 'Mixed recycling',
            service_item_name   => 'MDR-SACK',
            service_id_delivery => '243',
        },

        'Food Waste' => [
            {   name                => 'Brown Caddy',
                description         => 'Food waste',
                service_item_name   => 'FO-23',
                service_id_delivery => '224',
                service_id_removal  => '156',
                max                 => 3,
            },
            {   name                => 'Kitchen Caddy',
                description         => 'Food waste',
                service_item_name   => 'Kitchen 5 Ltr Caddy',
                service_id_delivery => '235',
            },
        ],

        'Recycling Box Lids' => {
            name                => 'Recycling Box Lids',
            service_item_name   => 'Deliver Box lids 55L',
            service_id_delivery => '216',
            max                 => 5,
        },
    };
}

sub _parent_for_container {
    my $id = shift;
    my $parents = {
        'RES-140' => 'Green Wheelie Bin',
        'RES-180' => 'Green Wheelie Bin',
        'RES-240' => 'Green Wheelie Bin',
        'PC-140' => 'Blue Lidded Wheelie Bin',
        'PC-180' => 'Blue Lidded Wheelie Bin',
        'PC-240' => 'Blue Lidded Wheelie Bin',
        'PG-140' => 'White Lidded Wheelie Bin',
        'PG-180' => 'White Lidded Wheelie Bin',
        'PG-240' => 'White Lidded Wheelie Bin',
    };
    return $parents->{$id} || $id;
}

=head2 waste_get_paye_narrative

Return a custom narrative for Bexley to use in paye.net integration

=cut

sub waste_get_paye_narrative {
    my ($self, $p) = @_;
    my $id = $p->id;
    if ($p->category eq 'Bulky collection') {
        return "Bulky waste - $id";
    } else {
        my $uprn = $p->get_extra_field_value('uprn');
        return "Garden Waste Service Payment - Reference: $id Contract: $uprn";
    }
}

1;
