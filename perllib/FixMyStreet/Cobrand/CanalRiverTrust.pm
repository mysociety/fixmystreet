=head1 NAME

FixMyStreet::Cobrand::CanalRiverTrust - code specific to the Canal & River Trust cobrand

=head1 SYNOPSIS

The Canal & River Trust is a charity looking after 2,000 miles of canals and
rivers, along with reservoirs and structures, in England and Wales.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::CanalRiverTrust;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;
use utf8;

sub council_name { 'Canal & River Trust' }
sub council_url { 'canalrivertrust' }
sub site_key { 'canalrivertrust' }
sub restriction { { cobrand => shift->moniker } }
sub hide_areas_on_reports { 1 }
sub suggest_duplicates { 1 }
sub all_reports_single_body { { name => 'Canal & River Trust' } }

=over 4

=item * It is not a council, so inherits from UK, not UKCouncils, but a number of functions are shared with what councils do

=cut

sub cut_off_date { '' }
sub problems_restriction { FixMyStreet::Cobrand::UKCouncils::problems_restriction($_[0], $_[1]) }
sub problems_on_map_restriction { $_[0]->problems_restriction($_[1]) }
sub problems_sql_restriction { FixMyStreet::Cobrand::UKCouncils::problems_sql_restriction($_[0], $_[1]) }
sub users_restriction { FixMyStreet::Cobrand::UKCouncils::users_restriction($_[0], $_[1]) }
sub updates_restriction { FixMyStreet::Cobrand::UKCouncils::updates_restriction($_[0], $_[1]) }
sub base_url { FixMyStreet::Cobrand::UKCouncils::base_url($_[0]) }
sub contact_name { FixMyStreet::Cobrand::UKCouncils::contact_name($_[0]) }
sub contact_email { FixMyStreet::Cobrand::UKCouncils::contact_email($_[0]) }
sub users_staff_admin { FixMyStreet::Cobrand::UKCouncils::users_staff_admin($_[0]) }
sub admin_allow_user { FixMyStreet::Cobrand::UKCouncils::admin_allow_user($_[0], $_[1]) }

sub enter_postcode_text { 'Enter a location, bridge number or postcode' }
sub example_places { ['Lock 47, Fazeley', 'Bridge 33, Kennet and Avon'] }
sub admin_user_domain { 'canalrivertrust.org.uk' }
sub abuse_reports_only { 1 }

sub fetch_area_children {
    my $self = shift;

    my $areas = FixMyStreet::MapIt::call('areas', $self->area_types_for_admin);
    $areas = {
        map { $_->{id} => $_ }
        grep { ($_->{country} || 'E') =~ /^[EW]$/ }
        values %$areas
    };
    return $areas;
}

=head2 Report categories

There is special handling of body/contacts; categories must end "(CRT)"
(this is stripped for display).

=cut

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;
    # On the cobrand there is only the Canals body
    %$bodies = map { $_->id => $_ } grep { $_->get_column('name') eq 'Canal & River Trust' } values %$bodies;
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    $code = 'CRT';
    foreach my $c (@$contacts) {
        my $clean_name = $c->category_display;
        if ($clean_name =~ s/ \($code\)//) {
            $c->set_extra_metadata(display_name => $clean_name);
        }
    }
}

sub admin_contact_validate_category {
    my ( $self, $category ) = @_;
    return "(CRT)" eq substr($category, -5) ? "" : "Category must end with (CRT).";
}

1;
