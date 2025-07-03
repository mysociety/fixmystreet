=head1 NAME

FixMyStreet::Cobrand::Northamptonshire - code specific to the Northamptonshire cobrand [incomplete]

=head1 SYNOPSIS



=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Northamptonshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::Open311Alloy';

=head2 Defaults

=over 4

=cut

sub council_area_id { [ 164185, 164186 ] }
sub council_area { 'Northamptonshire' }
sub council_name { 'Northamptonshire Highways' }
sub council_url { 'northamptonshire' }

=item * Users with a northamptonshire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'northamptonshire.gov.uk' }

=item * This is a two-tier authority.

=cut

sub is_two_tier { 1 }

=item * /around map shows only open reports by default.

=cut

sub on_map_default_status { 'open' }

=item * We send a confirmation email when report is sent.

=cut

sub report_sent_confirmation_email { 'id' }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

sub enter_postcode_text { 'Enter a Northamptonshire postcode, street name and area, or check an existing report number' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.30769080650276,-0.8647071378799923',
        bounds => [ 51.97726778979222, -1.332346116362747, 52.643600776698605, -0.3416080408721255 ],
    };
}

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { 'body.name' => [ $self->council_name, 'National Highways' ] } );
}

sub is_defect {
    my ($self, $p) = @_;
    return $p->user_id == $self->body->comment_user_id;
}

sub pin_colour {
    my ($self, $p, $context) = @_;
    return 'blue' if $self->is_defect($p);
    return $self->SUPER::pin_colour($p, $context);
}

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    # Northamptonshire don't want to show district/borough reports
    # on the site
    return $self->problems_restriction($rs);
}

sub privacy_policy_url {
    'https://www3.northamptonshire.gov.uk/councilservices/council-and-democracy/transparency/information-policies/privacy-notice/place/Pages/street-doctor.aspx'
}

sub open311_extra_data_exclude { [ 'emergency' ] }

sub open311_get_update_munging {
    my ($self, $comment) = @_;

    # If we've received an update via Open311, let us always take its state change
    my $state = $comment->problem_state;
    my $p = $comment->problem;
    if ($state && $p->state ne $state && $p->is_visible) {
        $p->state($state);
    }
}

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

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->title ) > 120 ) {
        $errors->{title} = sprintf( _('Summaries are limited to %s characters in length. Please shorten your summary'), 120 );
    }
}

sub staff_ignore_form_disable_form {
    my $self = shift;

    my $c = $self->{c};

    return $c->user_exists
        && $c->user->belongs_to_body( $self->body->id );
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        external_id => 'External ID',
    );

    return if $csv->dbi;

    $csv->csv_extra_data(sub {
        my $report = shift;

        return {
            external_id => $report->external_id,
        };
    });
}

1;
