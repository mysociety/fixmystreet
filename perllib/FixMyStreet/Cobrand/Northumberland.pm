package FixMyStreet::Cobrand::Northumberland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

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

sub allow_anonymous_reports { 'button' }

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

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
        { name => 'category',
          value => $row->category },
    ];

    return $open311_only;
}

sub open311_title_fetched_report {
    my ($self, $request) = @_;
    my ($group, $category) = split(/_/, $request->{service_name});
    return sprintf("%s: %s", $group, $category);
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible' || !$self->owns_problem($p);
    return 'green' if $p->state eq 'confirmed';
    return 'yellow' if $p->state eq 'investigating';
    return 'blue' if $p->state eq 'action scheduled';
    return 'red' if $p->is_fixed;
    return 'orange'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons {
    return '/cobrands/northumberland/images/';
}

1;
