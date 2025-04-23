=head1 NAME

FixMyStreet::Cobrand::BathNES - code specific to the BathNES cobrand

=head1 SYNOPSIS

=cut

package FixMyStreet::Cobrand::BathNES;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use utf8;

use Moo;
with 'FixMyStreet::Roles::Open311Multi';

=head2 Defaults

=over 4

=cut

use Moo;
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::ConfirmOpen311';

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;
use mySociety::EmailUtil qw(is_valid_email);

sub council_area_id { return 2551; }
sub council_area { return 'Bath and North East Somerset'; }
sub council_name { return 'Bath and North East Somerset Council'; }
sub council_url { return 'bathnes'; }

=item * Users with a bathnes.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'bathnes.gov.uk' }

=item * /around map shows only open reports by default.

=cut

sub on_map_default_status { 'open' }

=item * Uses OSM because default of Bing gives poor results.

=cut

sub get_geocoder {
    return 'OSM';
}

=item * Sends out confirmation emails when a report is sent.

=cut

sub report_sent_confirmation_email { 'id' }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Add display_name as an extra contact field.

=cut

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

=back

=cut

sub geocoder_munge_results {
    my ($self, $result) = @_;
    $result->{display_name} =~ s/, United Kingdom$//;
    $result->{display_name} =~ s/, Bath and North East Somerset, West of England, England//;
}

=head2 disambiguate_location

Geocoder tweaked to always search in Bath and NES areas.
Also applies some replacements for common typos and local names.

=cut

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

sub geocode_postcode {
    my ( $self, $s ) = @_;

    # One particular road name has an override to a specific location,
    # as the geocoder doesn't find any results for it.
    if ($s =~/^ten\s+acre\s+l[a]?n[e]?$/i) {
        return {
            latitude => 51.347351,
            longitude => -2.409305
        };
    }

    return $self->next::method($s);
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

=head2 pin_colour

BathNES uses the following pin colours:

=over 4

=item * grey: closed as 'not responsible'

=item * green: fixed or otherwise closed

=item * red: newly open

=item * yellow: any other open state

=back

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

=head2 default_map_zoom

If we're displaying the map at the user's GPS location we
want to start a bit more zoomed in than if they'd entered
a postcode/address.

=cut

sub default_map_zoom {
    my $self = shift;
    return 3 unless $self->{c}; # no c for batch job calling static_map
    return $self->{c}->get_param("geolocate") ? 5 : 3;
}

=head2 available_permissions

Sets-up custom permissions for rejecting reports and exporting extra columns in CSVs.

=cut

sub available_permissions {
    my $self = shift;

    my $permissions = $self->SUPER::available_permissions();

    $permissions->{Problems}->{report_reject} = "Reject reports";
    $permissions->{Dashboard}->{export_extra_columns} = "Extra columns in CSV export";

    return $permissions;
}

=head2 lookup_site_code

Looks up a site code from a BathNES server.

=cut

# TODO: Maybe refactor to a lookup_site_code_config.

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

=head2 categories_restriction

Categories covering BANES have a mixture of Open311 and Email
send methods. BANES only want specific categories to be visible on their
cobrand, not the email categories from FMS.com.

The FMS.com categories have a devolved send_method set to Email, so we can
filter these out.

NB. BANES have a 'Street Light Fault' category that has its
send_method set to 'Email::BathNES' (to use a custom template) which must
be show on the cobrand.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { -or => [
        'me.send_method' => undef, # Open311 categories, or National Highways
        'me.send_method' => '', # Open311 categories that have been edited in the admin
        'me.send_method' => 'Email::BathNES', # Street Light Fault
        'me.send_method' => 'Blackhole', # Parks categories
    ] } );
}

=head2 open311_munge_update_params

Stub needs to exist for FixMyStreet::Roles::Open311Multi

=cut

sub open311_munge_update_params {
}

=head2 open311_post_send

BANES have a passthrough open311 endpoint that receives all categories with email
addresses.

These then need to be sent to the specified email address after a successful
open311 send.

=cut

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful and the email not previously sent
    return unless $row->external_id;
    return if $row->get_extra_metadata('extra_email_sent');

    my $contact = $row->contact->email;
    $contact =~ s/Passthrough-//;
    return unless is_valid_email($contact);

    $row->push_extra_fields({ name => 'fixmystreet_id', description => 'FMS reference', value => $row->id });

    my $sender = FixMyStreet::SendReport::Email->new(
        use_verp => 0, use_replyto => 1, to => [ $contact ] );
    $sender->send($row, $h);
    if ($sender->success) {
        $row->set_extra_metadata(extra_email_sent => 1);
    }

    $row->remove_extra_field('fixmystreet_id');
}

=head2 dashboard_export_updates_add_columns

Adds 'Staff User' and 'User Email' columns for users with the 'Export Extra Columns'
permission.

=cut

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
            user_email => $report->user ? $report->user->email : '',
            staff_user => $staff_user,
        };
    });
}

=head2 dashboard_export_updates_add_columns

Adds a 'Staff User', 'User Email', 'User Phone' and 'Attribute Data' column for
users with the 'Export Extra Columns'permission.

=cut

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
                user_email => $report->user ? $report->user->email : '',
                user_phone => $report->user ? $report->user->phone : '',
                staff_user => $self->csv_staff_user_lookup($report->get_extra_metadata('contributed_by'), $user_lookup),
            ),
        };
    });
}

=head2

We protect all BANES categories that are open311 protected from being removed.

Default open311 protection is to allow category name to be changed without
being overwritten by the category name of its existing service code.

This is so the Passthrough categories (all the email categories),
which are manually added, aren't removed by the population of the service list.

=cut

sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete open311 protected contacts when importing
    return $contacts->search({
        -not => { extra => { '@>' => '{"open311_protect":1}' } }
    });
}

=head2 post_report_report_problem_link

Overrides the 'post-report' report another problem here button with one linking back to the front page, rather than the report view at the same location.

=cut

sub post_report_report_problem_link {
    return {
        uri => '/',
        label => 'Report a problem',
        attrs => 'class="report-a-problem-btn"',
    };

}

=head2 staff_can_assign_reports_to_disabled_categories

Staff users are unable to assign a report to a category that is disabled.

=cut

sub staff_can_assign_reports_to_disabled_categories { 0; }


1;
