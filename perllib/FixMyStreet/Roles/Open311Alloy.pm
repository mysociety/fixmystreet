package FixMyStreet::Roles::Open311Alloy;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::Open311Alloy - role for adding various Open311 things specific to Alloy

=cut

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
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
        { name => 'category',
          value => $row->category },
    ];

    return $open311_only;
}

1;
