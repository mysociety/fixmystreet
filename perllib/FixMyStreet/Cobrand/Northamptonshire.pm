=head1 NAME

FixMyStreet::Cobrand::Northamptonshire - code specific to the Northamptonshire cobrand

=head1 SYNOPSIS

Northamptonshire has split into West and North, this is left around so that
those cobrands can still locate old reports sent to this cobrand's body and for
getting/sending updates on those reports.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Northamptonshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';

=head2 Defaults

=over 4

=cut

sub council_area_id { [ 164185, 164186 ] }
sub council_area { 'Northamptonshire' }
sub council_name { 'Northamptonshire Highways' }
sub council_url { 'northamptonshire' }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * If we've received an update via Open311, let us always take its state change

=cut

sub open311_get_update_munging {
    my ($self, $comment) = @_;

    my $state = $comment->problem_state;
    my $p = $comment->problem;
    if ($state && $p->state ne $state && $p->is_visible) {
        $p->state($state);
    }
}

=item * Do not send updates on reports made by the comment user, or sent too long ago.

=back

=cut

sub should_skip_sending_update {
    my ($self, $comment) = @_;

    my $p = $comment->problem;
    my %body_users = map { $_->comment_user_id => 1 } values %{ $p->bodies };
    if ( $body_users{ $p->user->id } ) {
        return 1;
    }

    my $move = DateTime->new(year => 2022, month => 9, day => 12, hour => 9, minute => 30, time_zone => FixMyStreet->local_time_zone);
    return 1 if $p->whensent < $move;

    return 0;
}

1;
