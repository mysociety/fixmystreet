=head1 NAME

FixMyStreet::Cobrand::Aberdeenshire - code specific to the Aberdeenshire cobrand

=head1 SYNOPSIS

We integrate with Aberdeenshire's Confirm back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Aberdeenshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use JSON::MaybeXS;
use LWP::UserAgent;
use Moo;

=pod

Confirm backends expect some extra values and have some maximum lengths for
certain fields. These roles implement that behaviour.

=cut

with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

=head2 Defaults

=over 4

=cut

sub council_area_id { '2648' }
sub council_area { 'Aberdeenshire' }
sub council_name { 'Aberdeenshire Council' }
sub council_url { 'aberdeenshire' }

=item * Users with a Aberdeenshire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'aberdeenshire.gov.uk' }

=item * Aberdeenshire use their own privacy policy, and their own contact form

=cut

sub privacy_policy_url { 'https://publications.aberdeenshire.gov.uk/acblobstorage/168aac73-5139-4622-a980-7a9436c3e0a3/cusersspellascdocumentsroads-pn.pdf' }

=item * Single sign on is enabled from the cobrand feature 'oidc_login'

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * Extract the user's details from the OIDC token

=cut

sub user_from_oidc {
    my ($self, $payload, $access_token) = @_;

    my $name = '';
    my $email = '';

    # Payload doesn't include user's name so fetch it from
    # the OIDC userinfo endpoint.
    my $cfg = $self->feature('oidc_login');
    if ($access_token && $cfg->{userinfo_uri}) {
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get(
            $cfg->{userinfo_uri},
            Authorization => 'Bearer ' . $access_token,
        );
        my $user = decode_json($response->decoded_content);
        if ($user->{fname} && $user->{lname}) {
            $name = join(" ", $user->{fname}, $user->{lname});
        }
        if ($user->{emailaddress}) {
            $email = $user->{emailaddress};
        }
    }

    # In case we didn't get email from the claims above, default to value
    # present in payload. NB name is not available in this manner.
    $email ||= $payload->{sub} ? lc($payload->{sub}) : '';

    return ($name, $email);
}

sub abuse_reports_only { 1 }

=item * Users can not reopen reports

=cut

sub reopening_disallowed {
    my ($self, $problem) = @_;

    # Only staff can reopen reports.
    my $c = $self->{c};
    my $user = $c->user;
    return 0 if ($c->user_exists && $user->from_body && $user->from_body->cobrand_name eq $self->council_name);
    return 1;
}

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

=head2 open311_update_missing_data

Unlike the ConfirmOpen311 role, we want to fetch a central asset ID here, not a
site code.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    # In case the client hasn't given us a central asset ID, look up the
    # closest asset from the WFS service at the point we're sending the report
    if (!$row->get_extra_field_value('central_asset_id')) {
        if (my $id = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'central_asset_id', value => $id });
        }
    }

    # Q29 ('Insurance form requested ?') is required by Confirm but hidden from
    # the user, so here we give it a default value (BLNK = 'Blank').
    if ($contact->get_extra_field(code => 'Q29')  && !$row->get_extra_field_value('Q29')) {
        $row->update_extra_field({ name => 'Q29', value => "BLNK" });
    }
}

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '57.24185467,-2.62923456',
        span   => '0.95461349,2.03725374',
        bounds => [
            56.74712850, -3.80164643,
            57.70174199, -1.76439269,
        ],
    };
}

sub lookup_site_code {} # XXX waiting for asset layer

1;
