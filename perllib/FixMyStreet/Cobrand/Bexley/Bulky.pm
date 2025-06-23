=head1 NAME

FixMyStreet::Cobrand::Bexley::Bulky - code specific to Bexley WasteWorks Bulky Waste

=cut

package FixMyStreet::Cobrand::Bexley::Bulky;

use DateTime::Format::Strptime;
use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

sub bulky_allowed_property {
    my ($self, $property) = @_;
    my $class = $property->{class} || '';
    return $class =~ /^RD/ ? 1 : 0;
}

sub bulky_cancellation_cutoff_time { { hours => 23, minutes => 59, days_before => 2, working_days => 1 } }
sub bulky_collection_time { { hours => 6, minutes => 0 } }
sub bulky_collection_window_days { 56 }

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('collection_date'));
}

sub bulky_free_collection_available { 0 }

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    my $parser = DateTime::Format::Strptime->new( pattern => '%F', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

# We will send and then cancel if payment not received

sub bulky_send_before_payment { 1 }

# No earlier/later (make this Peterborough only?)

sub bulky_hide_later_dates { 1 }

1;
