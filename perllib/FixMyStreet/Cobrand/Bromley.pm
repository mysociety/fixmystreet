package FixMyStreet::Cobrand::Bromley;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use utf8;
use DateTime::Format::W3CDTF;
use DateTime::Format::Flexible;
use Try::Tiny;
use FixMyStreet::DateRange;

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

sub map_type {
    'Bromley';
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

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{always_send_latlong} = 0;
    $params->{send_notpinpointed} = 1;
    $params->{extended_description} = 0;
}

sub open311_extra_data {
    my ($self, $row, $h, $extra) = @_;

    my $title = $row->title;

    foreach (@$extra) {
        next unless $_->{value};
        $title .= ' | ID: ' . $_->{value} if $_->{name} eq 'feature_id';
        $title .= ' | PROW ID: ' . $_->{value} if $_->{name} eq 'prow_reference';
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

    # make sure we have last_name attribute present in row's extra, so
    # it is passed correctly to Bromley as attribute[]
    if (!$row->get_extra_field_value('last_name')) {
        my ( $firstname, $lastname ) = ( $row->name =~ /(\S+)\.?\s+(.+)/ );
        push @$open311_only, { name => 'last_name', value => $lastname };
    }
    if (!$row->get_extra_field_value('fms_extra_title') && $row->user->title) {
        push @$open311_only, { name => 'fms_extra_title', value => $row->user->title };
    }

    return ($open311_only, [ 'feature_id', 'prow_reference' ]);
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{endpoints} = {
        service_request_updates => 'update.xml',
        update => 'update.xml'
    };
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    my $extra = $row->extra || {};
    unless ( $extra->{title} ) {
        $extra->{title} = $row->user->title;
        $row->extra( $extra );
    }
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;
    delete $params->{update_id};
    $params->{public_anonymity_required} = $comment->anonymous ? 'TRUE' : 'FALSE',
    $params->{update_id_ext} = $comment->id;
    $params->{service_request_id_ext} = $comment->problem->id;
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
                category => ("&nbsp;" x 4) . $_->{name},
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
    if (!$where->{category}) {
        my $cats = $c->user->categories;
        my $subcats = $c->user->get_extra_metadata('subcategories') || [];
        $where->{category} = [ @$cats, @$subcats ] if @$cats || @$subcats;
    }

    my %subcats = $self->subcategories;
    my $subcat;
    my %chosen = map { $_ => 1 } @{$where->{category} || []};
    my @subcat = grep { $chosen{$_} } map { $_->{key} } map { @$_ } values %subcats;
    if (@subcat) {
        my %chosen = map { $_ => 1 } @subcat;
        $where->{'-or'} = {
            category => [ grep { !$chosen{$_} } @{$where->{category}} ],
            subcategory => \@subcat,
        };
        delete $where->{category};
    }
}

1;

