package FixMyStreet::Cobrand::Bromley;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use utf8;
use DateTime;
use DateTime::Format::Strptime;
use DateTime::Format::W3CDTF;
use Integrations::Echo;
use BromleyParks;
use FixMyStreet::App::Form::Waste::Request::Bromley;
use FixMyStreet::DB;
use Moo;
with 'FixMyStreet::Roles::Cobrand::Echo';
with 'FixMyStreet::Roles::Cobrand::Pay360';
with 'FixMyStreet::Roles::Open311Multi';
with 'FixMyStreet::Roles::Cobrand::SCP';
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

sub council_area_id { return 2482; }
sub council_area { return 'Bromley'; }
sub council_name { return 'Bromley Council'; }
sub council_url { return 'bromley'; }

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->detail ) > 1750 ) {
        $errors->{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1750 );
    }

    return $errors;
}

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    my $tfl = FixMyStreet::DB->resultset('Body')->search({ name => 'TfL' })->first;
    return $rs->to_body($tfl ? [ $self->body->id, $tfl->id ] : $self->body);
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bromley';

    #  There has been a road name change for a section of Ramsden Road
    #  (BR5) between Church Hill and Court Road has changed to 'Old Priory
    #  Avenue' - presently entering Old Priory Avenue simply takes the user to
    #  a different Priory Avenue in Petts Wood
    #  From Google maps search, "BR6 0PL" is a valid postcode for Old Priory Avenue
    if ($string =~/^old\s+priory\s+av\w*$/i) {
        $town = 'BR6 0PL';
    }

    # White Horse Hill is on boundary with Greenwich, so need a
    # specific postcode
    $town = 'BR7 6DH' if $string =~ /^white\s+horse/i;

    $town = '' if $string =~ /orpington/i;
    $string =~ s/(, *)?br[12]$//i;
    $town = 'Beckenham' if $string =~ s/(, *)?br3$//i;
    $town = 'West Wickham' if $string =~ s/(, *)?br4$//i;
    $town = 'Orpington' if $string =~ s/(, *)?br[56]$//i;
    $town = 'Chislehurst' if $string =~ s/(, *)?br7$//i;
    $town = 'Swanley' if $string =~ s/(, *)?br8$//i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        string => $string,
        town => $town,
        centre => '51.366836,0.040623',
        span   => '0.154963,0.24347',
        bounds => [ 51.289355, -0.081112, 51.444318, 0.162358 ],
    };
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if (my $parks_lookup = BromleyParks::lookup($s)) {
        return $parks_lookup;
    }

    # split postcode with Lewisham
    if ($s =~ /BR1\s*4EY/i) {
        return {
            latitude => 51.4190772,
            longitude => 0.0117805,
        };
    }

    return $self->next::method($s);
}

# Bromley pins always yellow
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if ($context||'') ne 'reports' && !$self->owns_problem($p);
    return 'yellow';
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 3 if $num > 3 && $area eq 'alert';
    return $self->problems->recent_photos({
        num => $num,
        point => [$lat, $lon, $dist],
    });
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

sub process_open311_extras {
    my $self = shift;
    $self->SUPER::process_open311_extras( @_, [ 'first_name', 'last_name' ] );
}

sub abuse_reports_only { 1; }

sub reports_per_page { return 20; }

sub tweak_all_reports_map {
    my $self = shift;
    my $c = shift;

    if ( !$c->stash->{ward} ) {
        $c->stash->{map}->{longitude} = 0.040622967881348;
        $c->stash->{map}->{latitude} = 51.36690161822;
        $c->stash->{map}->{any_zoom} = 0;
        $c->stash->{map}->{zoom} = 11;
    }
}

sub title_list {
    return ["MR", "MISS", "MRS", "MS", "DR", 'PCSO', 'PC', 'N/A'];
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};


    return unless $c->stash->{is_staff};

    if ( $c->user->has_permission_to('can_pay_with_csc', $self->body->id) ) {
        $c->stash->{staff_payments_allowed} = 'paye';
    }
}

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Waste}->{can_pay_with_csc} = "Can use CSC to pay for subscriptions";

    return $perms;
}

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    if ($contact->category eq 'Bulky collection') {
        $params->{multi_photos} = 1;
        $params->{upload_files} = 1;
    }

    $params->{always_send_latlong} = 0;
    $params->{send_notpinpointed} = 1;
    $params->{extended_description} = 0;
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $title = $row->title;

    my $extra = $row->get_extra_fields;
    foreach (@$extra) {
        next unless $_->{value};
        $title .= ' | ID: ' . $_->{value} if $_->{name} eq 'feature_id';
        $title .= ' | PROW ID: ' . $_->{value} if $_->{name} eq 'prow_reference';
    }

    # Add contributing user's roles to report title
    my $contributed_by = $row->get_extra_metadata('contributed_by');
    my $contributing_user = FixMyStreet::DB->resultset('User')->find({ id => $contributed_by });
    my $roles;
    if ($contributing_user) {
        $roles = join(',', map { $_->name } $contributing_user->roles->all);
    }
    if ($roles) {
        $title .= ' | ROLES: ' . $roles;
    }

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'report_title',
          value => $title },
        { name => 'public_anonymity_required',
          value => $row->anonymous ? 'TRUE' : 'FALSE' },
        { name => 'email_alerts_requested',
          value => 'FALSE' }, # always false as can never request them
        { name => 'requested_datetime',
          value => DateTime::Format::W3CDTF->format_datetime($row->confirmed->set_nanosecond(0)) },
        { name => 'email',
          value => $row->user->email }
    ];

    if ( $row->category eq 'Garden Subscription' ) {
        if ( $row->get_extra_metadata('contributed_as') && $row->get_extra_metadata('contributed_as') eq 'anonymous_user' ) {
            push @$open311_only, { name => 'contributed_as', value => 'anonymous_user' };
        }
    }

    # make sure we have last_name attribute present in row's extra, so
    # it is passed correctly to Bromley as attribute[]
    if (!$row->get_extra_field_value('last_name')) {
        my ( $firstname, $lastname ) = ( $row->name =~ /(\S+)\.?\s+(.+)/ );
        push @$open311_only, { name => 'last_name', value => $lastname };
    }
    if (!$row->get_extra_field_value('fms_extra_title') && $row->user->title) {
        push @$open311_only, { name => 'fms_extra_title', value => $row->user->title };
    }

    return $open311_only;
}

sub open311_extra_data_exclude {
    [ 'feature_id', 'prow_reference' ]
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{endpoints} = {
        service_request_updates => 'update.xml',
        update => 'update.xml'
    } if $params->{endpoint} =~ /bromley.gov.uk/;
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    $self->_include_user_title_in_extra($row);

    my $private_comments = $row->get_extra_metadata('private_comments');
    if ($private_comments) {
        my $text = $row->detail . "\n\nPrivate comments: $private_comments";
        $row->detail($text);
    }
}

sub _include_user_title_in_extra {
    my ($self, $row) = @_;

    my $extra = $row->extra || {};
    unless ( $extra->{title} ) {
        $extra->{title} = $row->user->title || 'n/a';
        $row->extra( $extra );
    }
}

sub open311_pre_send_updates {
    my ($self, $row) = @_;

    $self->{bromley_original_update_text} = $row->text;

    my $private_comments = $row->get_extra_metadata('private_comments');
    if ($private_comments) {
        my $text = $row->text . "\n\nPrivate comments: $private_comments";
        $row->text($text);
    }

    return $self->_include_user_title_in_extra($row);
}

sub open311_post_send_updates {
    my ($self, $row) = @_;

    $row->text($self->{bromley_original_update_text});
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    delete $params->{update_id};
    $params->{public_anonymity_required} = $comment->anonymous ? 'TRUE' : 'FALSE',
    $params->{update_id_ext} = $comment->id;
    $params->{service_request_id_ext} = $comment->problem->id;
}

sub open311_post_send {
    my ($self, $row, $h, $sender) = @_;
    my $error = $sender->error;
    my $db = FixMyStreet::DB->schema->storage;
    $db->txn_do(sub {
        my $row2 = FixMyStreet::DB->resultset('Problem')->search({ id => $row->id }, { for => \'UPDATE' })->single;
        if ($error =~ /Cannot renew this property, a new request is required/ && $row2->title eq "Garden Subscription - Renew") {
            # Was created as a renewal, but due to DD delay has now expired. Switch to new subscription
            $row2->title("Garden Subscription - New");
            $row2->update_extra_field({ name => "Subscription_Type", value => $self->waste_subscription_types->{New} });
            $row2->update;
            $row->discard_changes;
        } elsif ($error =~ /Missed Collection event already open for the property/) {
            $row2->state('duplicate');
            $row2->update;
            $row->discard_changes;
        } elsif ($error =~ /Selected reservations expired|Invalid reservation reference/) {
            $self->bulky_refetch_slots($row2);
            $row->discard_changes;
        }
    });
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    my %server_set = (easting => 1, northing => 1, service_request_id_ext => 1);
    my $id_field = 0;
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
        $id_field = 1 if $_->{code} eq 'service_request_id_ext';
    }
    if ($id_field) {
        $contact->set_extra_metadata( id_field => 'service_request_id_ext');
    } else {
        $contact->unset_extra_metadata('id_field');
    }

    # Lights we want to store feature ID, PROW on all categories.
    push @$meta, {
        code => 'prow_reference',
        datatype => 'string',
        description => 'Right of way reference',
        order => 101,
        required => 'false',
        variable => 'true',
        automated => 'hidden_field',
    };
    push @$meta, {
        code => 'feature_id',
        datatype => 'string',
        description => 'Feature ID',
        order => 100,
        required => 'false',
        variable => 'true',
        automated => 'hidden_field',
    } if $service->{service_code} =~ /^SL_/;

    my @override = qw(
        requested_datetime
        report_url
        title
        last_name
        email
        report_title
        public_anonymity_required
        email_alerts_requested
    );
    my %ignore = map { $_ => 1 } @override;
    @$meta = grep { !$ignore{$_->{code}} } @$meta;
}

=head2 should_skip_sending_update

Do not send updates to the backend if they were made by a staff user and
don't have any text (public or private).

=cut

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $private_comments = $update->get_extra_metadata('private_comments');
    my $has_text = $update->text || $private_comments;
    return $update->user->from_body && !$has_text;
}

sub munge_report_new_category_list {
    my ($self, $category_options, $contacts) = @_;

    my $user = $self->{c}->user;
    if ($user && $user->belongs_to_body($self->body->id) && $user->get_extra_metadata('assigned_categories_only')) {
        my %user_categories = map { $_ => 1} @{$user->categories};
        my $non_bromley_or_assigned_category = sub {
            $_->body_id != $self->body->id || $user_categories{$_->category}
        };

        @$category_options = grep &$non_bromley_or_assigned_category, @$category_options;
        @$contacts = grep &$non_bromley_or_assigned_category, @$contacts;
    }
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;

    # No updates on waste reports
    return 'waste' if $problem->cobrand_data eq 'waste';

    return $self->next::method(@_);
}

sub image_for_unit {
    my ($self, $unit) = @_;
    my $service_id = $unit->{service_id};
    my $base = '/i/waste-containers';
    my $images = {
        531 => "$base/sack-black",
        532 => "$base/sack-black",
        533 => "$base/large-communal-grey-black-lid",
        535 => "$base/box-green-mix",
        536 => "$base/bin-grey-green-lid-recycling",
        537 => "$base/box-black-paper",
        541 => "$base/bin-grey-blue-lid-recycling",
        542 => "$base/caddy-green-recycling",
        544 => "$base/bin-brown-recycling",
        545 => "$base/bin-black-brown-lid-recycling",
    };
    return $images->{$service_id};
}

=head2 waste_on_the_day_criteria

If it's before 5pm on the day of collection, treat an Outstanding task as if
it's the next collection and in progress, and do not allow missed collection
reporting if the task is not completed.

=cut

sub waste_on_the_day_criteria {
    my ($self, $completed, $state, $now, $row) = @_;

    return unless $now->hour < 17;
    if ($state eq 'Outstanding') {
        $row->{next} = $row->{last};
        $row->{next}{state} = 'In progress';
        delete $row->{last};
    }
    if (!$completed) {
        $row->{report_allowed} = 0;
    }
}

sub waste_staff_choose_payment_method { 0 }
sub waste_cheque_payments { 0 }

sub waste_event_state_map {
    return {
        New => { New => 'confirmed' },
        Pending => {
            Unallocated => 'investigating',
            'Allocated to Crew' => 'action scheduled',
            Accepted => 'action scheduled',
        },
        Closed => {
            Closed => 'fixed - council',
            Completed => 'fixed - council',
            'Not Completed' => 'unable to fix',
            'Partially Completed' => 'closed',
            Rejected => 'closed',
        },
    };
}

sub garden_service_id { 545 }
sub garden_service_name { 'Green Garden Waste collection service' }
sub garden_subscription_type_field { 'Subscription_Type' }
sub garden_subscription_container_field { 'Subscription_Details_Container_Type' }
sub garden_subscription_email_renew_reminder_opt_in { 0 }
sub garden_echo_container_name { 'LBB - GW Container' }
sub garden_due_days { 48 }

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        531 => 'Non-Recyclable Refuse',
        532 => 'Non-Recyclable Refuse',
        533 => 'Non-Recyclable Refuse',
        535 => 'Mixed Recycling (Cans, Plastics & Glass)',
        536 => 'Mixed Recycling (Cans, Plastics & Glass)',
        537 => 'Paper & Cardboard',
        541 => 'Paper & Cardboard',
        542 => 'Food Waste',
        544 => 'Food Waste',
        545 => 'Garden Waste',
    );

    return $service_name_override{$service->{ServiceId}} || $service->{ServiceName};
}

sub waste_containers {
    return {
        1 => 'Green Box (Plastic)',
        3 => 'Wheeled Bin (Plastic)',
        12 => 'Black Box (Paper)',
        14 => 'Wheeled Bin (Paper)',
        9 => 'Kitchen Caddy',
        10 => 'Outside Food Waste Container',
        44 => 'Garden Waste Container',
        46 => 'Wheeled Bin (Food)',
    };
}

sub waste_service_to_containers {
    return (
        535 => [ 1 ],
        536 => [ 3 ],
        537 => [ 12 ],
        541 => [ 14 ],
        542 => [ 9, 10 ],
        544 => [ 46 ],
        545 => [ 44 ],
    );
}

sub waste_quantity_max {
    return (
        535 => 6,
        536 => 4,
        537 => 6,
        541 => 4,
        542 => 6,
        544 => 4,
        545 => 6,
    );
}

sub garden_subscription_event_id { 2106 }

# Bulky collection event. No blocks on reporting a missed collection based on the state and resolution code.
sub waste_bulky_missed_blocked_codes { {} }

sub waste_extra_service_info {
    my ($self, $property, @rows) = @_;

    my $waste_cfg = $self->{c}->stash->{waste_features};

    # If we have a service ID for trade properties, consider a property domestic
    # unless we see it.
    my $trade_service_id;
    if ($waste_cfg) {
        if ($trade_service_id = $waste_cfg->{bulky_trade_service_id}) {
            $property->{pricing_property_type} = 'Domestic';
        }
    }

    foreach (@rows) {
        if (defined($trade_service_id) && $_->{ServiceId} eq $trade_service_id) {
            $property->{pricing_property_type} = 'Trade';
        }

        my $servicetask = $_->{ServiceTask};
        my $data = Integrations::Echo::force_arrayref($servicetask->{Data}, 'ExtensibleDatum');
        $self->{c}->stash->{assisted_collection} = $self->assisted_collection($data);
    }
}

sub garden_container_data_extract {
    my ($self, $data) = @_;
    my $moredata = Integrations::Echo::force_arrayref($data->{ChildData}, 'ExtensibleDatum');
    foreach (@$moredata) {
        # $container = $_->{Value} if $_->{DatatypeName} eq 'Container'; # should be 44
        if ( $_->{DatatypeName} eq 'Quantity' ) {
            my $garden_bins = $_->{Value};
            my $garden_cost = $self->garden_waste_cost_pa($garden_bins) / 100;
            return ($garden_bins, 0, $garden_cost);
        }
    }
}

sub assisted_collection {
    my ($self, $data) = @_;
    my $strp = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' );
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    my ($ac_end, $ac_flag);
    foreach (@$data) {
        $ac_end = $strp->parse_datetime($_->{Value})->ymd if $_->{DatatypeName} eq "Indicator End Date";
        $ac_flag = 1 if $_->{DatatypeName} eq "Task Indicator" && $_->{Value} eq 'LBB - Assisted Collection';
    }
    return ($ac_flag && $ac_end gt $today);
}

sub _closed_event {
    my ($self, $event) = @_;
    return 1 if $event->{ResolvedDate};
    return 1 if $event->{ResolutionCodeId} && $event->{ResolutionCodeId} != 584; # Out of Stock
    return 0;
}

sub missed_event_types { {
    2095 => 'missed',
    2096 => 'missed',
    2097 => 'missed',
    2098 => 'missed',
    2099 => 'missed',
    2100 => 'missed',
    2101 => 'missed',
    2102 => 'missed',
    2103 => 'missed',
    2104 => 'request',
    2175 => 'bulky',
} }

sub waste_garden_sub_params {
    my ($self, $data, $type) = @_;
    my $c = $self->{c};

    my %container_types = map { $c->{stash}->{containers}->{$_} => $_ } keys %{ $c->stash->{containers} };
    my $container_actions = {
        deliver => 1,
        remove => 2,
    };

    $c->set_param('Subscription_Type', $type);
    $c->set_param('Subscription_Details_Container_Type', $container_types{'Garden Waste Container'});
    $c->set_param('Subscription_Details_Quantity', $data->{bin_count});
    if ( $data->{new_bins} ) {
        if ( $data->{new_bins} > 0 ) {
            $c->set_param('Container_Instruction_Action', $container_actions->{deliver} );
        } elsif ( $data->{new_bins} < 0 ) {
            $c->set_param('Container_Instruction_Action',  $container_actions->{remove} );
        }
        $c->set_param('Container_Instruction_Container_Type', $container_types{'Garden Waste Container'});
        $c->set_param('Container_Instruction_Quantity', abs($data->{new_bins}));
    }

    $self->_set_user_source;
}

sub garden_waste_dd_get_redirect_params {
    my ($self, $c) = @_;

    my $token = $c->get_param('reference');
    my $id = $c->get_param('report_id');

    return ($token, $id);
}

sub garden_waste_check_pending {
    my ($self, $report) = @_;
    return $report;
}


sub _set_user_source {
    my $self = shift;
    my $c = $self->{c};
    return if !$c->user_exists || !$c->user->from_body;

    my %roles = map { $_->name => 1 } $c->user->obj->roles->all;
    my $source = 9; # Client Officer
    $source = 3 if $roles{'Contact Centre Agent'} || $roles{'CSC'}; # Council Contact Centre
    $c->set_param('Source', $source);
}

sub waste_request_form_first_next {
    my $self = shift;
    return sub {
        my $data = shift;
        return 'replacement' if $data->{"container-44"};
        return 'about_you';
    };
}

sub waste_munge_request_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{"quantity-$id"};
    my $reason = $data->{replacement_reason} || '';
    $data->{title} = "Request new $container";
    $data->{detail} = "Quantity: $quantity\n\n$address";
    $c->set_param('Container_Type', $id);
    $c->set_param('Quantity', $quantity);
    if ($id == 44) {
        if ($reason eq 'damaged') {
            $c->set_param('Action', '2::1'); # Remove/Deliver
            $c->set_param('Reason', 3); # Damaged
        } elsif ($reason eq 'stolen' || $reason eq 'taken') {
            $c->set_param('Reason', 1); # Missing / Stolen
        }
    } else {
        # Don't want to be remembered from previous loop
        $c->set_param('Action', '');
        $c->set_param('Reason', '');
    }
    $self->_set_user_source;
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $service = $c->stash->{services}{$id}{service_name};
    $data->{title} = "Report missed $service";
    $data->{detail} = "$data->{title}\n\n$address";
    $c->set_param('service_id', $id);
    $self->_set_user_source;
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;

    my $address = $self->{c}->stash->{property}->{address};
    $data->{title} = $data->{category};

    my $detail;
    foreach (sort grep { /^extra_/ } keys %$data) {
        $detail .= "$data->{$_}\n\n";
    }
    $detail .= $address;
    $data->{detail} = $detail;
    $self->_set_user_source;
}

sub waste_get_pro_rata_cost {
    my ($self, $bins, $end) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($end);
    my $cost = $bins * $self->waste_get_pro_rata_bin_cost( $sub_end, $now );

    return $cost;
}

sub waste_get_pro_rata_bin_cost {
    my ($self, $end, $start) = @_;

    my $weeks = $end->delta_days($start)->in_units('weeks');
    $weeks -= 1 if $weeks > 0;

    my $base = $self->_get_cost('pro_rata_minimum', $start);
    my $weekly_cost = $self->_get_cost('pro_rata_weekly', $start);
    my $cost = sprintf "%.0f", ($base + ( $weeks * $weekly_cost ));

    return $cost;
}

=head2 garden_waste_renewal_cost_pa

The price change for a renewal is based upon the end
date of the subscription, not the current date.

=cut

sub garden_waste_renewal_cost_pa {
    my ($self, $end_date, $bin_count) = @_;
    $bin_count ||= 1;
    my $per_bin_cost = $self->_get_cost('ggw_cost', $end_date);
    my $cost = $per_bin_cost * $bin_count;
    return $cost;
}

sub garden_waste_new_bin_admin_fee { 0 }

sub waste_payment_ref_council_code { "LBB" }

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->get_extra_field_value('uprn') unless $p->category eq 'Bulky collection';
    return $p->id;
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->get_extra_field_value('uprn');
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->get_extra_field_value('uprn');
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        staff_role => 'Staff Role',
    );

    return if $csv->dbi; # All covered already

    my $user_lookup = $self->csv_staff_users;
    my $userroles = $self->csv_staff_roles($user_lookup);

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $by = $report->get_extra_metadata('contributed_by');
        my $staff_user = '';
        my $staff_role = '';
        if ($by) {
            $staff_user = $self->csv_staff_user_lookup($by, $user_lookup);
            $staff_role = join(',', @{$userroles->{$by} || []});
        }
        return {
            staff_user => $staff_user,
            staff_role => $staff_role,
        };
    });
}

sub report_form_extras {
    ( { name => 'private_comments' } )
}

=head2 Bulky waste collection

Bromley has bulky waste collections starting at 7:00. It looks 4 weeks ahead
for collection dates, and sends the event to the backend before collecting
payment. Cancellations are done by update.

=cut

sub bulky_collection_time { { hours => 7, minutes => 0 } }
sub bulky_cancellation_cutoff_time { { hours => 7, minutes => 0, days_before => 0 } }
sub bulky_collection_window_days { 28 }
sub bulky_cancel_by_update { 1 }
sub bulky_free_collection_available { 0 }
sub bulky_hide_later_dates { 1 }
sub bulky_send_before_payment { 1 }
sub bulky_location_text_prompt {
  "Please provide the exact location where the items will be left ".
  "(e.g., On the driveway; To the left of the front door; By the front hedge, etc.)." .
  " Please note items can't be collected inside the property."
}

sub bulky_minimum_charge { $_[0]->wasteworks_config->{per_item_min_collection_price} }

sub bulky_booking_paid {
    my ($self, $collection) = @_;
    return $collection->get_extra_metadata('payment_reference');
}

sub bulky_can_refund_collection {
    my ($self, $collection) = @_;
    return 0 if !$self->bulky_booking_paid($collection);
    return 0 if !$self->within_bulky_cancel_window($collection);
    return $self->bulky_refund_amount($collection) > 0;
}

sub bulky_send_cancellation_confirmation {
    my ($self, $collection_report) = @_;
    my $c = $self->{c};
    $c->send_email(
        'waste/bulky-confirm-cancellation.txt',
        {   to => [
                [ $collection_report->user->email, $collection_report->name ]
            ],

            wasteworks_id => $collection_report->id,
            paid => $self->bulky_booking_paid($collection_report),
            refund_amount => $self->bulky_refund_amount($collection_report),
            collection_date => $self->bulky_nice_collection_date($collection_report),
        },
    );
}

sub bulky_refund_collection {
    my ($self, $collection_report) = @_;
    my $c = $self->{c};
    $c->send_email(
        'waste/bulky-refund-request.txt',
        {   to => [
                [ $c->cobrand->bulky_contact_email, $c->cobrand->council_name ]
            ],

            wasteworks_id => $collection_report->id,
            payment_amount => $collection_report->get_extra_field_value('payment'),
            refund_amount => $self->bulky_refund_amount($collection_report),
            payment_method =>
                $collection_report->get_extra_field_value('payment_method'),
            payment_code =>
                $collection_report->get_extra_field_value('PaymentCode'),
            auth_code =>
                $collection_report->get_extra_metadata('authCode'),
            continuous_audit_number =>
                $collection_report->get_extra_metadata('continuousAuditNumber'),
            payment_date       => $collection_report->created,
            scp_response       =>
                $collection_report->get_extra_metadata('scpReference'),
            detail  => $collection_report->detail,
            resident_name => $collection_report->name,
            resident_email => $collection_report->user->email,
        },
    );
}

sub bulky_refund_would_be_partial {
    my ($self, $collection) = @_;
    my $d = $self->collection_date($collection);
    my $t = $self->_bulky_cancellation_cutoff_date($d);
    return $t->subtract( days => 1 ) <= DateTime->now;
}

sub bulky_refund_amount {
    my ($self, $collection) = @_;
    my $charged = $collection->get_extra_field_value('payment');
    if ($self->bulky_refund_would_be_partial($collection)) {
        my $refund_amount = $charged - $self->bulky_minimum_charge;
        if ($refund_amount < 0) {
            return 0;
        }
        return $refund_amount;
    }
    return $charged;
}

sub bulky_cancel_no_payment_minutes {
    my $self = shift;
    $self->feature('waste_features')->{bulky_cancel_no_payment_minutes};
}

sub bulky_allowed_property {
    my ( $self, $property ) = @_;
    return $self->bulky_enabled;
}

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('Collection_Date'));
}

sub _bulky_refund_cutoff_date { }

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};
    my ($date, $ref, $expiry) = split(";", $data->{chosen_date});

    my $guid_key = $self->council_url . ":echo:bulky_event_guid:" . $c->stash->{property}->{id};
    $data->{extra_GUID} = $self->{c}->session->{$guid_key};
    $data->{extra_reservation} = $ref;

    $data->{title} = "Bulky goods collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Bulky collection";
    $data->{extra_Collection_Date} = $date;
    $data->{extra_Exact_Location} = $data->{location};
    $data->{extra_Notes} = $data->{location}; # We also want to pass this in to the Notes field

    my @items_list = @{ $self->bulky_items_master_list };
    my %items = map { $_->{name} => $_->{bartec_id} } @items_list;

    my @ids;
    my @item_names;
    my @item_quantity_codes;
    my @photos;

    if ($data->{location_photo}) {
        push @photos, $data->{location_photo};
    }

    my $cfg = $self->feature('waste_features');
    my $quantity_1_code = $cfg->{bulky_quantity_1_code};

    my $max = $self->bulky_items_maximum;
    for (1..$max) {
        if (my $item = $data->{"item_$_"}) {
            push @item_names, $item;
            push @ids, $items{$item};
            push @item_quantity_codes, $quantity_1_code;
            push @photos, $data->{"item_photo_$_"} || '';
        };
    }
    $data->{extra_Image} = join("::", @photos);
    $data->{extra_Bulky_Collection_Details_Item} = join("::", @ids);
    $data->{extra_Bulky_Collection_Details_Qty} = join("::", @item_quantity_codes);
    $data->{extra_Bulky_Collection_Details_Description} = join("::", @item_names);

    $self->bulky_total_cost($data);
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('Collection_Date'),
        "location" => $p->get_extra_field_value('Exact_Location'),
        "location_photo" => $p->get_extra_metadata("location_photo"),
    };

    my @fields = grep { /^item_\d/ } keys %{$p->get_extra_metadata};
    for my $id (1..@fields) {
        $saved_data->{"item_$id"} = $p->get_extra_metadata("item_$id");
        $saved_data->{"item_photo_$id"} = $p->get_extra_metadata("item_photo_$id");
    }

    $saved_data->{name} = $p->name;
    $saved_data->{email} = $p->user->email;
    $saved_data->{phone} = $p->phone_waste;

    return $saved_data;
}

sub bulky_per_item_pricing_property_types { ['Domestic', 'Trade'] }

sub bulky_contact_email {
    my $self = shift;
    return $self->feature('bulky_contact_email');
}

sub cancel_bulky_collections_without_payment {
    my ($self, $params) = @_;

    # Allow 30 minutes for payment before cancelling the booking.
    my $dtf = FixMyStreet::DB->schema->storage->datetime_parser;
    my $cutoff_date = $dtf->format_datetime( DateTime->now->subtract( minutes => $self->bulky_cancel_no_payment_minutes ) );

    my $rs = $self->problems->search(
        {   category => 'Bulky collection',
            created  => { '<'  => $cutoff_date },
            external_id => { '!=', undef },
            state => [ FixMyStreet::DB::Result::Problem->open_states ],
            -not => { extra => { '@>' => '{"contributed_as":"another_user"}' } },
            -or => [
                extra => undef,
                -not => { extra => { '\?' => 'payment_reference' } }
            ],
        },
    );

    while ( my $report = $rs->next ) {
        my $scp_reference = $report->get_extra_metadata('scpReference');
        if ($scp_reference) {

            # Double check whether the payment was made.
            my ($error, $auth_code, $can, $tx_id) = $self->cc_check_payment_status($scp_reference);
            if (!$error) {
                if ($params->{verbose}) {
                    printf(
                        'Booking %s for report %d was found to be paid (reference %s).' .
                        ' Updating with payment information and not cancelling.',
                        $report->external_id,
                        $report->id,
                        $tx_id,
                    );
                }
                if ($params->{commit}) {
                    $report->update_extra_metadata(
                        authCode => $auth_code,
                        continuousAuditNumber => $can,
                        payment_reference => $tx_id,
                    );
                    $report->set_extra_fields(
                        {
                            name => 'LastPayMethod',
                            description => 'LastPayMethod',
                            value => $self->bin_payment_types->{'csc'}
                        },
                        {
                            name => 'PaymentCode',
                            description => 'PaymentCode',
                            value => $tx_id
                        },
                    );
                    $report->update;
                    $report->add_to_comments({
                        text => "Payment confirmed, reference $tx_id",
                        user => $report->user,
                    });
                }
                next;
            }
        }

        if ($params->{commit}) {
            $report->add_to_comments({
                text => 'Booking cancelled since payment was not made in time',
                user_id => $self->body->comment_user_id,
                extra => { bulky_cancellation => 1 },
            });
            $report->state('closed');
            $report->detail(
                $report->detail . " | Cancelled since payment was not made in time"
            );
            $report->update;
        }
        if ($params->{verbose}) {
            printf(
                'Cancelled booking %s for report %d.',
                $report->external_id,
                $report->id,
            );
        }
    }
}

sub waste_auto_confirm_report {
    my ($self, $report) = @_;
    return $report->category eq 'Bulky collection';
}

1;
