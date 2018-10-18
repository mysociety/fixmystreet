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

    if ( length( $report->name ) > 40 ) {
        $errors->{name} = sprintf( _('Names are limited to %d characters in length.'), 40 );
    }

    return $errors;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra, { name => 'external_id', value => $row->id };
    push @$extra, { name => 'title', value => $row->title };
    push @$extra, { name => 'description', value => $row->detail };

    if ($h->{closest_address}) {
        push @$extra, { name => 'closest_address', value => "$h->{closest_address}" }
    }
    $row->set_extra_fields( @$extra );

    $params->{multi_photos} = 1;
}

sub example_places {
    return ( 'LE15 6HP', 'High Street', 'Oakham' );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        bounds => [52.524755166940075, -0.8217480325342802, 52.7597945702699, -0.4283542728893742]
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'yellow';
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

1;
