=head1 NAME

FixMyStreet::Cobrand::Bristol - code specific to the Bristol cobrand

=head1 SYNOPSIS

Bristol is a unitary authority, with its own Open311 server.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Bristol;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

=head2 Defaults

=over 4

=cut

sub council_area_id { return 2561; }
sub council_area { return 'Bristol'; }
sub council_name { return 'Bristol County Council'; }
sub council_url { return 'bristol'; }

=item * Bristol use the OS Maps API at all zoom levels.

=cut

sub map_type { 'OS::API' }

=item * Users with a bristol.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'bristol.gov.uk' }

=item * Bristol uses the OSM geocoder

=cut

sub get_geocoder { 'OSM' }

=item * We do not send questionnaires.

=back

=cut

sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bristol';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.4526044866206,-2.7706173308649',
        span   => '0.202810508012753,0.60740886659825',
        bounds => [ 51.3415749466466, -3.11785543094126, 51.5443854546593, -2.51044656434301 ],
    };
}

=head2 pin_colour

Bristol uses the following pin colours:

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

use constant ROADWORKS_CATEGORY => 'Inactive roadworks';

=head2 categories_restriction

Categories covering the Bristol area have a mixture of Open311 and Email send
methods. Bristol only want Open311 categories to be visible on their cobrand,
not the email categories from FMS.com. We've set up the Email categories with a
devolved send_method, so can identify Open311 categories as those which have a
blank send_method. Also National Highways categories have a blank send_method.
Additionally the special roadworks category should be shown.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { -or => [
        'me.category' => ROADWORKS_CATEGORY, # Special new category
        'me.send_method' => undef, # Open311 categories
        'me.send_method' => '', # Open311 categories that have been edited in the admin
    ] } );
}

=head2 open311_config

Bristol's endpoint requires an email address, so flag to always send one (with
a fallback if one not provided).

=cut

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{always_send_email} = 1;
}

=head2 open311_contact_meta_override

We need to mark some of the attributes returned by Bristol's Open311 server
as hidden or server_set.

=cut

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    my %server_set = (easting => 1, northing => 1);
    my %hidden_field = (usrn => 1, asset_id => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
        $_->{automated} = 'hidden_field' if $hidden_field{$_->{code}};
    }
}

=head2 post_report_sent

Bristol have a special Inactive roadworks category; any reports made in that
category are automatically closed, with an update with explanatory text added.

=cut

sub post_report_sent {
    my ($self, $problem) = @_;

    if ($problem->category eq ROADWORKS_CATEGORY) {
        my @include_path = @{ $self->path_to_web_templates };
        push @include_path, FixMyStreet->path_to( 'templates', 'web', 'default' );
        my $tt = FixMyStreet::Template->new({
            INCLUDE_PATH => \@include_path,
            disable_autoescape => 1,
        });
        my $text;
        $tt->process('report/new/roadworks_text.html', {}, \$text);

        $problem->update({
            state => 'closed'
        });
        $problem->add_to_comments({
            text => $text,
            user_id => $self->body->comment_user_id,
            problem_state => 'closed',
            cobrand => $problem->cobrand,
            send_state => 'processed',
        });
    }
}

1;
