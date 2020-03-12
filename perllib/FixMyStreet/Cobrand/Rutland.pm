package FixMyStreet::Cobrand::Rutland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2600; }
sub council_area { return 'Rutland'; }
sub council_name { return 'Rutland County Council'; }
sub council_url { return 'rutland'; }

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->title ) > 254 ) {
        $errors->{title} = sprintf( _('Summaries are limited to %s characters in length. Please shorten your summary'), 254 );
    }

    if ( length( $report->name ) > 40 ) {
        $errors->{name} = sprintf( _('Names are limited to %d characters in length.'), 40 );
    }

    return $errors;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
}

sub open311_extra_data {
    my ($self, $row, $h, $extra) = @_;

    return [
        { name => 'external_id', value => $row->id },
        { name => 'title', value => $row->title },
        { name => 'description', value => $row->detail },
        $h->{closest_address} ? { name => 'closest_address', value => "$h->{closest_address}" } : (),
    ];
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        bounds => [52.524755166940075, -0.8217480325342802, 52.7597945702699, -0.4283542728893742]
    };
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

sub on_map_default_status { 'open' }

1;
