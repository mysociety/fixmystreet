package FixMyStreet::Roles::Cobrand::Northants;

use v5.14;
use warnings;
use Moo::Role;
use FixMyStreet::DB;


=head1 NAME

FixMyStreet::Roles::Cobrand::Northants - shared code between West & Northants cobrands

=cut

sub open311_extra_data_exclude { [ 'emergency' ] }


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
                        "$table.created" => { '<'  => '2021-04-01' },
                        areas => {
                            'like' => $self->_problems_restriction_areas,
                        },
                    ],
                ],
            ],
        }
    );
    return $rs;
}

sub updates_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    my $northamptonshire = FixMyStreet::Cobrand::Northamptonshire->new->body;
    return $rs->to_body([ $northamptonshire->id, $self->body->id ]);
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

=item * A report is a defect if it was fetched from Open311.

=cut

sub is_defect {
    my ($self, $p) = @_;
    return $p->user_id == $self->body->comment_user_id;
}

=item * Defects are coloured blue.

=cut

around 'pin_colour' => sub {
    my ($orig, $self, $p, $context) = @_;
    return 'blue' if $self->is_defect($p);
    return $self->$orig($p, $context);
};

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

has '+max_title_length' => ( is => 'ro', default => 120 );

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

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker ),
        FixMyStreet->path_to( 'templates/web/northants' ),
        FixMyStreet->path_to( 'templates/web/fixmystreet-uk-councils' ),
    ];
}

sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    my $paths = [
        FixMyStreet->path_to( 'templates', 'email', $self->moniker ),
        FixMyStreet->path_to( 'templates', 'email', 'northants' ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet-uk-councils' ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
    ];
    return $paths;
}


=pod

=back

=cut

1;
