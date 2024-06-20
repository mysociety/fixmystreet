package FixMyStreet::Cobrand::BathNES;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use utf8;

use Moo;
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::ConfirmOpen311';

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub council_area_id { return 2551; }
sub council_area { return 'Bath and North East Somerset'; }
sub council_name { return 'Bath and North East Somerset Council'; }
sub council_url { return 'bathnes'; }

sub admin_user_domain { 'bathnes.gov.uk' }

sub on_map_default_status { 'open' }

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub contact_extra_fields { [ 'display_name' ] }

sub contact_extra_fields_validation {
    my ($self, $contact, $errors) = @_;
    return unless $contact->get_extra_metadata('display_name');

    my @contacts = $contact->body->contacts->not_deleted->search({ id => { '!=', $contact->id } });
    my %display_names = map { ($_->get_extra_metadata('display_name') || '') => 1 } @contacts;
    if ($display_names{$contact->get_extra_metadata('display_name')}) {
        $errors->{display_name} = 'That display name is already in use';
    }
}

=item * Geocoder results are somewhat munged to display more cleanly

=cut

sub geocoder_munge_results {
    my ($self, $result) = @_;
    $result->{display_name} =~ s/, United Kingdom$//;
    $result->{display_name} =~ s/, Bath and North East Somerset, West of England, England//;
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bath and North East Somerset';

    # The council have provided a list of common typos which we should correct:
    my %replacements = (
        "broom" => "brougham",
        "carnarvon" => "caernarvon",
        "cornation" => "coronation",
        "beafort" => "beaufort",
        "beechan" => "beechen",
        "malreword" => "malreward",
        "canyerberry"=> "canterbury",
        "clairemont"=> "claremont",
        "salsbury"=> "salisbury",
        "solsberry"=> "solsbury",
        "lawn road" => "lorne",
        "new road high littleton" => "danis house",
    );

    foreach my $original (keys %replacements) {
        my $replacement = $replacements{$original};
        $string =~ s/$original/$replacement/ig;
    }

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.3559192103294,-2.47522827137605',
        span   => '0.166437921041471,0.429359043406088',
        bounds => [ 51.2730478766607, -2.70792015294201, 51.4394857977022, -2.27856110953593 ],
        string => $string,
    };
}

sub new_report_title_field_label {
    "Summarise the problem and location"
}

sub new_report_title_field_hint {
    "e.g. ‘pothole on Example St, near post box’"
}

sub new_report_detail_field_hint {
    "e.g. ‘This pothole has been here for two months and…’"
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires { 0 }

sub default_map_zoom {
    my $self = shift;

    # If we're displaying the map at the user's GPS location we
    # want to start a bit more zoomed in than if they'd entered
    # a postcode/address.
    return 3 unless $self->{c}; # no c for batch job calling static_map
    return $self->{c}->get_param("geolocate") ? 5 : 3;
}

sub available_permissions {
    my $self = shift;

    my $permissions = $self->SUPER::available_permissions();

    $permissions->{Problems}->{report_reject} = "Reject reports";
    $permissions->{Dashboard}->{export_extra_columns} = "Extra columns in CSV export";

    return $permissions;
}

sub report_sent_confirmation_email { 'id' }

sub lookup_site_code {
    my $self = shift;
    my $row = shift;

    my $buffer = 5; # metres
    my ($x, $y) = $row->local_coords;
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $uri = URI->new("https://isharemaps.bathnes.gov.uk/getows.ashx");
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::27700",
        TYPENAME => "AdoptedHighways",
        VERSION => "1.1.0",
        mapsource => "BathNES/WFS",
        outputformat => "application/json",
        BBOX => "$w,$s,$e,$n"
    );

    my $response = get($uri);

    my $j = JSON->new->utf8->allow_nonref;
    try {
        $j = $j->decode($response);
        return $j->{features}->[0]->{properties}->{usrn};
    } catch {
        # There was either no asset found, or an error with the WFS
        # call - in either case let's just proceed without the USRN.
        return;
    }

}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a location in ' . $self->council_area;
}

sub categories_restriction {
    my ($self, $rs) = @_;
    # Categories covering BANES have a mixture of Open311 and Email
    # send methods. BANES only want specific categories to be visible on their
    # cobrand, not the email categories from FMS.com.
    # The FMS.com categories have a devolved send_method set to Email, so we can
    # filter these out.
    # NB. BANES have a 'Street Light Fault' category that has its
    # send_method set to 'Email::BathNES' (to use a custom template) which must
    # be show on the cobrand.
    return $rs->search( { -or => [
        'me.send_method' => undef, # Open311 categories, or National Highways
        'me.send_method' => '', # Open311 categories that have been edited in the admin
        'me.send_method' => 'Email::BathNES', # Street Light Fault
        'me.send_method' => 'Blackhole', # Parks categories
    ] } );
}

sub dashboard_export_updates_add_columns {
    my ($self, $csv) = @_;

    return unless $csv->user->has_body_permission_to('export_extra_columns');

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        user_email => 'User Email',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email'],
        join => 'user',
    });
    my $user_lookup = $self->csv_staff_users;

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $staff_user = $self->csv_staff_user_lookup($report->get_extra_metadata('contributed_by'), $user_lookup);

        return {
            user_email => $report->user->email || '',
            staff_user => $staff_user,
        };
    });
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    # If running via DBI export, we need the extra columns saved
    return unless $csv->dbi || $csv->user->has_body_permission_to('export_extra_columns');

    $csv->add_csv_columns(
        user_email => 'User Email',
        user_phone => 'User Phone',
        staff_user => 'Staff User',
        attribute_data => "Attribute Data",
    );

    $csv->objects_attrs({
        '+columns' => ['user.email', 'user.phone'],
        join => 'user',
    });
    my $user_lookup = $self->csv_staff_users;

    $csv->csv_extra_data(sub {
        my $report = shift;
        my $attribute_data = join "; ", map { $_->{name} . " = " . $_->{value} } @{ $csv->_extra_field($report) };
        return {
            attribute_data => $attribute_data,
            $csv->dbi ? () : (
                user_email => $report->user->email || '',
                user_phone => $report->user->phone || '',
                staff_user => $self->csv_staff_user_lookup($report->get_extra_metadata('contributed_by'), $user_lookup),
            ),
        };
    });
}

sub post_report_report_problem_link {
    return {
        uri => '/',
        label => 'Report a problem',
        attrs => 'class="report-a-problem-btn"',
    };

}

1;
