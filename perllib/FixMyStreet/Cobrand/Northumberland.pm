=head1 NAME

FixMyStreet::Cobrand::Northumberland - code specific to the Northumberland cobrand

=head1 SYNOPSIS

=cut

package FixMyStreet::Cobrand::Northumberland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use DateTime::Format::W3CDTF;
use Utils;

=head2 Defaults

=over 4

=cut

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';

sub council_area_id { 2248 }
sub council_area { 'Northumberland' }
sub council_name { 'Northumberland County Council' }
sub council_url { 'northumberland' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '55.2426024934787,-2.06541585421059',
        span   => '1.02929721743568,1.22989513596542',
        bounds => [ 54.7823703267595, -2.68978494847825, 55.8116675441952, -1.45988981251283 ],
        result_strip => ', Northumberland, North East, England',
    };
}

sub admin_user_domain { 'northumberland.gov.uk' }

sub is_defect {
    my ($self, $p) = @_;
    return $p->service eq 'Open311';
}

=item * The default map zoom is a bit more zoomed-in

=cut

sub default_map_zoom { 4 }

=item * The default map view shows closed/fixed reports for 14 days

=cut

sub report_age {
    return {
        closed => '14 days',
        fixed  => '14 days',
    };
}

=item * Pins are green if closed/fixed, red if confirmed, orange otherwise

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_closed || $p->is_fixed;
    return 'red' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub has_aerial_maps { 'tilma.mysociety.org/mapcache/gmaps/northumberlandaerial@osmaps' }

=item * Hovering over a pin includes the state as well as the title

=cut

sub pin_hover_title {
    my ($self, $problem, $title) = @_;
    my $state = FixMyStreet::DB->resultset("State")->display($problem->state, 1, 'northumberland');
    return "$state: $title";
}

=item * The cobrand doesn't show reports before 3rd May 2023

=cut

sub cut_off_date { '2023-05-03' }

=item * The contact form is for abuse reports only

=cut

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

sub abuse_reports_only { 1 }

=item * Users cannot reopen reports

=cut

sub reopening_disallowed { 1 }

=item * Staff Only - Out Of Hours categories are treated as cleaning categories for National Highways

=cut

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    $self->SUPER::munge_report_new_contacts($contacts);

    foreach (@$contacts) {
        if (grep { $_ eq 'Staff Only - Out Of Hours' } @{$_->groups}) {
            $_->set_extra_metadata(nh_council_cleaning => 1);
        }
    }
}

=item * Fetched reports via Open311 use the service name as their title

=cut

sub open311_title_fetched_report {
    my ($self, $request) = @_;
    return $request->{service_name};
}

=item * The privacy policy is held on Northumberland's own site

=cut

sub privacy_policy_url {
    return 'https://www.northumberland.gov.uk/NorthumberlandCountyCouncil/media/About-the-Council/information%20governance/Privacy-notice-Fix-My-Street.pdf'
}

=item * The CSV export includes staff user/role, assigned to, and response time

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        staff_role => 'Staff Role',
        assigned_to => 'Assigned To',
        response_time => 'Response Time',
        nearest_address => 'Nearest address',
    );

    my $response_time = sub {
        my $hashref = shift;
        if (my $response = ($hashref->{fixed} || $hashref->{closed}) ) {
            $response = DateTime::Format::W3CDTF->parse_datetime($response)->epoch;
            my $confirmed = DateTime::Format::W3CDTF->parse_datetime($hashref->{confirmed})->epoch;
            return Utils::prettify_duration($response - $confirmed, 'minute');
        }
        return '';
    };

    if ($csv->dbi) {
        $csv->csv_extra_data(sub {
            my $report = shift;
            my $hashref = shift;

            my $address = '';
            if ( $report->{geocode} ) {
                my $addr = FixMyStreet::Geocode::Address->new($report->{geocode});
                $address = $addr->summary;
            }

            return {
                user_name_display => $report->{name},
                response_time => $response_time->($hashref),
                nearest_address => $address,
            };
        });
        return; # Rest already covered
    }

    my $user_lookup = $self->csv_staff_users;
    my $userroles = $self->csv_staff_roles($user_lookup);
    my $problems_to_user = $self->csv_active_planned_reports;

    $csv->csv_extra_data(sub {
        my $report = shift;
        my $hashref = shift;

        my $by = $report->get_extra_metadata('contributed_by');
        my $staff_user = '';
        my $staff_role = '';
        my $assigned_to = '';
        if ($by) {
            $staff_user = $self->csv_staff_user_lookup($by, $user_lookup);
            $staff_role = join(',', @{$userroles->{$by} || []});
        }

        my $address = '';
        if ( $report->geocode ) {
            $address = $report->nearest_address;
        }

        return {
            user_name_display => $report->name,
            staff_user => $staff_user,
            staff_role => $staff_role,
            assigned_to => $problems_to_user->{$report->id} || '',
            response_time => $response_time->($hashref),
            nearest_address => $address,
        };
    });
}

=item * Updates on reports fetched from Alloy are not sent.

=cut

sub should_skip_sending_update {
    my ($self, $comment) = @_;
    my $p = $comment->problem;
    return $self->is_defect($p);
}

=back

=cut

=head2 record_update_extra_fields

We want to create comments when assigned (= shortlisted) user or
extra details (= detail_information) are updated for a report.

=cut

sub record_update_extra_fields {
    {   shortlisted_user     => 1,
        detailed_information => 1,
    };
}

=head2 open311_munge_update_params

We pass a report's 'detailed_information' (from its
extra_metadata) to Alloy, as an 'extra_details' attribute.

We pass the name and email address of the user assigned to the report (the
user who has shortlisted the report).

We pass any category change.

=cut

sub open311_munge_update_params {
    my ( $self, $params, $comment, undef ) = @_;

    my $p = $comment->problem;

    my $detailed_information
        = $p->get_extra_metadata('detailed_information') // '';
    $params->{'attribute[extra_details]'} = $detailed_information;

    my $assigned_to = $p->shortlisted_user;
    $params->{'attribute[assigned_to_user_email]'}
        = $assigned_to
        ? $assigned_to->email
        : '';

    if ( $comment->text =~ /Category changed/ ) {
        my $service_code = $p->contact->email;
        my $category_group = $p->get_extra_metadata('group');

        $params->{service_code} = $service_code;
        $params->{'attribute[group]'} = $category_group
            if $category_group;
    }
}

1;
