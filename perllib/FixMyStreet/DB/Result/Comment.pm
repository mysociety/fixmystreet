use utf8;
package FixMyStreet::DB::Result::Comment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;
use FixMyStreet::Template;

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
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
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
__PACKAGE__->might_have(
  "moderation_original_data",
  "FixMyStreet::DB::Result::ModerationOriginalData",
  { "foreign.comment_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2015-08-13 16:33:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZR+YNA1Jej3s+8mr52iq6Q
#

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('extra');

use Moo;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::Abuser',
     'FixMyStreet::Roles::Extra',
     'FixMyStreet::Roles::PhotoSet';

my $stz = sub {
    my ( $orig, $self ) = ( shift, shift );
    my $s = $self->$orig(@_);
    return $s unless $s && UNIVERSAL::isa($s, "DateTime");
    FixMyStreet->set_time_zone($s);
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
    if ( $self->text && $self->problem && $self->problem->bodies_str) {
        if ($self->problem->to_body_named('Bromley') && length($self->text) > 1750) {
            $errors{update} = sprintf( _('Updates are limited to %s characters in length. Please shorten your update'), 1750 );
        }
    }

    return \%errors;
}

=head2 confirm

Set state of comment to confirmed

=cut

sub confirm {
    my $self = shift;

    $self->state( 'confirmed' );
    $self->confirmed( \'current_timestamp' );
}

sub url {
    my $self = shift;
    return "/report/" . $self->problem_id . '#update_' . $self->id;
}

sub photos {
    my $self = shift;
    my $photoset = $self->get_photoset;
    my $i = 0;
    my $id = $self->id;
    my @photos = map {
        my $cachebust = substr($_, 0, 8);
        my ($hash, $format) = split /\./, $_;
        {
            id => $hash,
            url_temp => "/photo/temp.$hash.$format",
            url_temp_full => "/photo/fulltemp.$hash.$format",
            url => "/photo/c/$id.$i.$format?$cachebust",
            url_full => "/photo/c/$id.$i.full.$format?$cachebust",
            idx => $i++,
        }
    } $photoset->all_ids;
    return \@photos;
}

=head2 latest_moderation_log_entry

Return most recent ModerationLog object

=cut

sub latest_moderation_log_entry {
    my $self = shift;
    return $self->admin_log_entries->search({ action => 'moderation' }, { order_by => { -desc => 'id' } })->first;
}

__PACKAGE__->has_many(
  "admin_log_entries",
  "FixMyStreet::DB::Result::AdminLog",
  { "foreign.object_id" => "self.id" },
  {
      cascade_copy => 0, cascade_delete => 0,
      where => { 'object_type' => 'update' },
  }
);

# we already had the `moderation_original_data` rel above, as inferred by
# Schema::Loader, but that doesn't know about the problem_id mapping, so we now
# (slightly hackishly) redefine here:
#
# we also add cascade_delete, though this seems to be insufficient.
#
# TODO: should add FK on moderation_original_data field for this, to get S::L to
# pick up without hacks.

__PACKAGE__->might_have(
  "moderation_original_data",
  "FixMyStreet::DB::Result::ModerationOriginalData",
  { "foreign.comment_id" => "self.id",
    "foreign.problem_id" => "self.problem_id",
  },
  { cascade_copy => 0, cascade_delete => 1 },
);

=head2 meta_line

Returns a string to be used on a report update, describing some of the metadata
about an update

=cut

sub meta_line {
    my ( $self, $c ) = @_;

    my $meta = '';

    if ($self->anonymous or !$self->name) {
        $meta = sprintf( _( 'Posted anonymously at %s' ), Utils::prettify_dt( $self->confirmed ) )
    } elsif ($self->user->from_body) {
        my $user_name = FixMyStreet::Template::html_filter($self->user->name);
        my $body = $self->user->body;
        if ($body eq 'Bromley Council') {
            $body = "$body <img src='/cobrands/bromley/favicon.png' alt=''>";
        } elsif ($body eq 'Royal Borough of Greenwich') {
            $body = "$body <img src='/cobrands/greenwich/favicon.png' alt=''>";
        }
        my $can_view_contribute = $c->user_exists && $c->user->has_permission_to('view_body_contribute_details', $self->problem->bodies_str_ids);
        if ($self->text) {
            if ($can_view_contribute) {
                $meta = sprintf( _( 'Posted by <strong>%s</strong> (%s) at %s' ), $body, $user_name, Utils::prettify_dt( $self->confirmed ) );
            } else {
                $meta = sprintf( _( 'Posted by <strong>%s</strong> at %s' ), $body, Utils::prettify_dt( $self->confirmed ) );
            }
        } else {
            if ($can_view_contribute) {
                $meta = sprintf( _( 'Updated by <strong>%s</strong> (%s) at %s' ), $body, $user_name, Utils::prettify_dt( $self->confirmed ) );
            } else {
                $meta = sprintf( _( 'Updated by <strong>%s</strong> at %s' ), $body, Utils::prettify_dt( $self->confirmed ) );
            }
        }
    } else {
        $meta = sprintf( _( 'Posted by %s at %s' ), FixMyStreet::Template::html_filter($self->name), Utils::prettify_dt( $self->confirmed ) )
    }

    if ($self->get_extra_metadata('defect_raised')) {
        $meta .= ', ' . _( 'and a defect raised' );
    }

    return $meta;
};

sub problem_state_display {
    my ( $self, $c ) = @_;

    my $update_state = '';
    my $cobrand = $c->cobrand->moniker;

    if ($self->mark_fixed) {
        return FixMyStreet::DB->resultset("State")->display('fixed', 1);
    } elsif ($self->mark_open)  {
        return FixMyStreet::DB->resultset("State")->display('confirmed', 1);
    } elsif ($self->problem_state) {
        my $state = $self->problem_state;
        if ($state eq 'not responsible') {
            $update_state = _( "not the council's responsibility" );
            if ($cobrand eq 'bromley' || $self->problem->to_body_named('Bromley')) {
                $update_state = 'third party responsibility';
            }
        } else {
            $update_state = FixMyStreet::DB->resultset("State")->display($state, 1);
        }
    }

    return $update_state;
}

1;
