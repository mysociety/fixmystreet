package FixMyStreet::Roles::ConfirmOpen311;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::ConfirmOpen311 - role for adding various Open311 things specific to Confirm

=cut

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
}

sub open311_extra_data {
    my ($self, $row, $h, $extra) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
    ];

    # Reports made via FMS.com or the app probably won't have a USRN
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $site_code = $self->lookup_site_code($row)) {
            push @$extra,
                { name => 'site_code',
                value => $site_code };
        }
    }

    return $open311_only;
}

1;
