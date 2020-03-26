package FixMyStreet::Roles::BoroughEmails;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::BoroughEmails - role for directing reports according to the
borough_email_addresses COBRAND_FEATURE

=cut

=head2 munge_sendreport_params

TfL want reports made in certain categories sent to different email addresses
depending on what London Borough they were made in. To achieve this we have
some config in COBRAND_FEATURES that specifies what address to direct reports
to based on the MapIt area IDs it's in.

Contacts that use this technique have a short code in their email field,
which is looked up in the `borough_email_addresses` hash.

For example, if you wanted Pothole reports in Bromley and Barnet to be sent to
one email address, and Pothole reports in Hounslow to be sent to another,
create a contact with category = "Potholes" and email = "BOROUGHPOTHOLES" and
use the following config in general.yml:

COBRAND_FEATURES:
  borough_email_addresses:
    tfl:
      BOROUGHPOTHOLES:
        - email: bromleybarnetpotholes@example.org
          areas:
            - 2482 # Bromley
            - 2489 # Barnet
        - email: hounslowpotholes@example.org
          areas:
            - 2483 # Hounslow

=cut

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    my $addresses = $self->feature('borough_email_addresses');
    return unless $addresses;

    my @report_areas = grep { $_ } split ',', $row->areas;

    my $to = $params->{To};
    my @munged_to = ();
    for my $recip ( @$to ) {
        my ($email, $name) = @$recip;
        if (my $teams = $addresses->{$email}) {
            for my $team (@$teams) {
                my %team_area_ids = map { $_ => 1 } @{ $team->{areas} };
                if ( grep { $team_area_ids{$_} } @report_areas ) {
                    $recip = [
                        $team->{email},
                        $name
                    ];
                }
            }
        }
        push @munged_to, $recip;
    }
    $params->{To} = \@munged_to;
}

1;
