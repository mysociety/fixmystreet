package FixMyStreet::Cobrand::Bromley;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use utf8;
use DateTime::Format::W3CDTF;
use DateTime::Format::Flexible;
use File::Temp;
use Integrations::Echo;
use Integrations::Pay360;
use JSON::MaybeXS;
use Parallel::ForkManager;
use Sort::Key::Natural qw(natkeysort_inplace);
use Storable;
use Try::Tiny;
use FixMyStreet::DateRange;
use FixMyStreet::WorkingDays;
use Open311::GetServiceRequestUpdates;
use BromleyParks;

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

# This makes sure that the subcategory Open311 attribute question is
# also stored in the report's subcategory column. This could be done
# in process_open311_extras, but seemed easier to keep that separate
sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    # Make sure TfL reports are marked safety critical
    $self->SUPER::report_new_munge_before_insert($report);

    $report->subcategory($report->get_extra_field_value('service_sub_code'));
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

    return $self->next::method($s);
}

# Bromley pins always yellow
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if !$self->owns_problem( $p );
    return 'yellow';
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 3 if $num > 3 && $area eq 'alert';
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
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

    # A place where this can happen
    return unless $c->action eq 'dashboard/heatmap';

    # Bromley uses an extra attribute question to store 'subcategory',
    # rather than group/category, but wants this extra question to act
    # like a subcategory e.g. in the dashboard filter here.
    my %subcats = $self->subcategories;
    my $groups = $c->stash->{category_groups};
    foreach (@$groups) {
        my $filter = $_->{categories};
        my @new_contacts;
        foreach (@$filter) {
            push @new_contacts, $_;
            foreach (@{$subcats{$_->id}}) {
                push @new_contacts, {
                    category => $_->{key},
                    category_display => (" " x 4) . $_->{name},
                };
            }
        }
        $_->{categories} = \@new_contacts;
    }

    if (!%{$c->stash->{filter_category}}) {
        my $cats = $c->user->categories;
        my $subcats = $c->user->get_extra_metadata('subcategories') || [];
        $c->stash->{filter_category} = { map { $_ => 1 } @$cats, @$subcats } if @$cats || @$subcats;
    }
}

sub title_list {
    return ["MR", "MISS", "MRS", "MS", "DR"];
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};


    return unless $c->stash->{is_staff};

    if ( $c->user->has_permission_to('can_pay_with_csc', $self->body->id) ) {
        $c->stash->{staff_payments_allowed} = 1;
    }
}

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Waste}->{can_pay_with_csc} = "Can use CSC to pay for subscriptions";

    return $perms;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

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

    $self->{bromley_original_detail} = $row->detail;

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
        $extra->{title} = $row->user->title;
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
    $row->detail($self->{bromley_original_detail});
    my $error = $sender->error;
    if ($error =~ /Cannot renew this property, a new request is required/ && $row->title eq "Garden Subscription - Renew") {
        # Was created as a renewal, but due to DD delay has now expired. Switch to new subscription
        $row->title("Garden Subscription - New");
        $row->update_extra_field({ name => "Subscription_Type", value => $self->waste_subscription_types->{New} });
    }
    if ($error =~ /Missed Collection event already open for the property/) {
        $row->state('duplicate');
    }
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    $contact->set_extra_metadata( id_field => 'service_request_id_ext');

    my %server_set = (easting => 1, northing => 1, service_request_id_ext => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
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
    } if $service->{service_code} eq 'SLRS';

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

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $private_comments = $update->get_extra_metadata('private_comments');

    return $update->user->from_body && !$update->text && !$private_comments;
}

# If any subcategories ticked in user edit admin, make sure they're saved.
sub admin_user_edit_extra_data {
    my $self = shift;
    my $c = $self->{c};
    my $user = $c->stash->{user};

    return unless $c->get_param('submit') && $user && $user->from_body;

    $c->stash->{body} = $user->from_body;
    my %subcats = $self->subcategories;
    my @subcat_ids = map { $_->{key} } map { @$_ } values %subcats;
    my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @subcat_ids;
    $user->set_extra_metadata('subcategories', \@new_contact_ids);
}

# Returns a hash of contact ID => list of subcategories
# (which are stored as Open311 attribute questions)
sub subcategories {
    my $self = shift;

    my @c = $self->body->contacts->not_deleted->all;
    my %subcategories;
    foreach my $contact (@c) {
        my @fields = @{$contact->get_extra_fields};
        my ($field) = grep { $_->{code} eq 'service_sub_code' } @fields;
        $subcategories{$contact->id} = $field->{values} || [];
    }
    return %subcategories;
}

# Returns the list of categories, with Bromley subcategories added,
# for the user edit admin interface
sub add_admin_subcategories {
    my $self = shift;
    my $c = $self->{c};

    my $user = $c->stash->{user};
    return $c->stash->{contacts} unless $user; # e.g. admin templates, not user

    my @subcategories = @{$user->get_extra_metadata('subcategories') || []};
    my %active_contacts = map { $_ => 1 } @subcategories;

    my %subcats = $self->subcategories;
    my $contacts = $c->stash->{contacts};
    my @new_contacts;
    foreach (@$contacts) {
        push @new_contacts, $_;
        foreach (@{$subcats{$_->{id}}}) {
            push @new_contacts, {
                id => $_->{key},
                category => (" " x 4) . $_->{name}, # nbsp
                active => $active_contacts{$_->{key}},
            };
        }
    }
    return \@new_contacts;
}

# On heatmap page, include querying on subcategories
sub munge_load_and_group_problems {
    my ($self, $where, $filter) = @_;
    my $c = $self->{c};

    return unless $c->action eq 'dashboard/heatmap';

    # Bromley subcategory stuff
    if (!$where->{'me.category'}) {
        my $cats = $c->user->categories;
        my $subcats = $c->user->get_extra_metadata('subcategories') || [];
        $where->{'me.category'} = [ @$cats, @$subcats ] if @$cats || @$subcats;
    }

    my %subcats = $self->subcategories;
    my $subcat;
    my %chosen = map { $_ => 1 } @{$where->{'me.category'} || []};
    my @subcat = grep { $chosen{$_} } map { $_->{key} } map { @$_ } values %subcats;
    if (@subcat) {
        my %chosen = map { $_ => 1 } @subcat;
        $where->{'-or'} = {
            'me.category' => [ grep { !$chosen{$_} } @{$where->{'me.category'}} ],
            'me.subcategory' => \@subcat,
        };
        delete $where->{'me.category'};
    }
}

# We want to send confirmation emails only for Waste reports
sub report_sent_confirmation_email {
    my ($self, $report) = @_;
    my $contact = $report->contact or return;
    return 'id' if grep { $_ eq 'Waste' } @{$report->contact->groups};
    return '';
}

sub munge_around_category_where {
    my ($self, $where) = @_;
    $where->{extra} = [ undef, { -not_like => '%Waste%' } ];
}

sub munge_reports_category_list {
    my ($self, $categories) = @_;
    my $c = $self->{c};
    return if $c->action eq 'dashboard/heatmap';

    unless ( $c->user_exists && $c->user->from_body && $c->user->has_permission_to('report_mark_private', $self->body->id) ) {
        @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
    }
}

sub munge_report_new_contacts {
    my ($self, $categories) = @_;

    if ($self->{c}->action =~ /^waste/) {
        @$categories = grep { grep { $_ eq 'Waste' } @{$_->groups} } @$categories;
        return;
    }

    if ($self->{c}->stash->{categories_for_point}) {
        # Have come from an admin tool
    } else {
        @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
    }
    $self->SUPER::munge_report_new_contacts($categories);
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;

    # No updates on waste reports
    return 'waste' if $problem->cobrand_data eq 'waste';

    return $self->next::method(@_);
}

sub clear_cached_lookups_property {
    my ($self, $id) = @_;

    my $key = "bromley:echo:look_up_property:$id";
    delete $self->{c}->session->{$key};
    $key = "bromley:echo:bin_services_for_address:$id";
    delete $self->{c}->session->{$key};
}

sub bin_addresses_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $points = $echo->FindPoints($pc, $cfg);
    my $data = [ map { {
        value => $_->{Id},
        label => FixMyStreet::Template::title($_->{Description}),
    } } @$points ];
    natkeysort_inplace { $_->{label} } @$data;
    return $data;
}

sub look_up_property {
    my ($self, $id) = @_;

    my $calls = $self->call_api(
        "look_up_property:$id",
        GetPointAddress => [ $id ],
        GetServiceUnitsForObject => [ $id ],
        GetEventsForObject => [ 'PointAddress', $id ],
    );

    $self->{api_serviceunits} = $calls->{"GetServiceUnitsForObject $id"};
    $self->{api_events} = $calls->{"GetEventsForObject PointAddress $id"};
    my $result = $calls->{"GetPointAddress $id"};
    return {
        id => $result->{Id},
        uprn => $result->{SharedRef}{Value}{anyType},
        address => FixMyStreet::Template::title($result->{Description}),
        latitude => $result->{Coordinates}{GeoPoint}{Latitude},
        longitude => $result->{Coordinates}{GeoPoint}{Longitude},
    };
}

my %irregulars = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 11 => 'th', 12 => 'th', 13 => 'th');
sub ordinal {
    my $n = shift;
    $irregulars{$n % 100} || $irregulars{$n % 10} || 'th';
}

sub construct_bin_date {
    my $str = shift;
    return unless $str;
    my $offset = ($str->{OffsetMinutes} || 0) * 60;
    my $zone = DateTime::TimeZone->offset_as_string($offset);
    my $date = DateTime::Format::W3CDTF->parse_datetime($str->{DateTime});
    $date->set_time_zone($zone);
    return $date;
}

sub image_for_service {
    my ($self, $service_id) = @_;
    my $base = '/cobrands/bromley/images/container-images';
    my $images = {
        531 => "$base/refuse-black-sack",
        532 => "$base/refuse-black-sack",
        533 => "$base/large-communal-black",
        535 => "$base/kerbside-green-box-mix",
        536 => "$base/small-communal-mix",
        537 => "$base/kerbside-black-box-paper",
        541 => "$base/small-communal-paper",
        542 => "$base/food-green-caddy",
        544 => "$base/food-communal",
        545 => "$base/garden-waste-bin",
    };
    return $images->{$service_id};
}

sub available_bin_services_for_address {
    my ($self, $property) = @_;

    my $services = $self->{c}->stash->{services};
    return {} unless keys %$services;

    my $available_services = {};
    for my $service ( values %$services ) {
        my $name = $service->{service_name};
        $name =~ s/ /_/g;
        $available_services->{$name} = {
            service_id => $service->{service_id},
            is_active => 1,
        };
    }

    return $available_services;
}

sub garden_waste_service_id {
    return 545;
}

sub get_current_garden_bins {
    my ($self) = @_;

    my $service = $self->garden_waste_service_id;
    my $bin_count = $self->{c}->stash->{services}{$service}->{garden_bins};

    return $bin_count;
}

sub service_name_override {
    my $service = shift;

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

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
    };
}

sub waste_subscription_types {
    return {
        New => 1,
        Renew => 2,
        Amend => 3,
    };
}

sub waste_container_actions {
    return {
        deliver => 1,
        remove => 2
    };
}

sub waste_staff_source {
    my $self = shift;
    $self->_set_user_source;
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        1 => 'Green Box (Plastic)',
        3 => 'Wheeled Bin (Plastic)',
        12 => 'Black Box (Paper)',
        14 => 'Wheeled Bin (Paper)',
        9 => 'Kitchen Caddy',
        10 => 'Outside Food Waste Container',
        44 => 'Garden Waste Container',
        46 => 'Wheeled Bin (Food)',
    };

    $self->{c}->stash->{container_actions} = $self->waste_container_actions;

    my %service_to_containers = (
        535 => [ 1 ],
        536 => [ 3 ],
        537 => [ 12 ],
        541 => [ 14 ],
        542 => [ 9, 10 ],
        544 => [ 46 ],
        545 => [ 44 ],
    );
    my %request_allowed = map { $_ => 1 } keys %service_to_containers;
    my %quantity_max = (
        535 => 6,
        536 => 4,
        537 => 6,
        541 => 4,
        542 => 6,
        544 => 4,
        545 => 6,
    );

    $self->{c}->stash->{quantity_max} = \%quantity_max;

    $self->{c}->stash->{garden_subs} = $self->waste_subscription_types;

    my $result = $self->{api_serviceunits};
    return [] unless @$result;

    my $events = $self->{api_events};
    my $open = $self->_parse_open_events($events);
    $self->{c}->stash->{open_service_requests} = $open->{enquiry};

    # If there is an open Garden subscription (2106) event, assume
    # that means a bin is being delivered and so a pending subscription
    $self->{c}->stash->{pending_subscription} = $open->{enquiry}{2106} ? { title => 'Garden Subscription' } : undef;

    my @to_fetch;
    my %schedules;
    my @task_refs;
    my %expired;
    foreach (@$result) {
        my $servicetask = _get_current_service_task($_) or next;
        my $schedules = _parse_schedules($servicetask);
        $expired{$_->{Id}} = $schedules if $self->waste_sub_overdue( $schedules->{end_date}, weeks => 4 );

        next unless $schedules->{next} or $schedules->{last};
        $schedules{$_->{Id}} = $schedules;
        push @to_fetch, GetEventsForObject => [ ServiceUnit => $_->{Id} ];
        push @task_refs, $schedules->{last}{ref} if $schedules->{last};
    }
    push @to_fetch, GetTasks => \@task_refs if @task_refs;

    my $calls = $self->call_api('bin_services_for_address:' . $property->{id}, @to_fetch);

    my @out;
    my %task_ref_to_row;
    foreach (@$result) {
        my $service_name = service_name_override($_);
        next unless $schedules{$_->{Id}} || ( $service_name eq 'Garden Waste' && $expired{$_->{Id}} );

        my $schedules = $schedules{$_->{Id}} || $expired{$_->{Id}};
        my $servicetask = _get_current_service_task($_);

        my $events = $calls->{"GetEventsForObject ServiceUnit $_->{Id}"};
        my $open_unit = $self->_parse_open_events($events);

        my $containers = $service_to_containers{$_->{ServiceId}};
        my ($open_request) = grep { $_ } map { $open->{request}->{$_} } @$containers;

        my $request_max = $quantity_max{$_->{ServiceId}};

        my $garden = 0;
        my $garden_bins;
        my $garden_cost = 0;
        my $garden_due = $self->waste_sub_due($schedules->{end_date});
        my $garden_overdue = $expired{$_->{Id}};
        if ($service_name eq 'Garden Waste') {
            $garden = 1;
            my $data = Integrations::Echo::force_arrayref($servicetask->{Data}, 'ExtensibleDatum');
            foreach (@$data) {
                next unless $_->{DatatypeName} eq 'LBB - GW Container'; # DatatypeId 5093
                my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
                foreach (@$moredata) {
                    # $container = $_->{Value} if $_->{DatatypeName} eq 'Container'; # should be 44
                    if ( $_->{DatatypeName} eq 'Quantity' ) {
                        $garden_bins = $_->{Value};
                        $garden_cost = $self->garden_waste_cost($garden_bins) / 100;
                    }
                }
            }
            $request_max = $garden_bins;

            if ($self->{c}->stash->{waste_features}->{garden_disabled}) {
                $garden = 0;
            }
        }

        my $row = {
            id => $_->{Id},
            service_id => $_->{ServiceId},
            service_name => $service_name,
            garden_waste => $garden,
            garden_bins => $garden_bins,
            garden_cost => $garden_cost,
            garden_due => $garden_due,
            garden_overdue => $garden_overdue,
            report_open => $open->{missed}->{$_->{ServiceId}} || $open_unit->{missed}->{$_->{ServiceId}},
            request_allowed => $request_allowed{$_->{ServiceId}} && $request_max && $schedules->{next},
            request_open => $open_request,
            request_containers => $containers,
            request_max => $request_max,
            service_task_id => $servicetask->{Id},
            service_task_name => $servicetask->{TaskTypeName},
            service_task_type_id => $servicetask->{TaskTypeId},
            schedule => $schedules->{description},
            last => $schedules->{last},
            next => $schedules->{next},
            end_date => $schedules->{end_date},
        };
        if ($row->{last}) {
            my $ref = join(',', @{$row->{last}{ref}});
            $task_ref_to_row{$ref} = $row;
        }
        push @out, $row;
    }
    if (%task_ref_to_row) {
        my $tasks = $calls->{GetTasks};
        my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
        foreach (@$tasks) {
            my $ref = join(',', @{$_->{Ref}{Value}{anyType}});
            my $completed = construct_bin_date($_->{CompletedDate});
            my $state = $_->{State}{Name} || '';
            my $task_type_id = $_->{TaskTypeId} || '';

            my $orig_resolution = $_->{Resolution}{Name} || '';
            my $resolution = $orig_resolution;
            my $resolution_id = $_->{Resolution}{Ref}{Value}{anyType};
            if ($resolution_id) {
                my $template = FixMyStreet::DB->resultset('ResponseTemplate')->search({
                    'me.body_id' => $self->body->id,
                    'me.external_status_code' => [
                        "$resolution_id,$task_type_id,$state",
                        "$resolution_id,$task_type_id,",
                        "$resolution_id,,$state",
                        "$resolution_id,,",
                        $resolution_id,
                    ],
                })->first;
                $resolution = $template->text if $template;
            }

            my $row = $task_ref_to_row{$ref};
            $row->{last}{state} = $state unless $state eq 'Completed' || $state eq 'Not Completed' || $state eq 'Outstanding' || $state eq 'Allocated';
            $row->{last}{completed} = $completed;
            $row->{last}{resolution} = $resolution;
            $row->{report_allowed} = within_working_days($row->{last}{date}, 2);

            # Special handling if last instance is today
            if ($row->{last}{date}->ymd eq $now->ymd) {
                # If it's before 5pm and outstanding, show it as in progress
                if ($state eq 'Outstanding' && $now->hour < 17) {
                    $row->{next} = $row->{last};
                    $row->{next}{state} = 'In progress';
                    delete $row->{last};
                }
                if (!$completed && $now->hour < 17) {
                    $row->{report_allowed} = 0;
                }
            }

            # If the task is ended and could not be done, do not allow reporting
            if ($state eq 'Not Completed' || ($state eq 'Completed' && $orig_resolution eq 'Excess Waste')) {
                $row->{report_allowed} = 0;
                $row->{report_locked_out} = 1;
            }
        }
    }

    return \@out;
}

sub _get_current_service_task {
    my $service = shift;

    my $servicetasks = Integrations::Echo::force_arrayref($service->{ServiceTasks}, 'ServiceTask');
    @$servicetasks = grep { $_->{ServiceTaskSchedules} } @$servicetasks;
    return unless @$servicetasks;

    my $service_name = service_name_override($service);
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my ($current, $last_date);
    foreach my $task ( @$servicetasks ) {
        my $schedules = Integrations::Echo::force_arrayref($task->{ServiceTaskSchedules}, 'ServiceTaskSchedule');
        foreach my $schedule ( @$schedules ) {
            my $end = construct_bin_date($schedule->{EndDate});

            next if $last_date && $end && $end < $last_date;
            next if $end && $end < $today && $service_name ne 'Garden Waste';
            $last_date = $end;
            $current = $task;
        }
    }
    return $current;
}

sub _parse_open_events {
    my $self = shift;
    my $events = shift;
    my $open;
    foreach (@$events) {
        next if $_->{ResolvedDate};
        next if $_->{ResolutionCodeId} && $_->{ResolutionCodeId} != 584; # Out of Stock
        my $event_type = $_->{EventTypeId};
        my $service_id = $_->{ServiceId};
        if ($event_type == 2104) { # Request
            my $data = $_->{Data} ? $_->{Data}{ExtensibleDatum} : [];
            my $container;
            DATA: foreach (@$data) {
                if ($_->{ChildData}) {
                    foreach (@{$_->{ChildData}{ExtensibleDatum}}) {
                        if ($_->{DatatypeName} eq 'Container Type') {
                            $container = $_->{Value};
                            last DATA;
                        }
                    }
                }
            }
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            $open->{request}->{$container} = $report ? { report => $report } : 1;
        } elsif (2095 <= $event_type && $event_type <= 2103) { # Missed collection
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            $open->{missed}->{$service_id} = $report ? { report => $report } : 1;
        } else { # General enquiry of some sort
            $open->{enquiry}->{$event_type} = 1;
        }
    }
    return $open;
}

sub _schedule_object {
    my ($instance, $current) = @_;
    my $original = construct_bin_date($instance->{OriginalScheduledDate});
    my $changed = $current->strftime("%F") ne $original->strftime("%F");
    return {
        date => $current,
        ordinal => ordinal($current->day),
        changed => $changed,
        ref => $instance->{Ref}{Value}{anyType},
    };
}

sub _parse_schedules {
    my $servicetask = shift;
    my $schedules = Integrations::Echo::force_arrayref($servicetask->{ServiceTaskSchedules}, 'ServiceTaskSchedule');

    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->strftime("%F");
    my ($min_next, $max_last, $description, $max_end_date);
    foreach my $schedule (@$schedules) {
        my $start_date = construct_bin_date($schedule->{StartDate})->strftime("%F");
        my $end_date = construct_bin_date($schedule->{EndDate})->strftime("%F");
        $max_end_date = $end_date if !defined($max_end_date) || $max_end_date lt $end_date;

        next if $end_date lt $today;

        my $next = $schedule->{NextInstance};
        my $d = construct_bin_date($next->{CurrentScheduledDate});
        $d = undef if $d && $d->strftime('%F') lt $start_date; # Shouldn't happen
        if ($d && (!$min_next || $d < $min_next->{date})) {
            $min_next = _schedule_object($next, $d);
            $description = $schedule->{ScheduleDescription};
        }

        next if $start_date gt $today; # Shouldn't have a LastInstance in this case, but some bad data

        my $last = $schedule->{LastInstance};
        $d = construct_bin_date($last->{CurrentScheduledDate});
        # It is possible the last instance for this schedule has been rescheduled to
        # be in the future. If so, we should treat it like it is a next instance.
        if ($d && $d->strftime("%F") gt $today && (!$min_next || $d < $min_next->{date})) {
            $min_next = _schedule_object($last, $d);
            $description = $schedule->{ScheduleDescription};
        } elsif ($d && (!$max_last || $d > $max_last->{date})) {
            $max_last = _schedule_object($last, $d);
        }
    }

    return {
        next => $min_next,
        last => $max_last,
        description => $description,
        end_date => $max_end_date,
    };
}

sub bin_day_format { '%A, %-d~~~ %B' }

sub bin_future_collections {
    my $self = shift;

    my $services = $self->{c}->stash->{service_data};
    my @tasks;
    my %names;
    foreach (@$services) {
        push @tasks, $_->{service_task_id};
        $names{$_->{service_task_id}} = $_->{service_name};
    }

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);
    my $result = $echo->GetServiceTaskInstances(@tasks);

    my $events = [];
    foreach (@$result) {
        my $task_id = $_->{ServiceTaskRef}{Value}{anyType};
        my $tasks = Integrations::Echo::force_arrayref($_->{Instances}, 'ScheduledTaskInfo');
        foreach (@$tasks) {
            my $dt = construct_bin_date($_->{CurrentScheduledDate});
            my $summary = $names{$task_id} . ' collection';
            my $desc = '';
            push @$events, { date => $dt, summary => $summary, desc => $desc };
        }
    }
    return $events;
}

=over

=item within_working_days

Given a DateTime object and a number, return true if today is less than or
equal to that number of working days (excluding weekends and bank holidays)
after the date.

=cut

sub within_working_days {
    my ($dt, $days, $future) = @_;
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, $days)->ymd;
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    if ( $future ) {
        return $today ge $dt;
    } else {
        return $today le $dt;
    }
}

=item waste_fetch_events

Loop through all open waste events to see if there have been any updates

=back

=cut

sub waste_fetch_events {
    my ($self, $verbose) = @_;

    my $body = $self->body;
    my @contacts = $body->contacts->search({
        send_method => 'Open311',
        endpoint => { '!=', '' },
    })->all;
    die "Could not find any devolved contacts\n" unless @contacts;

    my %open311_conf = (
        endpoint => $contacts[0]->endpoint || '',
        api_key => $contacts[0]->api_key || '',
        jurisdiction => $contacts[0]->jurisdiction || '',
        extended_statuses => $body->send_extended_statuses,
    );
    my $cobrand = $body->get_cobrand_handler;
    $cobrand->call_hook(open311_config_updates => \%open311_conf)
        if $cobrand;
    my $open311 = Open311->new(%open311_conf);

    my $updates = Open311::GetServiceRequestUpdates->new(
        current_open311 => $open311,
        current_body => $body,
        system_user => $body->comment_user,
        suppress_alerts => 0,
        blank_updates_permitted => $body->blank_updates_permitted,
    );

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);

    my $cfg = {
        verbose => $verbose,
        updates => $updates,
        echo => $echo,
        event_types => {},
    };

    my $reports = $self->problems->search({
        external_id => { '!=', '' },
        state => [ FixMyStreet::DB::Result::Problem->open_states() ],
        category => [ map { $_->category } @contacts ],
    });

    while (my $report = $reports->next) {
        print 'Fetching data for report ' . $report->id . "\n" if $verbose;

        my $event = $cfg->{echo}->GetEvent($report->external_id);
        my $request = $self->construct_waste_open311_update($cfg, $event) or next;

        next if !$request->{status} || $request->{status} eq 'confirmed'; # Still in initial state
        next unless $self->waste_check_last_update(
            $cfg, $report, $request->{status}, $request->{external_status_code});

        my $last_updated = construct_bin_date($event->{LastUpdatedDate});
        $request->{comment_time} = $last_updated;

        print "  Updating report to state $request->{status}, $request->{description} ($request->{external_status_code})\n" if $cfg->{verbose};
        $cfg->{updates}->process_update($request, $report);
    }
}

sub construct_waste_open311_update {
    my ($self, $cfg, $event) = @_;

    return undef unless $event;
    my $event_type = $cfg->{event_types}{$event->{EventTypeId}} ||= $self->waste_get_event_type($cfg, $event->{EventTypeId});
    my $state_id = $event->{EventStateId};
    my $resolution_id = $event->{ResolutionCodeId} || '';
    my $status = $event_type->{states}{$state_id}{state};
    my $description = $event_type->{resolution}{$resolution_id} || $event_type->{states}{$state_id}{name};
    return {
        description => $description,
        status => $status,
        update_id => 'waste',
        external_status_code => $resolution_id ? "$resolution_id,," : "",
        prefer_template => 1,
    };
}

sub waste_get_event_type {
    my ($self, $cfg, $id) = @_;

    my $event_type = $cfg->{echo}->GetEventType($id);

    my $state_map = {
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

    my $states = $event_type->{Workflow}->{States}->{State};
    my $data;
    foreach (@$states) {
        my $core = $_->{CoreState}; # New/Pending/Closed
        my $name = $_->{Name}; # New : Unallocated/Allocated to Crew : Completed/Not Completed/Rejected/Closed
        $data->{states}{$_->{Id}} = {
            core => $core,
            name => $name,
            state => $state_map->{$core}{$name},
        };
        my $codes = Integrations::Echo::force_arrayref($_->{ResolutionCodes}, 'StateResolutionCode');
        foreach (@$codes) {
            my $name = $_->{Name};
            my $id = $_->{ResolutionCodeId};
            $data->{resolution}{$id} = $name;
        }
    }
    return $data;
}

# We only have the report's current state, no history, so must check current
# against latest received update to see if state the same, and skip if so
sub waste_check_last_update {
    my ($self, $cfg, $report, $status, $resolution_id) = @_;

    my $latest = $report->comments->search(
        { external_id => 'waste', },
        { order_by => { -desc => 'id' } }
    )->first;

    if ($latest) {
        my $state = $cfg->{updates}->current_open311->map_state($status);
        my $code = $latest->get_extra_metadata('external_status_code') || '';
        if ($latest->problem_state eq $state && $code eq $resolution_id) {
            print "  Latest update matches fetched state, skipping\n" if $cfg->{verbose};
            return;
        }
    }
    return 1;
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
    foreach (grep { /^extra_/ } keys %$data) {
        $detail .= "$data->{$_}\n\n";
    }
    $detail .= $address;
    $data->{detail} = $detail;
    $self->_set_user_source;
}
sub waste_get_next_dd_day {
    my $self = shift;

    my $dd_delay = 10; # No days to set up a DD

    my $dt = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());

    my $next_day = $wd->add_days( $dt, $dd_delay );

    return $next_day;
}

sub waste_get_pro_rata_cost {
    my ($self, $bins, $end) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($end);
    my $cost = $bins * $self->{c}->cobrand->waste_get_pro_rata_bin_cost( $sub_end, $now );

    return $cost;
}

sub waste_get_pro_rata_bin_cost {
    my ($self, $end, $start) = @_;

    my $weeks = $end->delta_days($start)->in_units('weeks');
    $weeks -= 1 if $weeks > 0;

    my $base = $self->feature('payment_gateway')->{pro_rata_minimum};
    my $weekly_cost = $self->feature('payment_gateway')->{pro_rata_weekly};

    my $cost = $base + ( $weeks * $weekly_cost );

    return $cost;
}

sub waste_sub_due {
    my ($self, $date) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date);

    my $diff = $now->delta_days($sub_end)->in_units('weeks');
    return $diff < 7;
}

sub waste_sub_overdue {
    my ($self, $date, $interval, $count) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->truncate( to => 'day' );
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date)->truncate( to => 'day' );

    if ( $now > $sub_end ) {
        my $diff = 1;
        if ( $interval ) {
            $diff = $now->delta_days($sub_end)->in_units($interval) < $count;
        }
        return $diff;
    };

    return 0;
}

sub waste_display_payment_method {
    my ($self, $method) = @_;

    my $display = {
        direct_debit => _('Direct Debit'),
        credit_card => _('Credit Card'),
    };

    return $display->{$method};
}

sub garden_waste_cost {
    my ($self, $bin_count) = @_;

    $bin_count ||= 1;

    return $self->feature('payment_gateway')->{ggw_cost} * $bin_count;
}

sub waste_payment_type {
    my ($self, $type, $ref) = @_;

    my ($sub_type, $category);
    if ( $type eq 'Payment: 01' || $type eq 'First Time' ) {
        $category = 'Garden Subscription';
        $sub_type = $self->waste_subscription_types->{New};
    } elsif ( $type eq 'Payment: 17' || $type eq 'Regular' ) {
        $category = 'Garden Subscription';
        if ( $ref ) {
            $sub_type = $self->waste_subscription_types->{Amend};
        } else {
            $sub_type = $self->waste_subscription_types->{Renew};
        }
    }

    return ($category, $sub_type);
}

sub waste_is_dd_payment {
    my ($self, $row) = @_;

    return $row->get_extra_field_value('payment_method') && $row->get_extra_field_value('payment_method') eq 'direct_debit';
}

sub waste_dd_paid {
    my ($self, $date) = @_;

    my ($day, $month, $year) = ( $date =~ m#^(\d+)/(\d+)/(\d+)$#);
    my $dt = DateTime->new(day => $day, month => $month, year => $year);
    return within_working_days($dt, 3, 1);
}

sub waste_reconcile_direct_debits {
    my $self = shift;

    my $today = DateTime->now;
    my $start = $today->clone->add( days => -14 );

    my $config = $self->feature('payment_gateway');
    my $i = Integrations::Pay360->new({
        config => $config
    });

    my $recent = $i->get_recent_payments({
        start => $start,
        end => $today
    });

    RECORD: for my $payment ( @$recent ) {

        my $date = $payment->{DueDate};
        next unless $self->waste_dd_paid($date);

        my ($category, $type) = $self->waste_payment_type ( $payment->{Type}, $payment->{YourRef} );

        next unless $category && $date;

        my $payer = $payment->{PayerReference};

        (my $uprn = $payer) =~ s/^GGW//;

        my $len = length($uprn);
        my $rs = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I' . $len . ':'. $uprn . '%' },
        },
        {
                order_by => { -desc => 'created' }
        })->to_body( $self->body );

        my $handled;

        # Work out what to do with the payment.
        # Processed payments are indicated by a matching record with a dd_date the
        # same as the CollectionDate of the payment
        #
        # Renewal is an automatic event so there is never a record in the database
        # and we have to generate one.
        #
        # If we're a renew payment then find the initial subscription payment, also
        # checking if we've already processed this payment. If we've not processed it
        # create a renewal record using the original subscription as a basis.
        if ( $type && $type eq $self->waste_subscription_types->{Renew} ) {
            next unless $payment->{Status} eq 'Paid';
            $rs = $rs->search({ category => 'Garden Subscription' });
            my $p;
            # loop over all matching records and pick the most recent new sub or renewal
            # record. This is where we get the details of the renewal from. There should
            # always be one of these for an automatic DD renewal. If there isn't then
            # something has gone wrong and we need to error.
            while ( my $cur = $rs->next ) {
                # only match direct debit payments
                next unless $self->waste_is_dd_payment($cur);
                # only confirmed records are valid.
                next unless FixMyStreet::DB::Result::Problem->visible_states()->{$cur->state};
                my $sub_type = $cur->get_extra_field_value('Subscription_Type');
                if ( $sub_type eq $self->waste_subscription_types->{New} ) {
                    $p = $cur if !$p;
                } elsif ( $sub_type eq $self->waste_subscription_types->{Renew} ) {
                    # already processed
                    next RECORD if $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date;
                    # if it's a renewal of a DD where the initial setup was as a renewal
                    $p = $cur if !$p;
                }
            }
            if ( $p ) {
                my $service = $self->waste_get_current_garden_sub( $p->get_extra_field_value('property_id') );
                unless ($service) {
                    warn "no matching service to renew for $payer\n";
                    next;
                }
                my $renew = _duplicate_waste_report($p, 'Garden Subscription', {
                    Subscription_Type => $self->waste_subscription_types->{Renew},
                    service_id => 545,
                    uprn => $uprn,
                    Subscription_Details_Container_Type => 44,
                    Subscription_Details_Quantity => $self->waste_get_sub_quantity($service),
                    LastPayMethod => $self->bin_payment_types->{direct_debit},
                    PaymentCode => $payer,
                } );
                $renew->set_extra_metadata('dd_date', $date);
                $renew->confirm;
                $renew->insert;
                $handled = 1;
            }
        # this covers new subscriptions and ad-hoc payments, both of which already have
        # a record in the database as they are the result of user action
        } else {
            next unless $payment->{Status} eq 'Paid';
            # we fetch the confirmed ones as well as we explicitly want to check for
            # processed reports so we can warn on those we are missing.
            $rs = $rs->search({ category => 'Garden Subscription' });
            while ( my $cur = $rs->next ) {
                next unless $self->waste_is_dd_payment($cur);
                if ( my $type = $self->_report_matches_payment( $cur, $payment ) ) {
                    if ( $cur->state eq 'unconfirmed' && !$handled) {
                        if ( $type eq 'New' ) {
                            if ( !$cur->get_extra_metadata('payerReference') ) {
                                $cur->set_extra_metadata('payerReference', $payer);
                            }
                        }
                        $cur->set_extra_metadata('dd_date', $date);
                        $cur->update_extra_field( {
                            name => 'PaymentCode',
                            description => 'PaymentCode',
                            value => $payer,
                        } );
                        $cur->update_extra_field( {
                            name => 'LastPayMethod',
                            description => 'LastPayMethod',
                            value => $self->bin_payment_types->{direct_debit},
                        } );
                        $cur->confirm;
                        $cur->update;
                        $handled = 1;
                    } elsif ( $cur->state eq 'unconfirmed' ) {
                        # if we've pulled out more that one record, e.g. because they
                        # failed to make a payment then skip remaining ones.
                        $cur->state('hidden');
                        $cur->update;
                    } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date)  {
                        next RECORD;
                    }
                }
            }
        }

        unless ( $handled ) {
            warn "no matching record found for $category payment with id $payer\n";
        }
    }

    # There's two options with a cancel payment. If the user has cancelled it outside of
    # WasteWorks then we need to find the original sub and generate a new cancel subscription
    # report.
    #
    # If it's been cancelled inside WasteWorks then we'll have an unconfirmed cancel report
    # which we need to confirm.

    my $cancelled = $i->get_cancelled_payers({
        start => $start,
        end => $today
    });

    if ( ref $cancelled eq 'HASH' && $cancelled->{error} ) {
        if ( $cancelled->{error} ne 'No cancelled payers found.' ) {
            warn $cancelled->{error} . "\n";
        }
        return;
    }

    CANCELLED: for my $payment ( @$cancelled ) {

        my $date = $payment->{CancelledDate};
        next unless $date;

        my $payer = $payment->{Reference};
        (my $uprn = $payer) =~ s/^GGW//;
        my $len = length($uprn);
        my $rs = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I' . $len . ':'. $uprn . '%' },
        }, {
            order_by => { -desc => 'created' }
        })->to_body( $self->body );

        $rs = $rs->search({ category => 'Cancel Garden Subscription' });
        my $r;
        while ( my $cur = $rs->next ) {
            if ( $cur->state eq 'unconfirmed' ) {
                $r = $cur;
            # already processed
            } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date) {
                next CANCELLED;
            }
        }

        if ( $r ) {
            my $service = $self->waste_get_current_garden_sub( $r->get_extra_field_value('property_id') );
            # if there's not a service then it's fine as it's already been cancelled
            if ( $service ) {
                $r->set_extra_metadata('dd_date', $date);
                $r->confirm;
                $r->update;
            # there's no service but we don't want to be processing the report all the time.
            } else {
                $r->state('hidden');
                $r->update;
            }
        } else {
            # We don't do anything with DD cancellations that don't have
            # associated Cancel reports, so no need to warn on them
            # warn "no matching record found for Cancel payment with id $payer\n";
        }
    }
}

sub _report_matches_payment {
    my ($self, $r, $p) = @_;

    my $match = 0;
    if ( $p->{YourRef} && $r->id eq $p->{YourRef} ) {
        $match = 'Ad-Hoc';
    } elsif ( !$p->{YourRef}
            && ( $r->get_extra_field_value('Subscription_Type') eq $self->waste_subscription_types->{New} ||
                 # if we're renewing a previously non DD sub
                 $r->get_extra_field_value('Subscription_Type') eq $self->waste_subscription_types->{Renew} )
    ) {
        $match = 'New';
    }

    return $match;
}

sub _duplicate_waste_report {
    my ( $report, $category, $extra ) = @_;
    my $new = FixMyStreet::DB->resultset('Problem')->new({
        category => $category,
        user => $report->user,
        latitude => $report->latitude,
        longitude => $report->longitude,
        cobrand => $report->cobrand,
        bodies_str => $report->bodies_str,
        title => $report->title,
        detail => $report->detail,
        postcode => $report->postcode,
        used_map => $report->used_map,
        name => $report->user->name || $report->name,
        areas => $report->areas,
        anonymous => $report->anonymous,
        state => 'unconfirmed',
        non_public => 1,
    });

    my @extra = map { { name => $_, value => $extra->{$_} } } keys %$extra;
    $new->set_extra_fields(@extra);

    return $new;
}

sub waste_get_current_garden_sub {
    my ( $self, $id ) = @_;

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);
    my $services = $echo->GetServiceUnitsForObject( $id );
    return undef unless $services;

    my $garden;
    for my $service ( @$services ) {
        if ( $service->{ServiceId} == $self->garden_waste_service_id ) {
            $garden = _get_current_service_task($service);
            last;
        }
    }

    return $garden;
}

sub waste_get_sub_quantity {
    my ($self, $service) = @_;

    my $quantity = 0;
    my $tasks = Integrations::Echo::force_arrayref($service->{Data}, 'ExtensibleDatum');
    return 0 unless scalar @$tasks;
    for my $data ( @$tasks ) {
        next unless $data->{DatatypeName} eq 'LBB - GW Container';
        next unless $data->{ChildData};
        my $kids = $data->{ChildData}->{ExtensibleDatum};
        $kids = [ $kids ] if ref $kids eq 'HASH';
        for my $child ( @$kids ) {
            next unless $child->{DatatypeName} eq 'Quantity';
            $quantity = $child->{Value}
        }
    }

    return $quantity;
}

sub admin_templates_external_status_code_hook {
    my ($self) = @_;
    my $c = $self->{c};

    my $res_code = $c->get_param('resolution_code') || '';
    my $task_type = $c->get_param('task_type') || '';
    my $task_state = $c->get_param('task_state') || '';

    my $code = "$res_code,$task_type,$task_state";
    $code = '' if $code eq ',,';
    return $code;
}

sub call_api {
    my ($self, $key) = (shift, shift);

    $key = "bromley:echo:$key";
    return $self->{c}->session->{$key} if !FixMyStreet->test_mode && $self->{c}->session->{$key};

    my $tmp = File::Temp->new;
    my @cmd = (
        FixMyStreet->path_to('bin/fixmystreet.com/bromley-echo'),
        '--out', $tmp,
        '--calls', encode_json(\@_),
    );
    my $start = time();

    # We cannot fork directly under mod_fcgid, so
    # call an external script that calls back in.
    my $data;
    my $echo = $self->feature('echo');
    # uncoverable branch false
    if (FixMyStreet->test_mode || $echo->{sample_data}) {
        $data = $self->_parallel_api_calls(@_);
    } else {
        # uncoverable statement
        system(@cmd);
        $data = Storable::fd_retrieve($tmp);
    }
    $self->{c}->session->{$key} = $data;
    my $time = time() - $start;
    $self->{c}->log->info("[Bromley] call_api $key took $time seconds");
    return $data;
}

sub _parallel_api_calls {
    my $self = shift;
    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);

    my %calls;
    # uncoverable branch false
    my $pm = Parallel::ForkManager->new(FixMyStreet->test_mode || $echo->sample_data ? 0 : 10);
    $pm->run_on_finish(sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
        %calls = ( %calls, %$data );
    });

    while (@_) {
        my $call = shift;
        my $args = shift;
        $pm->start and next;
        my $result = $echo->$call(@$args);
        my $key = "$call @$args";
        $key = $call if $call eq 'GetTasks';
        $pm->finish(0, { $key => $result });
    }
    $pm->wait_all_children;

    return \%calls;
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        staff_role => 'Staff Role',
    );

    my $user_lookup = $self->csv_staff_users;

    my $userroles = FixMyStreet::DB->resultset("UserRole")->search({
        user_id => [ keys %$user_lookup ],
    }, {
        prefetch => 'role'
    });
    my %userroles;
    while (my $userrole = $userroles->next) {
        my $user_id = $userrole->user_id;
        my $role = $userrole->role->name;
        push @{$userroles{$user_id}}, $role;
    }

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $by = $report->get_extra_metadata('contributed_by');
        my $staff_user = '';
        my $staff_role = '';
        if ($by) {
            $staff_user = $self->csv_staff_user_lookup($by, $user_lookup);
            $staff_role = join(',', @{$userroles{$by} || []});
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

1;
