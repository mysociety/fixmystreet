=head1 NAME

FixMyStreet::Cobrand::NorthNorthants - code specific to the North Northamptonshire cobrand.

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::NorthNorthants;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use Moo;

# This cobrand is integrated with Kier's works manager but
# makes use of the same attributes as Alloy and validation
# checks for Confirm.
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::Open311Alloy';

=head2 Defaults

=over 4

=cut

sub council_area_id { return 164185; }
sub council_area { return 'North Northamptonshire'; }
sub council_name { return 'North Northamptonshire Council'; }
sub council_url { return 'northnorthants'; }

sub privacy_policy_url {
    'https://www.northnorthants.gov.uk/service-privacy-notices/street-doctor-privacy-notice'
}

sub enter_postcode_text { 'Enter a North Northamptonshire postcode, street name and area, or check an existing report number' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.2230321460526,-1.03613790739017',
        span   => '0.500177808954568,0.627284685758849',
        bounds => [ 51.9772677832173, -1.33234611641128, 52.4774455921719, -0.705061430652433 ],
    };
}

sub open311_extra_data_exclude { [ 'emergency' ] }

=item * Users with a northnorthants.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'northnorthants.gov.uk' }

=item * Includes all Northamptonshire reports before April 2021 and ones after within the boundary.

=cut

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    my $northamptonshire = FixMyStreet::Cobrand::Northamptonshire->new->body;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    $rs = $rs->search(
        {
            -or => [
                FixMyStreet::DB::ResultSet::Problem->body_query($self->body),
                -and => [
                    FixMyStreet::DB::ResultSet::Problem->body_query($northamptonshire),
                    -or => [
                        "$table.created" => { '<'  => '2021-04-01' }, # XXX check that North Northants want these
                        areas => {
                            'like' => [
                                '%,2398,%', # Corby.
                                '%,2396,%', # Kettering.
                                '%,2395,%', # Wellingborough.
                                '%,164185,%', # North Northamptonshire.
                            ],
                        },
                    ],
                ],
            ],
        }
    );
    return $rs;
}

=item * Staff users have permissions on Northamptonshire reports.

=cut

sub permission_body_override {
    my ($self, $body_ids) = @_;
    my $northamptonshire_id = FixMyStreet::Cobrand::Northamptonshire->new->body->id;
    my @out = map { $northamptonshire_id == $_ ? $self->body->id : $_} @$body_ids;
    return \@out;
}

=item * Uses the OSM geocoder.

=cut

sub get_geocoder { 'OSM' }

=item * /around map shows only open reports by default.

=cut

sub on_map_default_status { 'open' }

=item * We send a confirmation email when report is sent.

=cut

sub report_sent_confirmation_email { 'id' }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * We color defects blue.

=cut

sub is_defect {
    my ($self, $p) = @_;
    return $p->user_id == $self->body->comment_user_id;
}

sub pin_colour {
    my ($self, $p, $context) = @_;
    return 'blue' if $self->is_defect($p);
    return $self->SUPER::pin_colour($p, $context);
}

=item * We include external IDs in dashboard exports.

=cut

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

=item * We limit report titles to 120 characters.

=cut

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->title ) > 120 ) {
        $errors->{title} = sprintf( _('Summaries are limited to %s characters in length. Please shorten your summary'), 120 );
    }
}

=item * We allow staff to bypass stoppers.

=cut

sub staff_ignore_form_disable_form {
    my $self = shift;

    my $c = $self->{c};

    return $c->user_exists
        && $c->user->belongs_to_body( $self->body->id );
}


=item * We always apply state changes from Open311 updates.

=cut

sub open311_get_update_munging {
    my ($self, $comment) = @_;

    my $state = $comment->problem_state;
    my $p = $comment->problem;
    if ($state && $p->state ne $state && $p->is_visible) {
        $p->state($state);
    }
}

=item * We don't send updates for comments made by bodies.

=cut

sub should_skip_sending_update {
    my ($self, $comment) = @_;

    my $p = $comment->problem;
    my %body_users = map { $_->comment_user_id => 1 } values %{ $p->bodies };
    if ( $body_users{ $p->user->id } ) {
        return 1;
    }
    return 0;
}

=pod

=back

=cut

1;
