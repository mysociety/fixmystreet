package FixMyStreet::Cobrand::Northumberland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

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

1;
