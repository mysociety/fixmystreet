package FixMyStreet::Roles::ConfirmOpen311;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::ConfirmOpen311 - role for adding various Open311 things specific to Confirm

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
}

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    # Reports made via FMS.com or the app probably won't have a USRN
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $site_code = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'site_code', value => $site_code });
        }
    }
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
    ];

    return $open311_only;
}

=head2 open311_munge_update_params

We pass any category change to Confirm, if enabled by cobrand.

=cut

sub open311_munge_update_params {
    my ( $self, $params, $comment ) = @_;

    return unless $self->call_hook('open311_send_category_change');

    my $p = $comment->problem;

    if ( $comment->text =~ /Category changed/ ) {
        if ( my $service_code = $p->get_extra_field_value('_wrapped_service_code')  || $p->contact->email ) {
            $params->{service_code} = $service_code;
        }
    }
}

1;
