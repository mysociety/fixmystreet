=head1 NAME

FixMyStreet::Cobrand::Buckinghamshire - code specific to the Buckinghamshire cobrand

=head1 SYNOPSIS

We integrate with Buckinghamshire's Alloy back end for highways reporting and
Evo for red claims, also send emails for some categories, and send
reports to Buckinghamshire parishes based on category/speed limit.
Emails for parish bodies can be found on this link if they are found to have changed:
 https://buckinghamshire.moderngov.co.uk/mgParishCouncilDetails.aspx?bcr=1

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


use LWP::UserAgent;
use URI;
use Try::Tiny;
use Utils;

use constant VEHICLE_LITTERING_CATEGORY => 'Littering From Vehicles';

sub council_area_id { return 163793; }
sub council_area { return 'Buckinghamshire'; }
sub council_name { return 'Buckinghamshire Council'; }
sub council_url { return 'buckinghamshire'; }

=item * Bucks uses its own geocoder (L<FixMyStreet::Geocode::Buckinghamshire>)

Bexley provides a layer containing Rights of Way that
supplements the standard geocoder.

=cut

sub get_geocoder { 'Buckinghamshire' }

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
        result_strip => ', Buckinghamshire, England',
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

=item * Customised pin colours

Bucks have a grey cross for closed / other council reports;
green tick for fixed; yellow cone for open; orange at work
for other open states.

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey-cross' if $p->is_closed || ($context ne 'reports' && !$self->owns_problem($p));
    return 'green-tick' if $p->is_fixed;
    return 'yellow-cone' if $p->state eq 'confirmed';
    return 'orange-work'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons { '/i/pins/whole-shadow-cone-spot/' }

=item * We use both their old and new domains for the admin_user_domain.

=cut

sub admin_user_domain { ( 'buckscc.gov.uk', 'buckinghamshire.gov.uk' ) }

=item * Bucks use the triage system for handling parish redirected reports.

=cut

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

=item * Bucks automatically resend any report upon a category change.

=cut

# Assume that any category change means the report should be resent
sub category_change_force_resend { 1 }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=head2 post_report_sent

Bucks have a special 'Littering From Vehicles' category; any reports made in
that category are automatically set to 'Investigating'.

=cut

sub post_report_sent {
    my ( $self, $problem ) = @_;

    if ( $problem->category eq VEHICLE_LITTERING_CATEGORY ) {
        $problem->update( { state => 'investigating' } );
    }
}

sub open311_extra_data_exclude { [ 'road-placement' ] }

=head2 open311_update_missing_data

All reports sent to Alloy should have a parent asset they're associated with.
This is indicated by the value in the asset_resource_id field. For certain
categories (e.g. street lights, grit bins) this will be the asset the user
selected from the map. For other categories (e.g. potholes) or if the user
didn't select an asset then we look up the nearest road from Buckinghamshire's
Alloy server and use that as the parent.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    my $dest = $row->contact->email;

    # If the report doesn't already have an asset, associate it with the
    # closest feature from the Alloy highways network layer.
    # This may happen because the report was made on the app, without JS,
    # using a screenreader, etc.
    if ($dest !~ /^(Abavus|Cams)/ && !$row->get_extra_field_value('asset_resource_id')) {
        if (my $item_id = $self->lookup_site_code($row, 'alloy')) {
            $row->update_extra_field({ name => 'asset_resource_id', value => $item_id });
        }
    }

    if ($dest =~ /^Cams/ && !$row->get_extra_field_value('LinkCode')) {
        my $item = $self->lookup_site_code($row, 'InfraWFS');
        if ($item && $item->{distance} < 10) {
            $row->update_extra_field({ name => 'AdminArea', value => $item->{'ms:AdminArea'} });
            $row->update_extra_field({ name => 'LinkCode', value => $item->{'ms:InfraCode'} });
            $row->update_extra_field({ name => 'LinkType', value => $item->{'ms:LinkType'} });
        } else {
            if ($item = $self->lookup_site_code($row, 'RouteWFS')) {
                $row->update_extra_field({ name => 'AdminArea', value => $item->{'ms:AdminArea'} });
                $row->update_extra_field({ name => 'LinkCode', value => $item->{'ms:RouteCode'} });
                $row->update_extra_field({ name => 'LinkType', value => $item->{'ms:LinkType'} });
            }
        }
    }
}

=head2 open311_extra_data_include

Reports in the "Apply for Access Protection Marking" category have some
extra field values that we want to append to the report description
before it's passed to Alloy.

=cut

around open311_extra_data_include => sub {
    my ($orig, $self) = (shift, shift);
    my $open311_only = $self->$orig(@_);

    my ($row, $h, $contact) = @_;

    if (my $address = $row->get_extra_field_value('ADDRESS_POSTCODE')) {
        my $phone = $row->get_extra_field_value('TELEPHONE_NUMBER') || "";
        for (@$open311_only) {
            if ($_->{name} eq 'description') {
                $_->{value} .= "\n\nAddress:\n$address\n\nPhone:\n$phone";
            }
        }
    }

    if ($contact->email =~ /^Abavus/ && $h->{closest_address}) {
        push @$open311_only, {
            name => 'closest_address', value => $h->{closest_address}->multiline(5) };
        $h->{closest_address} = '';
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
    my $group = $row->get_extra_metadata('group') || '';
    my $dest = $emails->{$row->category} || $emails->{$group};
    return unless $dest;
    $dest = [ email_list($dest->[0], $dest->[1] || 'FixMyStreet') ];

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
    my $description = $template ? $template->text : undef;
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
            $row->cancel_update_alert($update->id);
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

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
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

    return if $csv->dbi; # staff_user included by default

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
    # This should be a list of all Parish Councils within Buckinghamshire,
    # taken from https://mapit.mysociety.org/area/163793/children.json?type=CPC
    return FixMyStreet::DB->resultset("Config")->get('buckinghamshire_parishes') || [];
}

# Enable adding/editing of parish councils in the admin
sub add_extra_areas_for_admin {
    my ($self, $areas) = @_;

    my $ids_string = join ",", @{ $self->_parish_ids };
    return $areas unless $ids_string;

    my $extra_areas = mySociety::MaPit::call('areas', [ $ids_string ]);

    my %all_areas = (
        %$areas,
        %$extra_areas
    );
    return \%all_areas;
}

sub is_two_tier { 1 }

=head2 should_skip_sending_update

Only send updates to one particular backend

=cut

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $contact = $update->problem->contact || return 1;
    return 0 if $contact->email =~ /^Abavus/;
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

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs if $self->{c}->stash->{categories_for_point}; # Admin page
    return $rs->search( { category => { '!=', 'Flytipping (off-road)'} } );
}

sub lookup_site_code_config {
    my ($self, $type) = @_;
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    if ($type eq 'streets') {
        return {
            buffer => 200,
            url => "https://$host/mapserver/bucks",
            srsname => "urn:ogc:def:crs:EPSG::27700",
            typename => "Whole_Street",
            accept_feature => sub { 1 }
        };
    } elsif ($type eq 'alloy') {
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
        };
    } else {
        return {
            buffer => 200,
            url => "https://$host/proxy/bucks_prow/wfs/",
            srsname => "urn:ogc:def:crs:EPSG::27700",
            typename => $type,
            outputformat => 'GML3',
        };
    }
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    # For non-Alloy we don't need to adjust the URL
    if ($cfg->{typename}) {
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

sub _nearest_feature {
    my ($self, $cfg, $x, $y, $features) = @_;

    # The Bucks PROW is XML, not JSON which the default code handles
    if ($cfg->{url} !~ /bucks_prow/) {
        return $self->next::method($cfg, $x, $y, $features);
    }

    my $chosen = '';
    my $nearest;

    for my $feature ( @{$features || []} ) {
        $feature = $feature->{'ms:RouteWFS'} || $feature->{'ms:InfraWFS'};

        my $geo = $feature->{'ms:msGeometry'};
        if ($geo->{'gml:Point'}) {
            # Convert to a one-segment zero-length line
            my $pt = $geo->{'gml:Point'}{'gml:pos'};
            $geo = [ { 'gml:posList' => { 'content' => "$pt $pt" } } ];
        } else {
            # Might be a "MultiCurve", might be a single "LineString"
            $geo = $geo->{'gml:MultiCurve'}{'gml:curveMembers'}{'gml:LineString'} || $geo->{'gml:LineString'};
            if (ref $geo ne 'ARRAY') {
                $geo = [ $geo ];
            }
        }
        foreach (@$geo) {
            my $coords = $_->{'gml:posList'}{'content'};
            my @coords = split / /, $coords;
            for (my $i=0; $i<@coords-2; $i+=2) {
                my $distance = $self->_distanceToLine($x, $y,
                    [ $coords[$i], $coords[$i+1] ],
                    [ $coords[$i+2], $coords[$i+3] ]
                );
                if ( !defined $nearest || $distance < $nearest ) {
                    $chosen = $feature;
                    $nearest = $distance;
                }
            }
        }
    }

    $chosen->{distance} = $nearest if $chosen;
    return $chosen;
}

sub claim_location {
    my ($self, $row) = @_;

    my $road = $self->lookup_site_code($row, 'streets');

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

sub car_park_wfs_query {
    my ($self, $row) = @_;
    my $uri = "https://maps.buckinghamshire.gov.uk/server/services/Transport/Car_Parks/MapServer/WFSServer";
    return $self->_wfs_post($uri, $row, 'BC_CAR_PARKS', ['OBJECTID', 'Shape']);
}

sub speed_limit_wfs_query {
    my ($self, $row) = @_;
    my $uri = "https://maps.buckinghamshire.gov.uk/server/services/Transport/OS_Highways_Speed/MapServer/WFSServer";
    return $self->_wfs_post($uri, $row, 'OS_Highways_Speed:OS_Highways_Speed', ['OBJECTID', 'Shape', 'speed']);
}

sub _wfs_post {
    my ($self, $uri, $row, $typename, $properties) = @_;

    # This fn may be called before cobrand has been set in the
    # reporting flow and local_coords needs it to be set
    $row->cobrand('buckinghamshire') if !$row->cobrand;

    my ($x, $y) = $row->local_coords;
    my $buffer = 50; # metres
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    $properties = map { "<wfs:PropertyName>$_</wfs:PropertyName>" } @$properties;
    my $data = <<EOF;
<wfs:GetFeature service="WFS" version="1.1.0" xmlns:wfs="http://www.opengis.net/wfs">
  <wfs:Query typeName="$typename">
    $properties
    <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
        <ogc:BBOX>
            <ogc:PropertyName>Shape</ogc:PropertyName>
            <gml:Envelope xmlns:gml="http://www.opengis.net/gml" srsName="EPSG:27700">
                <gml:lowerCorner>$w $s</gml:lowerCorner>
                <gml:upperCorner>$e $n</gml:upperCorner>
            </gml:Envelope>
        </ogc:BBOX>
    </ogc:Filter>
  </wfs:Query>
</wfs:GetFeature>
EOF

    try {
        return $self->_post($uri, $data);
    } catch {
        # Ignore WFS errors.
        return {};
    };
}

# Wrapper around LWP::Simple::get to make mocking in tests easier.
sub _post {
    my ($self, $uri, $data) = @_;

    my $ua = LWP::UserAgent->new;
    my $res = $ua->post($uri, Content_Type => "text/xml", Content => $data);
    return $res->decoded_content;
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
        my $speed_limit;
        $speed_limit = $1 if $speed_limit_xml =~ /<OS_Highways_Speed:speed>([\.\d]+)<\/OS_Highways_Speed:speed>/;

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
    my %areas = map { %{$_->areas} } grep { $_->get_column('name') !~ /National Highways/ } @bodies;

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
