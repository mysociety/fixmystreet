=head1 NAME

FixMyStreet::Cobrand::NottinghamshirePolice - code specific to the Nottinghamshire Police cobrand.

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::NottinghamshirePolice;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::BoroughEmails';

# Copying of functions from UKCouncils that can be used here also
sub suggest_duplicates { FixMyStreet::Cobrand::UKCouncils::suggest_duplicates($_[0]) }
sub all_reports_single_body { FixMyStreet::Cobrand::UKCouncils::all_reports_single_body($_[0], $_[1]) }
sub admin_show_creation_graph { 0 }

=head2 Defaults

=over 4

=cut

sub council_area_id { [ 2236, 2565 ] }
sub council_area { 'Nottinghamshire'; }
sub council_name { 'Nottinghamshire Police' }

=item * Any superuser or staff user can access the admin

=cut

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser || $user->from_body;
}

=item * Don't allow reports outside Nottinghamshire

=cut

sub area_check {
    my ( $self, $params, $context ) = @_;
    return 1 if FixMyStreet->staging_flag('skip_checks');
    my $councils = $params->{all_areas};
    foreach (@{$self->council_area_id}) {
        return 1 if defined $councils->{$_};
    }
    return ( 0, "That location is not covered by Nottinghamshire Police." );
}

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

=item * Yellow pins for open, green for closed or fixed

=cut

sub pin_colour {
    my ( $self, $p ) = @_;

    return 'green' if $p->is_fixed || $p->is_closed;
    return 'yellow';
}

=item * Do not allow email addresses in title or detail

=back

=cut

sub report_validation {
    my ($self, $report, $errors) = @_;

    my $regex = Utils::email_regex;

    if ($report->detail =~ /$regex/ || $report->title =~ /$regex/) {
        $errors->{detail} = 'Please remove any email addresses from report';
    }

    return $errors;
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
=item * Category change to/from "Council referral" category will resend the report

=cut

sub category_change_force_resend {
    my ($self, $old, $new) = @_;
    my $referral = 'Council referral';
    return 1 if $old eq $referral || $new eq $referral;
    return 0;
}

around 'munge_sendreport_params' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    $self->$orig($row, $h, $params);

    if ($params->{To}[0][0] =~ /gov\.uk/) {
        # being sent to a council, so lookup the name on MapIt
        my ($lat, $lon) = ($row->latitude, $row->longitude);
        my $council = FixMyStreet::MapIt::call( 'point', "4326/$lon,$lat", type => 'DIS,UTA');
        ($council) = values %$council;
        my $name = $council->{name};

        # address email to the correct council name
        $params->{To}[0][1] = $name;

        # and store council name in the report extra for front end display
        $row->update_extra_metadata(sent_to_council => $name);
    } else {
        # being sent (back?) to the police, so remove the council name
        $row->update_extra_metadata(sent_to_council => undef);
    }
};

=item * Display district/city council name on report page if that's where the report was referred to

=cut

sub link_to_council_cobrand {
    my ( $self, $problem ) = @_;

    return $problem->get_extra_metadata('sent_to_council', '');
}

1;
