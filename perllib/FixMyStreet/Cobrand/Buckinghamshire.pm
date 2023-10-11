=head1 NAME

FixMyStreet::Cobrand::Buckinghamshire - code specific to the Buckinghamshire cobrand

=head1 SYNOPSIS

We integrate with Buckinghamshire's Alloy back end for highways reporting and
Evo for red claims, also send emails for some categories, and send
reports to Buckinghamshire parishes based on category/speed limit.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Buckinghamshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use JSON::MaybeXS;
use Path::Tiny;
use Moo;
with 'FixMyStreet::Roles::Open311Alloy';
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::BoroughEmails';
use SUPER;


use LWP::Simple;
use URI;
use Try::Tiny;
use Utils;

sub council_area_id { return 163793; }
sub council_area { return 'Buckinghamshire'; }
sub council_name { return 'Buckinghamshire Council'; }
sub council_url { return 'buckinghamshire'; }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Buckinghamshire';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.7852948471218,-0.812140044990842',
        span   => '0.596065946222112,0.664092167105497',
        bounds => [ 51.4854160129405, -1.1406945585036, 52.0814819591626, -0.476602391398098 ],
    };
}

sub geocoder_munge_results {
    my ($self, $result) = @_;

    if ($result->{display_name} =~ /Stoke Road, Stoke Poges/) {
        # Tweak the location of this one particular result to be on the correct
        # side of the Slough/Bucks boundary
        $result->{lat} = "51.523";
    }
}

sub new_report_title_field_label {
    "Summarise the problem"
}

sub new_report_title_field_hint {
    "Exact location, including any landmarks"
}

sub new_report_detail_field_hint {
    "Dimensions, landmarks, direction of travel etc."
}

sub on_map_default_status { ('open', 'fixed') }

sub around_nearby_filter {
    my ($self, $params) = @_;
    $params->{states}->{'internal referral'} = 1;
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->is_closed || ($context ne 'reports' && !$self->owns_problem($p));
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons {
    return '/cobrands/oxfordshire/images/';
}

sub admin_user_domain { ( 'buckscc.gov.uk', 'buckinghamshire.gov.uk' ) }

sub admin_pages {
    my $self = shift;
    my $pages = $self->next::method();
    $pages->{triage} = [ undef, undef ];
    return $pages;
}

=item admin_templates_state_and_external_status_code

We can set response templates with both state and external status code,
for updating reports by email.

=cut

sub admin_templates_state_and_external_status_code { 1 }

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Problems}->{triage} = "Triage reports";

    return $perms;
}

=head2 permission_body_override

If a parish body ID is provided, return our body ID instead.
This is so Bucks staff users have permissions on parish reports.

=cut

sub permission_body_override {
    my ($self, $body_ids) = @_;

    my %parish_ids = map { $_->id => 1 } $self->parish_bodies->all;
    my @out = map { $parish_ids{$_} ? $self->body->id : $_ } @$body_ids;

    return \@out;
}

# Assume that any category change means the report should be resent
sub category_change_force_resend { 1 }

sub send_questionnaires {
    return 0;
}

sub open311_extra_data_exclude { [ 'road-placement' ] }


=head2 open311_extra_data_include

All reports sent to Alloy should have a parent asset they're associated with.
This is indicated by the value in the asset_resource_id field. For certain
categories (e.g. street lights, grit bins) this will be the asset the user
selected from the map. For other categories (e.g. potholes) or if the user
didn't select an asset then we look up the nearest road from Buckinghamshire's
Alloy server and use that as the parent.

=cut

around open311_extra_data_include => sub {
    my ($orig, $self) = (shift, shift);
    my $open311_only = $self->$orig(@_);

    my ($row, $h, $contact) = @_;

    # If the report doesn't already have an asset, associate it with the
    # closest feature from the Alloy highways network layer.
    # This may happen because the report was made on the app, without JS,
    # using a screenreader, etc.
    if (!$row->get_extra_field_value('asset_resource_id')) {
        if (my $item_id = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'asset_resource_id', value => $item_id });
        }
    }

    return $open311_only;
};

=head2 open311_pre_send

We do not actually want to send claim reports via Open311, though there is a
backend category for them, only email and Evo by a separate process

=cut

sub open311_pre_send {
    my ($self, $row, $open311) = @_;
    return 'SKIP' if $row->category eq 'Claim';
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    $self->_add_claim_auto_response($row, $h) if $row->category eq 'Claim';

    # Check Open311 was successful;
    return unless $row->external_id;
    return if $row->get_extra_metadata('extra_email_sent');

    # For certain categories, send an email also
    my $emails = $self->feature('open311_email');
    my $addresses = {
        'Flytipping' => [ email_list($emails->{flytipping}, "TfB") ],
        'Blocked drain' => [ email_list($emails->{flood}, "Flood Management") ],
        'Ditch issue' => [ email_list($emails->{flood}, "Flood Management") ],
        'Flooded subway' => [ email_list($emails->{flood}, "Flood Management") ],
    };
    my $dest = $addresses->{$row->category};
    return unless $dest;

    my $sender = FixMyStreet::SendReport::Email->new( to => $dest );
    $sender->send($row, $h);
    if ($sender->success) {
        $row->set_extra_metadata(extra_email_sent => 1);
    }
}

sub _add_claim_auto_response {
    my ($self, $row, $h) = @_;

    my $user = $self->body->comment_user;
    return unless $user && $row->category eq 'Claim';

    # Attach auto-response template if present
    my $template = $row->response_templates->search({ 'me.state' => $row->state })->first;
    my $description = $template->text if $template;
    if ( $description ) {
        my $updates = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_body => $self->body,
            blank_updates_permitted => 1,
        );

        my $request = {
            service_request_id => $row->id,
            update_id => 'auto-internal',
            # Add a second so it is definitely later than problem confirmed timestamp,
            # which uses current_timestamp (and thus microseconds) whilst this update
            # is rounded down to the nearest second
            comment_time => DateTime->now->add( seconds => 1 ),
            status => 'open',
            description => $description,
        };
        my $update = $updates->process_update($request, $row);
        my $row_id = $row->id;
        if ($update) {
            $h->{update} = {
                item_text => $update->text,
                item_extra => $update->get_column('extra'),
            };

            # Stop any alerts being sent out about this update as included here.
            $h->{report}->cancel_update_alert($update->id);
        }
    }
}

sub email_list {
    my ($emails, $name) = @_;
    return unless $emails;
    my @emails = split /,/, $emails;
    my @to = map { [ $_, $name ] } @emails;
    return @to;
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{mark_reopen} = 1;
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    push @$meta, {
        code => 'road-placement',
        datatype => 'singlevaluelist',
        description => 'Is the fly-tip located on',
        order => 100,
        required => 'true',
        variable => 'true',
        values => [
            { key => 'road', name => 'The road' },
            { key => 'off-road', name => 'Off the road/on a verge' },
        ],
    } if $service->{service_name} eq 'Flytipping';
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    return unless $report->category eq 'Flytipping';
    return unless $self->{c}->stash->{report}->to_body_named('Buckinghamshire');

    my $placement = $self->{c}->get_param('road-placement');
    return unless $placement && $placement eq 'off-road';

    $report->category('Flytipping (off-road)');
}

sub filter_report_description {
    my ($self, $description) = @_;

    # this allows _ in the domain name but I figure it's unlikely to
    # generate false positives so lets go with that for the same of
    # a simpler regex
    $description =~ s/\b[\w.!#$%&'*+\-\/=?^_{|}~]+\@[\w\-]+\.[^ ]+\b//g;
    $description =~ s/ (?: \+ \d{2} \s? | \b 0 ) (?:
        \d{2} \s? \d{4} \s? \d{4}   # 0xx( )xxxx( )xxxx
      | \d{3} \s \d{3} \s? \d{4}    # 0xxx xxx( )xxxx
      | \d{3} \s? \d{2} \s \d{4,5}  # 0xxx( )xx xxxx(x)
      | \d{4} \s \d{5,6}            # 0xxxx xxxxx(x)
    ) \b //gx;

    return $description;
}

sub default_map_zoom { 4 }

sub _dashboard_export_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns( staff_user => 'Staff User' );

    my $user_lookup = $self->csv_staff_users;

    $csv->csv_extra_data(sub {
        my $report = shift;
        my $staff_user = $self->csv_staff_user_lookup($report->get_extra_metadata('contributed_by'), $user_lookup);
        return {
            staff_user => $staff_user,
        };
    });
}

sub dashboard_export_updates_add_columns {
    shift->_dashboard_export_add_columns(@_);
}

sub dashboard_export_problems_add_columns {
    shift->_dashboard_export_add_columns(@_);
}

sub dashboard_extra_bodies {
    my ($self) = @_;

    return $self->parish_bodies->all;
}

sub _parish_ids {
    # This is a list of all Parish Councils within Buckinghamshire,
    # taken from https://mapit.mysociety.org/area/163793/children.json?type=CPC
    return [
        "135493",
        "135494",
        "148713",
        "148714",
        "164523",
        "164562",
        "164563",
        "53319",
        "53360",
        "53390",
        "53404",
        "53453",
        "53486",
        "53515",
        "53542",
        "53612",
        "53822",
        "53874",
        "53887",
        "53942",
        "53991",
        "54003",
        "54014",
        "54158",
        "54174",
        "54178",
        "54207",
        "54289",
        "54305",
        "54342",
        "54355",
        "54402",
        "54465",
        "54479",
        "54493",
        "54590",
        "54615",
        "54672",
        "54691",
        "54721",
        "54731",
        "54787",
        "54846",
        "54879",
        "54971",
        "55290",
        "55326",
        "55534",
        "55638",
        "55724",
        "55775",
        "55896",
        "55900",
        "55915",
        "55945",
        "55973",
        "56007",
        "56091",
        "56154",
        "56268",
        "56350",
        "56379",
        "56418",
        "56432",
        "56498",
        "56524",
        "56592",
        "56609",
        "56641",
        "56659",
        "56664",
        "56709",
        "56758",
        "56781",
        "57099",
        "57138",
        "57330",
        "57332",
        "57366",
        "57367",
        "57507",
        "57529",
        "57582",
        "57585",
        "57666",
        "57701",
        "58166",
        "58208",
        "58229",
        "58279",
        "58312",
        "58333",
        "58405",
        "58523",
        "58659",
        "58815",
        "58844",
        "58891",
        "58965",
        "58980",
        "59003",
        "59007",
        "59012",
        "59067",
        "59144",
        "59152",
        "59179",
        "59211",
        "59235",
        "59288",
        "59353",
        "59491",
        "59518",
        "59727",
        "59763",
        "59971",
        "60027",
        "60137",
        "60321",
        "60322",
        "60438",
        "60456",
        "60462",
        "60532",
        "60549",
        "60598",
        "60622",
        "60640",
        "60731",
        "60777",
        "60806",
        "60860",
        "60954",
        "61100",
        "61102",
        "61107",
        "61142",
        "61144",
        "61167",
        "61172",
        "61249",
        "61268",
        "61269",
        "61405",
        "61445",
        "61471",
        "61479",
        "61898",
        "61902",
        "61920",
        "61964",
        "62226",
        "62267",
        "62296",
        "62311",
        "62321",
        "62454",
        "62640",
        "62657",
        "62938",
        "63040",
        "63053",
        "63068",
        "63470",
        "63476",
        "63501",
        "63507",
        "63517",
        "63554",
        "63715",
        "63723"
    ];
}

# Enable adding/editing of parish councils in the admin
sub add_extra_areas {
    my ($self, $areas) = @_;

    my $ids_string = join ",", @{ $self->_parish_ids };

    my $extra_areas = mySociety::MaPit::call('areas', [ $ids_string ]);

    my %all_areas = (
        %$areas,
        %$extra_areas
    );
    return \%all_areas;
}

# Make sure CPC areas are included in point lookups for new reports
sub add_extra_area_types {
    my ($self, $types) = @_;

    my @types = (
        @$types,
        'CPC',
    );
    return \@types;
}

sub is_two_tier { 1 }

sub should_skip_sending_update {
    my ($self, $update ) = @_;
    return 1;
}

=head2 disable_phone_number_entry

Hides the phone number field on report/update forms for anyone but Bucks staff.

=cut

sub disable_phone_number_entry {
    my $self = shift;
    my $c = $self->{c};

    # Only show the phone number field for Bucks staff
    my $staff = $c->user_exists && $c->user->from_body && $c->user->from_body->id == $self->body->id;
    return $staff ? 0 : 1;
}

sub report_sent_confirmation_email { 'id' }

sub handle_email_status_codes { 1 }

# Try OSM for Bucks as it provides better disamiguation descriptions.
sub get_geocoder { 'OSM' }

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs if $self->{c}->stash->{categories_for_point}; # Admin page
    return $rs->search( { category => { '!=', 'Flytipping (off-road)'} } );
}

sub lookup_site_code_config {
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my $suffix = FixMyStreet->config('STAGING_SITE') ? "staging" : "assets";
    return {
    buffer => 200, # metres
    _nearest_uses_latlon => 1,
    proxy_url => "https://$host/alloy/layer.php",
    layer => "designs_highwaysNetworkAsset_62d68698e5a3d20155f5831d",
    url => "https://buckinghamshire.$suffix",
    property => "itemId",
    accept_feature => sub {
        my $feature = shift;

        # There are only certain features we care about, the rest can be ignored.
        my @valid_types = ( "2", "3A", "3B", "4A", "4B", "HE", "HWOA", "HWSA", "P" );
        my %valid_types = map { $_ => 1 } @valid_types;
        my $type = $feature->{properties}->{feature_ty};

        return $valid_types{$type};
    }
} }

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    # For red claims site lookup we're still using the old WFS assets for now
    if ($cfg->{typename} && $cfg->{typename} eq 'Whole_Street') {
        return $self->next::method($cfg);
    }

    # Buckinghamshire's asset proxy is Alloy, not a standard WFS server.

    my ($w, $s, $e, $n) = split(/,/, $cfg->{bbox});
    ($s, $w) = Utils::convert_en_to_latlon($w, $s);
    ($n, $e) = Utils::convert_en_to_latlon($e, $n);
    my $bbox = "$w,$s,$e,$n";

    my $uri = URI->new($cfg->{proxy_url});
    $uri->query_form(
        layer => $cfg->{layer},
        url => $cfg->{url},
        bbox => $bbox,
    );

    return $uri;
}


sub _lookup_site_name {
    my $self = shift;
    my $row = shift;

    my $cfg = {
        buffer => 200,
        url => "https://tilma.mysociety.org/mapserver/bucks",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Whole_Street",
        accept_feature => sub { 1 }
    };
    my ($x, $y) = $row->local_coords;
    my $features = $self->_fetch_features($cfg, $x, $y);
    return $self->_nearest_feature($cfg, $x, $y, $features);
}

sub claim_location {
    my ($self, $row) = @_;

    my $road = $self->_lookup_site_name($row);

    if (!$road) {
        return "Unknown location";
    }

    my $site_name = $road->{properties}->{site_name};
    $site_name =~ s/([\w']+)/\u\L$1/g;
    my $area_name = $road->{properties}->{area_name};
    $area_name =~ s/([\w']+)/\u\L$1/g;

    return "$site_name, $area_name";
}

around 'munge_sendreport_params' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    # Do not want the user's email to be the Reply-To
    delete $params->{'Reply-To'};

    # The district areas don't exist in MapIt past generation 36, so look up
    # what district this report would have been in and temporarily override
    # the areas column so BoroughEmails::munge_sendreport_params can do its
    # thing.
    my ($lat, $lon) = ($row->latitude, $row->longitude);
    my $district = FixMyStreet::MapIt::call( 'point', "4326/$lon,$lat", type => 'DIS', generation => 36 );
    ($district) = keys %$district;

    my $original_areas = $row->areas;
    $row->areas(",$district,");

    $self->$orig($row, $h, $params);

    $row->areas($original_areas);
};

sub council_rss_alert_options {
    my ($self, @args) = @_;
    my ($options) = super();

    # rename old district councils to 'area' and remove 'ward' from their wards
    # remove 'County' from Bucks Council name
    for my $area (@$options) {
        for my $key (qw(rss_text text)) {
            $area->{$key} =~ s/District Council/area/ && $area->{$key} =~ s/ ward//;
            $area->{$key} =~ s/ County//;
        }
    }

    return ($options);
}

sub car_park_wfs_query {
    my ($self, $row) = @_;

    my $uri = URI->new("https://maps.buckscc.gov.uk/arcgis/services/Transport/BC_Car_Parks/MapServer/WFSServer");
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::27700",
        TYPENAME => "BC_CAR_PARKS",
        VERSION => "1.1.0",
        propertyName => 'OBJECTID,Shape',
    );

    try {
        return $self->_get($self->_wfs_uri($row, $uri));
    } catch {
        # Ignore WFS errors.
        return {};
    };
}

sub speed_limit_wfs_query {
    my ($self, $row) = @_;

    my $uri = URI->new("https://maps.buckscc.gov.uk/arcgis/services/Transport/OS_Highways_Speed/MapServer/WFSServer");
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::27700",
        TYPENAME => "OS_Highways_Speed:CORPGIS.CORPORATE.OS_Highways_Speed",
        VERSION => "1.1.0",
        propertyName => 'OBJECTID,Shape,speed',
    );

    try {
        return $self->_get($self->_wfs_uri($row, $uri));
    } catch {
        # Ignore WFS errors.
        return {};
    };
}

sub _wfs_uri {
    my ($self, $row, $base_uri) = @_;

    # This fn may be called before cobrand has been set in the
    # reporting flow and local_coords needs it to be set
    $row->cobrand('buckinghamshire') if !$row->cobrand;

    my ($x, $y) = $row->local_coords;
    my $buffer = 50; # metres
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $filter = "
    <ogc:Filter xmlns:ogc=\"http://www.opengis.net/ogc\">
        <ogc:BBOX>
            <ogc:PropertyName>Shape</ogc:PropertyName>
            <gml:Envelope xmlns:gml='http://www.opengis.net/gml' srsName='EPSG:27700'>
                <gml:lowerCorner>$w $s</gml:lowerCorner>
                <gml:upperCorner>$e $n</gml:upperCorner>
            </gml:Envelope>
        </ogc:BBOX>
    </ogc:Filter>";
    $filter =~ s/\n\s+//g;

    # URI encodes ' ' as '+' but arcgis wants it to be '%20'
    # Putting %20 into the filter string doesn't work because URI then escapes
    # the '%' as '%25' so you get a double encoding issue.
    #
    # Avoid all of that and just put the filter on the end of the $base_uri
    $filter = URI::Escape::uri_escape_utf8($filter);

    return "$base_uri&filter=$filter";
}

# Wrapper around LWP::Simple::get to make mocking in tests easier.
sub _get {
    my ($self, $uri) = @_;

    get($uri);
}

around 'report_validation' => sub {
    my ($orig, $self, $report, $errors) = @_;

    my $contact = FixMyStreet::DB->resultset('Contact')->find({
        body_id => $self->body->id,
        category => $report->category,
    });

    # Reports to parishes are considered "owned" by Bucks, but this method only searches for
    # contacts owned by the Bucks body, so just call the original method if contact isn't found.
    return $self->$orig($report, $errors) unless $contact;

    my %groups = map { $_ => 1 } @{ $contact->groups };
    return $self->$orig($report, $errors) unless $groups{'Car park issue'};

    my $car_parks = $self->car_park_wfs_query($report);

    if (index($car_parks, '<gml:featureMember>') == -1) {
        # Car park not found
        $errors->{category} = 'Please select a location in a Buckinghamshire maintained car park';
    }

    return $self->$orig($report, $errors);
};

# Route certain reports to the parish if the user answers 'no' to the
# question 'Is the speed limit greater than 30mph?'
sub munge_contacts_to_bodies {
    my ($self, $contacts, $report) = @_;

    my $parish_cats = [ 'Grass cutting', 'Hedge problem', 'Dirty signs', 'Unauthorised signs' ];
    my %parish_cats = map { $_ => 1 } @$parish_cats;

    return unless $parish_cats{$report->category};

    # If there's only one contact then we just want to use that, so skip filtering.
    return if scalar @{$contacts} < 2;

    my $greater_than_30 = $report->get_extra_field_value('speed_limit_greater_than_30');

    if (!$greater_than_30) {
        # Look up the report's location on the speed limit WFS server
        my $speed_limit_xml = $self->speed_limit_wfs_query($report);
        my $speed_limit = $1 if $speed_limit_xml =~ /<OS_Highways_Speed:speed>([\.\d]+)<\/OS_Highways_Speed:speed>/;

        if ($speed_limit) {
            $greater_than_30 = $speed_limit > 30 ? 'yes' : 'no';
        } else {
            $greater_than_30 = 'dont_know';
        }
    }

    my $area_id = $self->council_area_id;

    if ($greater_than_30 eq 'no') {
        # Route to the parish
        @$contacts = grep { !$_->body->areas->{$area_id} } @$contacts;
    } else {
        # Route to council
        @$contacts = grep { $_->body->areas->{$area_id} } @$contacts;
    }
}

sub area_ids_for_problems {
    my ($self) = @_;

    return ($self->council_area_id, @{$self->_parish_ids});
}

# Need to check parish areas before passing to UKCouncils::owns_problem for
# the body-cobrand check.
sub owns_problem {
    my ($self, $report) = @_;

    my @bodies;
    if (ref $report eq 'HASH') {
        return unless $report->{bodies_str};
        @bodies = split /,/, $report->{bodies_str};
        @bodies = FixMyStreet::DB->resultset('Body')->search({ id => \@bodies })->all;
    } else { # Object
        @bodies = values %{$report->bodies};
    }

    # Want to ignore National Highways here
    my %areas = map { %{$_->areas} } grep { $_->name !~ /National Highways/ } @bodies;

    foreach my $area_id ($self->area_ids_for_problems) {
        return 1 if $areas{$area_id};
    }

    # Fall back to the parent method that checks the body's cobrand value.
    return $self->next::method($report);
}

sub parish_bodies {
    my ($self) = @_;

    return $self->{parish_bodies} //= FixMyStreet::DB->resultset('Body')->search(
        { 'body_areas.area_id' => { -in => $self->_parish_ids } },
        { join => 'body_areas', order_by => 'name' }
    )->active;
}

# Show parish problems on the cobrand.
sub problems_restriction_bodies {
    my ($self) = @_;

    my @parishes = $self->parish_bodies->all;
    my @parish_ids = map { $_->id } @parishes;

    return [$self->body->id, @parish_ids];
}

sub updates_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    my $bodies = $self->problems_restriction_bodies;
    return $rs->to_body($bodies);
}

# Redirect to .com if not Bucks or a parish
sub reports_body_check {
    my ( $self, $c, $code ) = @_;

    my @parishes = $self->parish_bodies->all;
    my @bodies = ($self->body, @parishes);
    my $matched = 0;
    foreach my $body (@bodies) {
        if ( $body->name =~ /^\Q$code\E/ ) {
            $matched = 1;
            last;
        }
    }

    if (!$matched) {
        $c->res->redirect( 'https://www.fixmystreet.com' . $c->req->uri->path_query, 301 );
        $c->detach();
    }

    return;
}

sub about_hook {
    my ($self) = @_;

    my $c = $self->{c};
    if ($c->stash->{template} eq 'about/parishes.html') {
        my @parishes = $self->parish_bodies->all;
        $c->stash->{parishes} = \@parishes;
    }
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Buckinghamshire postcode, street name and area, or report reference number';
}

sub lookup_by_ref {
    my ($self, $ref) = @_;
    if (my ($id) = $ref =~ /^\s*(40\d{6})\s*$/) {
        return { 'extra' => { '@>' => encode_json({ confirm_reference => $id }) } };
    }
    return 0;
}

1;
