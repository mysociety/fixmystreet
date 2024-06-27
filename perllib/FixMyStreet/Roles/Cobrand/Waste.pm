=head1 NAME

FixMyStreet::Roles::Cobrand::Waste - cobrand functions shared with all waste clients

=cut

package FixMyStreet::Roles::Cobrand::Waste;

use Moo::Role;
use Path::Tiny;

=head2 svg_container_sack

TYPE is either 'normal' or 'stripe'.

=cut

sub svg_container_sack {
    my ($type, $colour) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    $type = ($type eq 'stripe') ? 'sack-stripe' : 'sack';
    return {
        type => 'svg',
        data => $dir->child("$type.svg")->slurp_raw,
        colour => $colour,
    };
}

=head2 svg_container_bin

TYPE is either 'wheelie' or 'communal'.

=cut

sub svg_container_bin {
    my ($type, $colour_main, $colour_lid, $recycling_logo) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    return {
        type => 'svg',
        data => $dir->child("$type.svg")->slurp_raw,
        colour => $colour_main,
        lid_colour => $colour_lid,
        recycling_logo => $recycling_logo,
    };
}

sub svg_container_box {
    my ($colour, $recycling_logo) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    return {
        type => 'svg',
        data => $dir->child("box.svg")->slurp_raw,
        colour => $colour,
        recycling_logo => $recycling_logo,
    };
}

1;
