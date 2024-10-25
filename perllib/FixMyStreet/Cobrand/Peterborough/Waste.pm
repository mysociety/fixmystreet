=head1 NAME

FixMyStreet::Cobrand::Peterborough::Waste - code specific to the Peterborough cobrand waste parts

=head1 SYNOPSIS

We integrate with Peterborough's Bartec system for waste collection services,
including bulky waste collection.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Peterborough::Waste;
use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::Waste';
with 'FixMyStreet::Roles::Cobrand::SCP';
with 'FixMyStreet::Cobrand::Peterborough::Bulky';

use utf8;
use strict;
use warnings;
use DateTime;
use Hash::Util qw(lock_hash);
use Integrations::Bartec;
use List::Util qw(any);
use Sort::Key::Natural qw(natkeysort_inplace);
use FixMyStreet::WorkingDays;
use FixMyStreet::App::Form::Waste::Request::Peterborough;
use Utils;

my %SERVICES = (
    new_all_bins => 425,
    new_black_240 => 419,
    new_black_360 => 422,
    new_food_both => 493,
    new_food_bag => 428,
    new_green_240 => 420,
    new_food_caddy_large => 424,
    new_food_caddy_small => 423,
    missed_assisted => 492,
    missed_food => 252,
    lid_green_240 => 537,
    lid_black_240 => 538,
    lid_brown_240 => 539,
    wheels_green_240 => 540,
    wheels_black_240 => 541,
    wheels_brown_240 => 542,
    not_returned => 497,
);
lock_hash(%SERVICES);

my %CONTAINERS = (
    black_240 => 6533,
    black_1100 => 6836,
    green_240 => 6534,
    brown_240 => 6579,
);
lock_hash(%CONTAINERS);

sub service_name_override {
    my $self = shift;
    return {
        "Empty Bin 240L Black"      => "Black Bin",
        "Empty Bin 240L Brown"      => "Brown Bin",
        "Empty Bin 240L Green"      => "Green Bin",
        "Empty Black 240l Bin"      => "Black Bin",
        "Empty Brown 240l Bin"      => "Brown Bin",
        "Empty Green 240l Bin"      => "Green Bin",
        "Empty Bin Recycling 1100l" => "Recycling Bin",
        "Empty Bin Recycling 240l"  => "Recycling Bin",
        "Empty Bin Recycling 660l"  => "Recycling Bin",
        "Empty Bin Refuse 1100l"    => "Refuse",
        "Empty Bin Refuse 240l"     => "Refuse",
        "Empty Bin Refuse 660l"     => "Refuse",
    };
}

sub _premises_for_postcode {
    my $self = shift;
    my $pc = shift;
    my $c = $self->{c};

    my $key = "peterborough:bartec:premises_for_postcode:$pc";

    my $data = $c->waste_cache_get($key);
    return $data if $data;

    my $cfg = $self->feature('bartec');
    my $bartec = Integrations::Bartec->new(%$cfg);
    my $response = $bartec->Premises_Get($pc);

    if (!$c->user_exists || !($c->user->from_body || $c->user->is_superuser)) {
        my $blocked = $cfg->{blocked_uprns} || [];
        my %blocked = map { $_ => 1 } @$blocked;
        @$response = grep { !$blocked{$_->{UPRN}} } @$response;
    }

    $data = [ map { {
        id => $pc . ":" . $_->{UPRN},
        uprn => $_->{UPRN},
        usrn => $_->{USRN},
        address => $self->_format_address($_),
        latitude => $_->{Location}->{Metric}->{Latitude},
        longitude => $_->{Location}->{Metric}->{Longitude},
    } } @$response ];

    return $c->waste_cache_set($key, $data);
}

sub clear_cached_lookups_postcode {
    my ($self, $pc) = @_;
    my $key = "peterborough:bartec:premises_for_postcode:$pc";
    $self->{c}->waste_cache_delete($key);
}

sub clear_cached_lookups_property {
    my ($self, $uprn) = @_;

    # might be prefixed with postcode if it's come straight from the URL
    $uprn =~ s/^.+\://g;

    foreach ( qw/bin_services_for_address/ ) {
        $self->{c}->waste_cache_delete("peterborough:bartec:$_:$uprn");
    }

    $self->clear_cached_lookups_bulky_slots($uprn);
}

sub clear_cached_lookups_bulky_slots {
    my ($self, $uprn) = @_;

    # might be prefixed with postcode
    $uprn =~ s/^.+\://g;

    for (qw/earlier later/) {
        $self->{c}->waste_cache_delete("peterborough:bartec:available_bulky_slots:$_:$uprn");
    }
}

sub bin_addresses_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $premises = $self->_premises_for_postcode($pc);
    my $data = [ map { {
        value => $pc . ":" . $_->{uprn},
        label => $_->{address},
    } } @$premises ];
    natkeysort_inplace { $_->{label} } @$data;
    return $data;
}

my %irregulars = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 11 => 'th', 12 => 'th', 13 => 'th');
sub ordinal {
    my $n = shift;
    $irregulars{$n % 100} || $irregulars{$n % 10} || 'th';
}

sub construct_bin_date {
    my $str = shift;
    return unless $str;
    my $date = DateTime::Format::W3CDTF->parse_datetime($str);
    return $date;
}

sub look_up_property {
    my $self = shift;
    my $id = shift;
    return unless $id;

    my ($pc, $uprn) = split ":", $id;
    my $premises = $self->_premises_for_postcode($pc);
    my %premises = map { $_->{uprn} => $_ } @$premises;
    return $premises{$uprn};
}

sub image_for_unit {
    my ($self, $unit) = @_;
    my $service_id = $unit->{service_id};
    my $base = '/i/waste-containers';
    my $images = {
        $CONTAINERS{black_240} => svg_container_bin('wheelie', '#333333'),
        $CONTAINERS{green_240} => svg_container_bin("wheelie", '#41B28A'),
        $CONTAINERS{brown_240} => svg_container_bin("wheelie", '#8B5E3D'),
        bulky => "$base/bulky-white",
    };
    return $images->{$service_id};
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        # For new containers
        $SERVICES{new_black_240} => "240L Black",
        $SERVICES{new_green_240} => "240L Green",
        $SERVICES{new_all_bins} => "All bins",
        $SERVICES{new_food_both} => "Both food bins",
        $SERVICES{new_food_caddy_large} => "Large food caddy",
        $SERVICES{new_food_caddy_small} => "Small food caddy",
        $SERVICES{new_food_bag} => "Food bags",

        "FOOD_BINS" => "Food bins",
        "ASSISTED_COLLECTION" => "Assisted collection",

        # For missed collections or repairs
        $CONTAINERS{black_240} => "240L Black",
        $CONTAINERS{green_240} => "240L Green",
        $CONTAINERS{brown_240} => "240L Brown",
        "LARGE BIN" => "360L Black", # Actually would be service 422
    };

    my %container_request_ids = (
        $CONTAINERS{black_240} => [ $SERVICES{new_black_240} ], # 240L Black
        $CONTAINERS{green_240} => [ $SERVICES{new_green_240} ], # 240L Green
        $CONTAINERS{brown_240} => undef, # 240L Brown
        $CONTAINERS{black_1100} => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
        # all bins?
        # large food caddy?
        # small food caddy?
    );

    my %container_service_ids = (
        $CONTAINERS{black_240} => 255, # 240L Black
        $CONTAINERS{green_240} => 254, # 240L Green
        $CONTAINERS{brown_240} => 253, # 240L Brown
        $CONTAINERS{black_1100} => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
        # black 360L?
    );

    my %container_request_max = (
        $CONTAINERS{black_240} => 1, # 240L Black
        $CONTAINERS{green_240} => 1, # 240L Green
        $CONTAINERS{brown_240} => 1, # 240L Brown
        $CONTAINERS{black_1100} => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
        # all bins?
        # large food caddy?
        # small food caddy?
    );

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    my $uprn = $property->{uprn};

    my @calls = (
        Jobs_Get => [ $uprn ],
        Features_Schedules_Get => [ $uprn ],
        Jobs_FeatureScheduleDates_Get => [ $uprn ],
        Premises_Detail_Get => [ $uprn ],
        Premises_Events_Get => [ $uprn ],
        Streets_Events_Get => [ $property->{usrn} ],
        ServiceRequests_Get => [ $uprn ],
        Premises_Attributes_Get => [ $uprn ],
    );

    # we can only do an async lookup and thus page refresh when navigating
    # directly to the bin days page, not when e.g. calling this sub as a result
    # of going to the /bulky page.
    my $async = $self->{c}->action eq 'waste/bin_days' && $self->{c}->req->method eq 'GET';

    my $results = $bartec->call_api($self->{c}, 'peterborough', 'bin_services_for_address:' . $uprn, $async, @calls);

    my $jobs = $results->{"Jobs_Get $uprn"};
    my $schedules = $results->{"Features_Schedules_Get $uprn"};
    my $jobs_featureschedules = $results->{"Jobs_FeatureScheduleDates_Get $uprn"};
    my $detail_uprn = $results->{"Premises_Detail_Get $uprn"};
    my $events_uprn = $results->{"Premises_Events_Get $uprn"};
    my $events_usrn = $results->{"Streets_Events_Get " . $property->{usrn}};
    my $requests = $results->{"ServiceRequests_Get $uprn"};
    my $attributes = $results->{"Premises_Attributes_Get $uprn"};

    my $code = $detail_uprn->{BLPUClassification}{ClassificationCode} || '';
    $property->{commercial_property} = $code =~ /^C/;

    my %attribs = map { $_->{AttributeDefinition}->{Name} => 1 } @$attributes;
    $property->{attributes} = \%attribs;

    my $job_dates = relevant_jobs($jobs_featureschedules, $uprn, $schedules);
    my $open_requests = $self->open_service_requests_for_uprn($uprn, $requests);

    my %feature_to_workpack;
    foreach (@$jobs) {
        my $workpack = $_->{WorkPack}{Name};
        my $name = $_->{Name};
        #my $start = construct_bin_date($_->{ScheduledStart})->ymd;
        #my $status = $_->{Status}{Status};
        $feature_to_workpack{$name} = $workpack;
    }

    my %lock_out_types = map { $_ => 1 } ('BIN NOT OUT', 'CONTAMINATION', 'EXCESS WASTE', 'OVERWEIGHT', 'WRONG COLOUR BIN', 'NO ACCESS - street', 'NO ACCESS');
    my %premise_dates_to_lock_out;
    my %street_workpacks_to_lock_out;
    foreach (@$events_uprn) {
        my $container_id = $_->{Features}{FeatureType}{ID};
        my $date = construct_bin_date($_->{EventDate})->ymd;
        my $type = $_->{EventType}{Description};
        next unless $lock_out_types{$type};
        my $types = $premise_dates_to_lock_out{$date}{$container_id} ||= [];
        push @$types, $type;
    }
    foreach (@$events_usrn) {
        my $workpack = $_->{Workpack}{Name};
        my $type = $_->{EventType}{Description};
        my $date = construct_bin_date($_->{EventDate});
        # e.g. NO ACCESS 1ST TRY, NO ACCESS 2ND TRY, NO ACCESS BAD WEATHE, NO ACCESS GATELOCKED, NO ACCESS PARKED CAR, NO ACCESS POLICE, NO ACCESS ROADWORKS
        $type = 'NO ACCESS - street' if $type =~ /NO ACCESS/;
        next unless $lock_out_types{$type};
        $street_workpacks_to_lock_out{$workpack} = { type => $type, date => $date };
    }

    my %schedules = map { $_->{JobName} => $_ } @$schedules;
    $self->{c}->stash->{open_service_requests} = $open_requests;

    $self->{c}->stash->{waste_features} = $self->feature('waste_features');

    my @out;
    my %seen_containers;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

    foreach (@$job_dates) {
        my $last = construct_bin_date($_->{PreviousDate});
        my $next = construct_bin_date($_->{NextDate});
        my $name = $_->{JobName};
        my $container_id = $schedules{$name}->{Feature}->{FeatureType}->{ID};

        # Some properties may have multiple of the same containers - only display each once.
        next if $seen_containers{$container_id};
        $seen_containers{$container_id} = 1;

        my $report_service_id = $container_service_ids{$container_id};
        my @report_service_ids_open = grep { $open_requests->{$_} } $report_service_id;
        my $request_service_ids = $container_request_ids{$container_id};
        # Open request for same thing, or for all bins, or for large black bin
        my @request_service_ids_open = grep { $open_requests->{$_} || $open_requests->{$SERVICES{new_all_bins}} || ($_ == $SERVICES{new_black_240} && $open_requests->{$SERVICES{new_black_360}}) } @$request_service_ids;

        my %requests_open = map { $_ => 1 } @request_service_ids_open;

        if ( $container_id == $CONTAINERS{black_240} || $container_id == $CONTAINERS{black_1100} ) {    # Black bin
            $property->{has_black_bin} = 1;
        }

        my $last_obj = $last ? { date => $last, ordinal => ordinal($last->day) } : undef;
        my $next_obj = $next ? { date => $next, ordinal => ordinal($next->day) } : undef;
        my $row = {
            id => $_->{JobID},
            last => $last_obj,
            next => $next_obj,
            service_name => service_name_override()->{$name} || $name,
            schedule => $schedules{$name}->{Frequency},
            service_id => $container_id,
            request_containers => $request_service_ids,

            # can this container type be requested?
            request_allowed => $container_request_ids{$container_id} ? 1 : 0,
            # what's the maximum number of this container that can be request?
            request_max => $container_request_max{$container_id} || 0,
            # is there already an open bin request for this container?
            requests_open => \%requests_open,
            # can this collection be reported as having been missed?
            report_allowed => $last ? $self->_waste_report_allowed($last) : 0,
            # is there already a missed collection report open for this container
            # (or a missed assisted collection for any container)?
            report_open => ( @report_service_ids_open || $open_requests->{$SERVICES{missed_assisted}} ) ? 1 : 0,
        };
        if ($row->{report_allowed}) {
            # We only get here if we're within the 1.5 day window after the collection.
            # Set this so missed food collections can always be reported, as they don't
            # have their own collection event.
            $self->{c}->stash->{any_report_allowed} = 1;

            # If on the day, but before 5pm, show a special message to call
            # (which is slightly different for staff, who are actually allowed to report)
            if ($last->ymd eq $now->ymd && $now->hour < 17) {
                my $is_staff = $self->{c}->user_exists && $self->{c}->user->from_body && $self->{c}->user->from_body->get_column('name') eq "Peterborough City Council";
                $row->{report_allowed} = $is_staff ? 1 : 0;
                $row->{report_locked_out} = [ "ON DAY PRE 5PM" ];
                # Set a global flag to show things in the sidebar
                $self->{c}->stash->{on_day_pre_5pm} = 1;
            }
            # But if it has been marked as locked out, show that
            if (my $types = $premise_dates_to_lock_out{$last->ymd}{$container_id}) {
                $row->{report_allowed} = 0;
                $row->{report_locked_out} = $types;
            }
        }
        # Last date is last successful collection. If whole street locked out, it hasn't started
        my $workpack = $feature_to_workpack{$name} || '';
        if (my $lockout = $street_workpacks_to_lock_out{$workpack}) {
            $row->{report_allowed} = 0;
            $row->{report_locked_out} = [ $lockout->{type} ];
            my $last = $lockout->{date};
            $row->{last} = { date => $last, ordinal => ordinal($last->day) };
        }
        push @out, $row;
    }

    $property->{show_bulky_waste} = $self->bulky_allowed_property($property);

    # Some need to be added manually as they don't appear in Bartec responses
    # as they're not "real" collection types (e.g. requesting all bins)

    my $bags_only = $self->{c}->get_param('bags_only');
    my $skip_bags = $self->{c}->get_param('skip_bags');

    @out = () if $bags_only;

    my @food_containers;
    if ($bags_only) {
        push(@food_containers, $SERVICES{new_food_bag}) unless $open_requests->{$SERVICES{new_food_bag}};
    } else {
        unless ( $open_requests->{$SERVICES{new_food_both}} || $open_requests->{$SERVICES{new_all_bins}} ) { # Both food bins, or all bins
            push(@food_containers, $SERVICES{new_food_caddy_large}) unless $open_requests->{$SERVICES{new_food_caddy_large}}; # Large food caddy
            push(@food_containers, $SERVICES{new_food_caddy_small}) unless $open_requests->{$SERVICES{new_food_caddy_small}}; # Small food caddy
        }
        push(@food_containers, $SERVICES{new_food_bag}) unless $skip_bags || $open_requests->{$SERVICES{new_food_bag}};
    }

    push(@out, {
        id => "FOOD_BINS",
        service_name => "Food bins",
        service_id => "FOOD_BINS",
        request_containers => \@food_containers,
        request_allowed => 1,
        request_max => 1,
        request_only => 1,
        report_only => !$open_requests->{$SERVICES{missed_food}}, # Can report if no open report
    }) if @food_containers;

    # All bins, black bin, green bin, large black bin, small food caddy, large food caddy, both food bins
    my $any_open_bin_request = any { $open_requests->{$_} } ($SERVICES{new_all_bins}, $SERVICES{new_black_240}, $SERVICES{new_green_240}, $SERVICES{new_black_360}, $SERVICES{new_food_caddy_small}, $SERVICES{new_food_caddy_large}, $SERVICES{new_food_both});
    unless ( $bags_only || $any_open_bin_request ) {
        # We want this one to always appear first
        unshift @out, {
            id => "_ALL_BINS",
            service_name => "All bins",
            service_id => "_ALL_BINS",
            request_containers => [ $SERVICES{new_all_bins} ],
            request_allowed => 1,
            request_max => 1,
            request_only => 1,
        };
    }
    return \@out;
}

sub relevant_jobs {
    my ($jobs, $uprn, $schedules) = @_;
    my %schedules = map { $_->{JobName} => $_ } @$schedules;
    my @jobs = grep {
        my $name = $_->{JobName};
        my $schedule_name = $schedules{$name}->{Feature}->{Status}->{Name} || '';
        $schedule_name eq 'IN SERVICE'
        && $schedules{$name}->{Feature}->{FeatureType}->{ID} != 6815;
    } @$jobs;
    return \@jobs;
}

=pod

Missed bins can be reported up until 4pm the working day following the last
collection day. So a bin not collected on Tuesday can be rung through up to
4pm on Wednesday, and one not collected on Friday can be rung through up to
4pm Monday.

=cut

sub _waste_report_allowed {
    my ($self, $dt) = @_;

    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, 1);
    $dt->set( hour => 16, minute => 0, second => 0 );
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    return $now <= $dt;
}

sub bin_future_collections {
    my $self = shift;

    my $bartec = $self->feature('bartec');
    $bartec = Integrations::Bartec->new(%$bartec);

    my $uprn = $self->{c}->stash->{property}{uprn};
    my $schedules = $bartec->Features_Schedules_Get($uprn);
    my $jobs_featureschedules = $bartec->Jobs_FeatureScheduleDates_Get($uprn);
    my $jobs = relevant_jobs($jobs_featureschedules, $uprn, $schedules);

    my $events = [];
    foreach (@$jobs) {
        my $dt = construct_bin_date($_->{NextDate});
        push @$events, { date => $dt, desc => '', summary => $_->{JobName} };
    }
    return $events;
}

sub open_service_requests_for_uprn {
    my ($self, $uprn, $requests) = @_;

    my %open_requests;
    foreach (@$requests) {
        my $service_id = $_->{ServiceType}->{ID};
        my $status = $_->{ServiceStatus}->{Status};
        # XXX need to confirm that this list is complete and won't change in the future...
        next unless $status =~ /PENDING|INTERVENTION|OPEN|ASSIGNED|IN PROGRESS/;
        $open_requests{$service_id} = 1;
    }
    return \%open_requests;
}

sub waste_munge_request_form_data {
    my ($self, $data) = @_;

    # In the UI we show individual checkboxes for large and small food caddies.
    # If the user requests both containers then we want to raise a single
    # request for both, rather than one request for each.
    if ($data->{"container-$SERVICES{new_food_caddy_large}"} && $data->{"container-$SERVICES{new_food_caddy_small}"}) {
        $data->{"container-$SERVICES{new_food_caddy_large}"} = 0;
        $data->{"container-$SERVICES{new_food_caddy_small}"} = 0;
        $data->{"container-$SERVICES{new_food_both}"} = 1;
        $data->{"quantity-$SERVICES{new_food_both}"} = 1;
    }
}

sub waste_munge_report_form_data {
    my ($self, $data) = @_;

    my $attributes = $self->{c}->stash->{property}->{attributes};

    if ( $attributes->{"ASSISTED COLLECTION"} ) {
        # For assisted collections we just raise a single "missed assisted collection"
        # report, instead of the usual thing of one per container.
        # The details of the bins that were missed are stored in the problem body.

        $data->{assisted_detail} = "";
        $data->{assisted_detail} .= "Food bins\n\n" if $data->{"service-FOOD_BINS"};
        $data->{assisted_detail} .= "Black bin\n\n" if $data->{"service-$CONTAINERS{black_240}"};
        $data->{assisted_detail} .= "Green bin\n\n" if $data->{"service-$CONTAINERS{green_240}"};
        $data->{assisted_detail} .= "Brown bin\n\n" if $data->{"service-$CONTAINERS{brown_240}"};

        $data->{"service-FOOD_BINS"} = 0;
        $data->{"service-$CONTAINERS{black_240}"} = 0;
        $data->{"service-$CONTAINERS{green_240}"} = 0;
        $data->{"service-$CONTAINERS{brown_240}"} = 0;
        $data->{"service-ASSISTED_COLLECTION"} = 1;
    }
}

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;

    push @$field_list, "extra_detail" => {
        type => 'Text',
        widget => 'Textarea',
        label => 'Please supply any additional information such as the location of the bin.',
        maxlength => 1_000,
        messages => {
            text_maxlength => 'Please use 1000 characters or less for additional information.',
        },
    };
}

sub waste_munge_request_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{"quantity-$id"};
    my $reason = $data->{request_reason} || '';

    $reason = {
        lost_stolen => 'Lost/stolen bin',
        new_build => 'New build',
        other_staff => '(Other - PD STAFF)',
    }->{$reason} || $reason;

    $data->{title} = "Request new $container";
    $data->{detail} = "Quantity: $quantity\n\n$address";
    $data->{detail} .= "\n\nReason: $reason" if $reason;

    if ( $data->{extra_detail} ) {
        $data->{detail} .= "\n\nExtra detail: " . $data->{extra_detail};
    }

    $data->{category} = $self->body->contacts->find({ email => "Bartec-$id" })->category;
}

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    return "BULKY-" . $p->get_extra_field_value('uprn') . "-" .$p->get_extra_field_value('DATE');
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return "BULKY-" . $p->get_extra_field_value('uprn') . "-" .$p->get_extra_field_value('DATE');
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "BULKY-" . $p->get_extra_field_value('uprn') . "-" .$p->get_extra_field_value('DATE');
}

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
    };
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    if ( $service->{service_name} eq 'Bulky collection' ) {
        push @$meta, {
            code => 'payment',
            datatype => 'string',
            description => 'Payment',
            order => 101,
            required => 'false',
            variable => 'true',
            automated => 'hidden_field',
        }, {
            code => 'payment_method',
            datatype => 'string',
            description => 'Payment method',
            order => 101,
            required => 'false',
            variable => 'true',
            automated => 'hidden_field',
        }, {
            code => 'property_id',
            datatype => 'string',
            description => 'Property ID',
            order => 101,
            required => 'false',
            variable => 'true',
            automated => 'hidden_field',
        };
    }
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;
    my $c = $self->{c};

    my %container_service_ids = (
        "FOOD_BINS" => $SERVICES{missed_food}, # Food bins (pseudocontainer hardcoded in bin_services_for_address)
        "ASSISTED_COLLECTION" => $SERVICES{missed_assisted}, # Will only be set by waste_munge_report_form_data (if property has assisted attribute)
        $CONTAINERS{black_240} => 255, # 240L Black
        $CONTAINERS{green_240} => 254, # 240L Green
        $CONTAINERS{brown_240} => 253, # 240L Brown
        $CONTAINERS{black_1100} => undef, # Refuse 1100l
        6837 => undef, # Refuse 660l
        6839 => undef, # Refuse 240l
        6840 => undef, # Recycling 1100l
        6841 => undef, # Recycling 660l
        6843 => undef, # Recycling 240l
    );

    my $service_id = $container_service_ids{$id};

    if ($service_id == 255) {
        my $attributes = $c->stash->{property}->{attributes};
        if ($attributes->{"LARGE BIN"}) {
            # For large bins, we need different text to show
            $id = "LARGE BIN";
        }
    }

    if ( $data->{assisted_detail} ) {
        $data->{title} = "Report missed assisted collection";
        $data->{detail} = $data->{assisted_detail};
        $data->{detail} .= "\n\n" . $c->stash->{property}->{address};
    } else {
        my $container = $c->stash->{containers}{$id};
        $data->{title} = "Report missed $container";
        $data->{title} .= " bin" if $container !~ /^Food/;
        $data->{detail} = $c->stash->{property}->{address};
    }

    if ( $data->{extra_detail} ) {
        $data->{detail} .= "\n\nExtra detail: " . $data->{extra_detail};
    }

    $data->{category} = $self->body->contacts->find({ email => "Bartec-$service_id" })->category;
}

sub waste_munge_problem_data {
    my ($self, $id, $data) = @_;
    my $c = $self->{c};

    my $service_details = $self->{c}->stash->{services_problems}->{$id};
    my $container_id = $service_details->{container} || 0; # 497 doesn't have a container

    my $category = $self->body->contacts->find({ email => "Bartec-$id" })->category;
    my $category_verbose = $service_details->{label};

    if ($container_id == $CONTAINERS{black_240} && $category =~ /Lid|Wheels/) { # 240L Black repair
        my $attributes = $c->stash->{property}->{attributes};
        if ($attributes->{"LARGE BIN"}) {
            # For large bins, we need to raise a new bin request instead
            $container_id = "LARGE BIN";
            $category = 'Black 360L bin';
            $category_verbose .= ", exchange bin";
        }
    }

    my $bin = $c->stash->{containers}{$container_id};
    $data->{category} = $category;
    $data->{title} = $category =~ /Lid|Wheels/ ? "Damaged $bin bin" :
                    $category =~ /Not returned/ ? "Bin not returned" : $bin;
    $data->{detail} = "$category_verbose\n\n" . $c->stash->{property}->{address};
    if ( $data->{extra_detail} ) {
        $data->{detail} .= "\n\nExtra detail: " . $data->{extra_detail};
    }
}

sub waste_munge_problem_form_fields {
    my ($self, $field_list) = @_;

    my $not_staff = !($self->{c}->user_exists && $self->{c}->user->from_body && $self->{c}->user->from_body->get_column('name') eq "Peterborough City Council");
    my $label_497 = $not_staff
    ? 'The bin wasn’t returned to the collection point (Please phone 01733 747474 to report this issue)'
    : 'The bin wasn’t returned to the collection point';

    my %services_problems = (
        $SERVICES{lid_black_240} => {
            container => $CONTAINERS{black_240},
            container_name => "Black bin",
            label => "The bin’s lid is damaged",
        },
        $SERVICES{wheels_black_240} => {
            container => $CONTAINERS{black_240},
            container_name => "Black bin",
            label => "The bin’s wheels are damaged",
        },
        $SERVICES{lid_green_240} => {
            container => $CONTAINERS{green_240},
            container_name => "Green bin",
            label => "The bin’s lid is damaged",
        },
        $SERVICES{wheels_green_240} => {
            container => $CONTAINERS{green_240},
            container_name => "Green bin",
            label => "The bin’s wheels are damaged",
        },
        $SERVICES{lid_brown_240} => {
            container => $CONTAINERS{brown_240},
            container_name => "Brown bin",
            label => "The bin’s lid is damaged",
        },
        $SERVICES{wheels_brown_240} => {
            container => $CONTAINERS{brown_240},
            container_name => "Brown bin",
            label => "The bin’s wheels are damaged",
        },
        $SERVICES{not_returned} => {
            container_name => "General",
            label => $label_497,
            disabled => $not_staff,
        },
    );
    $self->{c}->stash->{services_problems} = \%services_problems;

    my %services;
    foreach (keys %services_problems) {
        my $v = $services_problems{$_};
        next unless $v->{container};
        $services{$v->{container}} ||= {};
        $services{$v->{container}}{$_} = $v->{label};
    }

    my $open_requests = $self->{c}->stash->{open_service_requests};
    @$field_list = ();

    foreach (@{$self->{c}->stash->{service_data}}) {
        my $id = $_->{service_id};
        my $name = $_->{service_name};

        next unless $services{$id};

        # Don't allow any problem reports on a bin if a new one is currently
        # requested. Check for large bin requests for black bins as well
        my $black_bin_request = (($open_requests->{$SERVICES{new_black_240}} || $open_requests->{$SERVICES{new_black_360}}) && $id == $CONTAINERS{black_240});
        my $green_bin_request = ($open_requests->{$SERVICES{new_green_240}} && $id == $CONTAINERS{green_240});

        my $categories = $services{$id};
        foreach (sort keys %$categories) {
            my $cat_name = $categories->{$_};
            my $disabled = $open_requests->{$_} || $black_bin_request || $green_bin_request;
            push @$field_list, "service-$_" => {
                type => 'Checkbox',
                label => $name,
                option_label => $cat_name,
                disabled => $disabled,
            };

            # Set this to empty so the heading isn't shown multiple times
            $name = '';
        }
    }
    push @$field_list, "service-$SERVICES{not_returned}" => {
        type => 'Checkbox',
        label => $self->{c}->stash->{services_problems}->{$SERVICES{not_returned}}->{container_name},
        option_label => $self->{c}->stash->{services_problems}->{$SERVICES{not_returned}}->{label},
        disabled => $open_requests->{$SERVICES{not_returned}} || $self->{c}->stash->{services_problems}->{$SERVICES{not_returned}}->{disabled},
    };

    push @$field_list, "extra_detail" => {
        type => 'Text',
        widget => 'Textarea',
        label => 'Please supply any additional information such as the location of the bin.',
        maxlength => 1_000,
        messages => {
            text_maxlength => 'Please use 1000 characters or less for additional information.',
        },
    };

}

sub waste_request_form_first_title { 'Which bins do you need?' }
sub waste_request_form_first_next {
    my $self = shift;
    return 'replacement' unless $self->{c}->get_param('bags_only');
    return 'about_you';
}

sub _format_address {
    my ($self, $property) = @_;

    my $a = $property->{Address};
    my $prefix = join(" ", $a->{Address1}, $a->{Address2}, $a->{Street});
    return Utils::trim_text(FixMyStreet::Template::title(join(", ", $prefix, $a->{Town}, $a->{PostCode})));
}

sub bin_day_format { '%A, %-d~~~ %B %Y' }

sub _bulky_send_optional_text {
    my ($self, $report, $url, $params) = @_;

    my %message_data = ();
    my $title;
    if ($params->{text_type} eq 'confirmed') {
        $title = 'Bulky waste booking';
    } else {
        $title = 'Bulky waste reminder';
    }
    $message_data{to} = $report->phone_waste;
    my $address = $report->detail;
    $address =~ s/\s\|.*?$//; # Address may contain ref to Bartec report
    $message_data{body} =
    sprintf("%s\n\n
            Date: %s
            Items: %d
            %s
            Reference: %d
            Please note the items put out for collection must be the items you specified when you booked.",
            $title,
            $self->bulky_nice_collection_date($report->get_extra_field_value('DATE')),
            scalar grep ({ $_->{name} =~ /^ITEM/ && $_->{value} } @{$report->get_extra_fields}),
            $address,
            $report->id);
    FixMyStreet::SMS->new(cobrand => $self, notify_choice => 'waste')->send(
        %message_data,
    );
}

1;
