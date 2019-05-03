package DBIx::Class::FixMyStreet::InflateColumn::DateTime;

use strict;
use warnings;
use base qw/DBIx::Class::InflateColumn::DateTime/;
use FixMyStreet;
use namespace::clean;

sub _post_inflate_datetime {
    my $self = shift;
    my $dt = $self->next::method(@_);
    FixMyStreet->set_time_zone($dt);
    return $dt;
}

sub _pre_deflate_datetime {
    my $self = shift;
    my $dt = $self->next::method(@_);
    $dt->set_time_zone(FixMyStreet->local_time_zone);
    return $dt;
}

1;

__END__

=head1 NAME

DBIx::Class::FixMyStreet::InflateColumn::DateTime

=head1 DESCRIPTION

This acts the same as DBIx::Class::InflateColumn::DateTime, as if a
'local' timezone object was attached to every datetime column, plus
alters the timezone upon inflation to the configured timezone if it
has been set, and uses a singleton to prevent needless disc access.
