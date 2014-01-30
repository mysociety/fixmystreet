use utf8;
package FixMyStreet::DB::Result::Comment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("comment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "comment_id_seq",
  },
  "problem_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "anonymous",
  { data_type => "boolean", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "website",
  { data_type => "text", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
  "confirmed",
  { data_type => "timestamp", is_nullable => 1 },
  "text",
  { data_type => "text", is_nullable => 0 },
  "photo",
  { data_type => "bytea", is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 0 },
  "cobrand",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "lang",
  { data_type => "text", default_value => "en-gb", is_nullable => 0 },
  "cobrand_data",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "mark_fixed",
  { data_type => "boolean", is_nullable => 0 },
  "mark_open",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "problem_state",
  { data_type => "text", is_nullable => 1 },
  "external_id",
  { data_type => "text", is_nullable => 1 },
  "extra",
  { data_type => "text", is_nullable => 1 },
  "send_fail_count",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "send_fail_reason",
  { data_type => "text", is_nullable => 1 },
  "send_fail_timestamp",
  { data_type => "timestamp", is_nullable => 1 },
  "whensent",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "problem",
  "FixMyStreet::DB::Result::Problem",
  { id => "problem_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-10 17:11:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:D/+UWcF7JO/EkCiJaAHUOw

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('extra');

use DateTime::TimeZone;
use Image::Size;
use Moose;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::Abuser';

my $tz = DateTime::TimeZone->new( name => "local" );

my $tz_f;
$tz_f = DateTime::TimeZone->new( name => FixMyStreet->config('TIME_ZONE') )
    if FixMyStreet->config('TIME_ZONE');

my $stz = sub {
    my ( $orig, $self ) = ( shift, shift );
    my $s = $self->$orig(@_);
    return $s unless $s && UNIVERSAL::isa($s, "DateTime");
    $s->set_time_zone($tz);
    $s->set_time_zone($tz_f) if $tz_f;
    return $s;
};

around created => $stz;
around confirmed => $stz;

# You can replace this text with custom code or comments, and it will be preserved on regeneration

sub check_for_errors {
    my $self = shift;

    my %errors = ();

    $errors{name} = _('Please enter your name')
        if !$self->name || $self->name !~ m/\S/;

    $errors{update} = _('Please enter a message')
      unless $self->text =~ m/\S/;

    # Bromley Council custom character limit
    if ( $self->text && $self->problem && $self->problem->bodies_str
        && $self->problem->bodies_str eq '2482' && length($self->text) > 1750 ) {
        $errors{update} = sprintf( _('Updates are limited to %s characters in length. Please shorten your update'), 1750 );
    }

    return \%errors;
}

=head2 confirm

Set state of comment to confirmed

=cut

sub confirm {
    my $self = shift;

    $self->state( 'confirmed' );
    $self->confirmed( \'ms_current_timestamp()' );
}

=head2 get_photo_params

Returns a hashref of details of any attached photo for use in templates.

=cut

sub get_photo_params {
    my $self = shift;
    return FixMyStreet::App::get_photo_params($self, 'c');
}

=head2 meta_problem_state

Returns a string suitable for display lookup in the update meta section.
Removes the '- council/user' bit from fixed states.

=cut

sub meta_problem_state {
    my $self = shift;

    my $state = $self->problem_state;
    $state =~ s/ -.*$//;

    return $state;
}

# we need the inline_constructor bit as we don't inherit from Moose
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
