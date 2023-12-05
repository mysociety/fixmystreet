package FixMyStreet::Cobrand::Northumberland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use DateTime::Format::W3CDTF;
use Utils;

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
        centre => '55.2426024934787,-2.06541585421059',
        span   => '1.02929721743568,1.22989513596542',
        bounds => [ 54.7823703267595, -2.68978494847825, 55.8116675441952, -1.45988981251283 ],
    };
}

sub admin_user_domain { 'northumberland.gov.uk' }

sub default_map_zoom { 4 }

sub abuse_reports_only { 1 }

sub cut_off_date { '2023-05-03' }

sub reopening_disallowed {
    my ($self, $problem) = @_;

    # Check if reopening is disallowed by the category
    return 1 if $self->next::method($problem);

    # Only staff can reopen reports.
    my $c = $self->{c};
    my $user = $c->user;
    return 0 if ($c->user_exists && $user->from_body && $user->from_body->cobrand_name eq $self->council_name);
    return 1;
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    $self->SUPER::munge_report_new_contacts($contacts);

    foreach (@$contacts) {
        if (grep { $_ eq 'Staff Only - Out Of Hours' } @{$_->groups}) {
            $_->set_extra_metadata(nh_council_cleaning => 1);
        }
    }
}

sub open311_title_fetched_report {
    my ($self, $request) = @_;
    return $request->{service_name};
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_closed || $p->is_fixed;
    return 'red' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons {
    return '/cobrands/northumberland/images/';
}

sub privacy_policy_url {
    return 'https://www.northumberland.gov.uk/NorthumberlandCountyCouncil/media/About-the-Council/information%20governance/Privacy-notice-Fix-My-Street.pdf'
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        staff_role => 'Staff Role',
        assigned_to => 'Assigned To',
        response_time => 'Response Time',
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
            return {
                user_name_display => $report->{name},
                response_time => $response_time->($hashref),
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

        return {
            user_name_display => $report->name,
            staff_user => $staff_user,
            staff_role => $staff_role,
            assigned_to => $problems_to_user->{$report->id} || '',
            response_time => $response_time->($hashref),
        };
    });
}

1;
