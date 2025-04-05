package FixMyStreet::Roles::EnforcePhotoSizeOpen311PreSend;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::EnforcePhotoSizeOpen311PreSend - limit report photo sizes on open311 pre-send

=head1 SYNOPSIS

Applied to a cobrand class to shrink any images larger than a given size as an open311 pre-send action.

Oversized images are repeatedly shrunk until they conform.

A 'photo_size_limit_applied_<bytes>' metadata flag is set on the report to indicate it has been processed
and prevent reprocessing.

=cut

=head1 REQUIRED METHODS

=cut

=head2 per_photo_size_limit_for_report_in_bytes

Takes the report and the number of images.
Returns the max number of bytes for each photo on the report.
0 indicates no max to apply.

=cut

requires 'per_photo_size_limit_for_report_in_bytes';

sub open311_update_missing_data { }

after open311_update_missing_data => sub {
    my ($self, $report, $h, $contact) = @_;
    my $photoset = $report->get_photoset;
    return unless $photoset->num_images > 0;

    my $limit = $self->per_photo_size_limit_for_report_in_bytes($report, $photoset->num_images);
    return unless $limit > 0;

    my $limit_applied_flag = "photo_size_limit_applied_" . $limit;
    return if $report->get_extra_metadata($limit_applied_flag);

    # Keep shrinking oversized images to 90% of their original size until they conform.
    my ($new, $shrunk) = $photoset->shrink_all_to_size($limit, 90);

    if ($shrunk) {
        $report->photo($new->data);
    }

    $report->set_extra_metadata( $limit_applied_flag => 1 );
};

1;
