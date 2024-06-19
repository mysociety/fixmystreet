=head1 NAME

FixMyStreet::Cobrand::NottinghamshirePolice - code specific to the Nottinghamshire Police cobrand.

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::NottinghamshirePolice;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use Moo;

=head2 Defaults

=over 4

=cut

sub council_area_id { [ 2236, 2565 ] }
sub council_area { 'Nottinghamshire'; }
sub council_name { 'Nottinghamshire Police' }
sub council_url { 'nottinghamshirepolice' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = "Nottinghamshire";

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '53.1337083457641,-1.00642123965732',
        span   => '0.713104976883301,0.678328244170235',
        bounds => [ 52.7894115139395, -1.34459045070673, 53.5025164908228, -0.666262206536495 ],
    };
}

sub enter_postcode_text { 'Enter a Nottinghamshire postcode, street name or area' }

sub privacy_policy_url {
    'https://www.nottinghamshire.pcc.police.uk/Document-Library/Public-Information/Policies-and-Procedures/People/Privacy-Notice-OPCCN-Feb-2023.pdf'
}

=item * Never allows anonymous reports.

=cut

sub allow_anonymous_reports { 0 }

=item * Users with a notts.police.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'notts.police.uk' }

=head2 pin_colour

Yellow for open, green for closed or fixed.

=cut

sub pin_colour {
    my ( $self, $p ) = @_;

    return 'green' if $p->is_fixed || $p->is_closed;
    return 'yellow';
}

=head2 body_disallows_state_change

Determines whether state of a report can be updated, based on user and current
report state.

The original reporter can reopen a closed/fixed report.

Note: Staff permissions are handled separately, via relevant_staff_user
check.

=cut

sub body_disallows_state_change {
    my ( $self, $problem ) = @_;

    if (   $self->{c}->user_exists
        && $self->{c}->user->id eq $problem->user->id )
    {
        return $problem->is_open ? 1 : 0;
    }

    return 1;
}

sub report_validation {
    my ($self, $report, $errors) = @_;

    my $regex = Utils::email_regex;

    if ($report->detail =~ /$regex/ || $report->title =~ /$regex/) {
        $errors->{detail} = 'Please remove any email addresses from report';
    }

    return $errors;
}

1;
