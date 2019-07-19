package FixMyStreet::Cobrand::IsleOfWight;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2636 }
sub council_area { 'Isle of Wight' }
sub council_name { 'Island Roads' }
sub council_url { 'isleofwight' }
sub all_reports_single_body { { name => "Isle of Wight Council" } }
sub link_to_council_cobrand { "Island Roads" }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an ' . $self->council_area . ' postcode, or street name and area';
}

sub on_map_default_status { 'open' }

sub send_questionnaires { 0 }

sub map_type { 'OSM' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '50.675761,-1.296571',
        bounds => [ 50.574653, -1.591732, 50.767567, -1.062957 ],
    };
}

sub updates_disallowed {
    my ($self, $problem) = @_;

    my $c = $self->{c};
    return 0 if $c->user_exists && $c->user->id eq $problem->user->id;
    return 1;
}

sub get_geocoder { 'OSM' }

sub open311_get_update_munging {
    my ($self, $comment) = @_;

    # If we've received an update via Open311 that's closed
    # or fixed the report, also close it to updates.
    $comment->problem->set_extra_metadata(closed_updates => 1)
        if !$comment->problem->is_open;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    $row->set_extra_fields(@$extra);
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    if ($comment->mark_fixed) {
        $params->{description} = "[The customer indicated that this issue had been fixed]\n\n" . $params->{description};
    }

    $params->{description} = "FMS-Update: " . $params->{description};
}

1;
