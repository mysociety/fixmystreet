package FixMyStreet::Cobrand::Hylte;
use base 'FixMyStreet::Cobrand::FixaMinGata';

use strict;
use warnings;
use utf8;

use Carp;
use mySociety::MaPit;
use DateTime;

sub council_area_id { return 68; }
sub council_area { return 'Hylte'; }
sub council_name { return 'Hylte kommun'; }
sub council_url { return 'hylte'; }

sub base_url { return 'https://hylte.fixamingata.se' }

sub site_key { 'hylte' }

sub areas_on_around { [68]; }

sub body {
    return FixMyStreet::DB->resultset("Body")->find({
        name => 'Hylte kommun'
    })
}

sub extra_reports_bodies {
    return FixMyStreet::DB->resultset("Body")->find({
        name => 'Trafikverket'
    })
}

sub problems_on_map_restriction {
    my ($self, $rs) = @_;

    return $rs if FixMyStreet->staging_flag('skip_checks');

    my $extra_bodies = $self->extra_reports_bodies();
    my @extra_bodies_ids = map { $_->id } $extra_bodies;
    my $bodies = [$self->body->id, @extra_bodies_ids];

    return $rs->to_body($bodies);
}

sub problems_restriction {
    my ($self, $rs) = @_;

    return $rs if FixMyStreet->staging_flag('skip_checks');

    my $extra_bodies = $self->extra_reports_bodies();
    my @extra_bodies_ids = map { $_->id } $extra_bodies;
    my $bodies = [$self->body->id, @extra_bodies_ids];

    return $rs->to_body($bodies);
}

sub updates_restriction {
    my ($self, $rs) = @_;

    return $rs if FixMyStreet->staging_flag('skip_checks');

    return $rs->to_body($self->body);
}

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        bounds => [ 56.8236518, 12.8207981, 57.1138647, 13.6935731 ],
    };
}

sub abuse_reports_only { 1 }

sub always_view_body_contribute_details { return; }

sub default_show_name { 0 }

sub recent {
    my $self = shift;

    return $self->problems->search({ areas => { 'like', '%,' . $self->body->id . ',%' } })->recent(@_);
}

1;
