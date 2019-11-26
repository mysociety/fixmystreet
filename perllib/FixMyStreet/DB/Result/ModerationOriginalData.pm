use utf8;
package FixMyStreet::DB::Result::ModerationOriginalData;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "FilterColumn",
  "FixMyStreet::InflateColumn::DateTime",
  "FixMyStreet::EncodedColumn",
);
__PACKAGE__->table("moderation_original_data");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "moderation_original_data_id_seq",
  },
  "problem_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "comment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "detail",
  { data_type => "text", is_nullable => 1 },
  "photo",
  { data_type => "bytea", is_nullable => 1 },
  "anonymous",
  { data_type => "boolean", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "extra",
  { data_type => "text", is_nullable => 1 },
  "category",
  { data_type => "text", is_nullable => 1 },
  "latitude",
  { data_type => "double precision", is_nullable => 1 },
  "longitude",
  { data_type => "double precision", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "comment",
  "FixMyStreet::DB::Result::Comment",
  { id => "comment_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE,",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "problem",
  "FixMyStreet::DB::Result::Problem",
  { id => "problem_id" },
  { is_deferrable => 0, on_delete => "CASCADE,", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FLKiZELcfBcc9VwHU2MZYQ

use Moo;
use FixMyStreet::Template::SafeString;
use Text::Diff;
use Data::Dumper;

with 'FixMyStreet::Roles::Extra';

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('extra');

sub admin_log {
    my $self = shift;
    my $rs = $self->result_source->schema->resultset("AdminLog");
    my $log = $rs->search({
        object_id => $self->id,
        object_type => 'moderation',
    })->first;
    return $log;
}

sub compare_with {
    my ($self, $other) = @_;
    if ($self->comment_id) {
        my $new_detail = $other->can('text') ? $other->text : $other->detail;
        return {
            detail => string_diff($self->detail, $new_detail),
            photo => $self->compare_photo($other),
            anonymous => $self->compare_anonymous($other),
            extra => $self->compare_extra($other),
        };
    }
    return {
        title => string_diff($self->title, $other->title),
        detail => string_diff($self->detail, $other->detail),
        photo => $self->compare_photo($other),
        anonymous => $self->compare_anonymous($other),
        coords => $self->compare_coords($other),
        category => string_diff($self->category, $other->category, single => 1),
        extra => $self->compare_extra($other),
    }
}

sub compare_anonymous {
    my ($self, $other) = @_;
    string_diff(
        $self->anonymous ? _('Yes') : _('No'),
        $other->anonymous ? _('Yes') : _('No'),
    );
}

sub compare_coords {
    my ($self, $other) = @_;
    return '' unless $self->latitude && $self->longitude;
    my $old = join ',', $self->latitude, $self->longitude;
    my $new = join ',', $other->latitude, $other->longitude;
    string_diff($old, $new, single => 1);
}

sub compare_photo {
    my ($self, $other) = @_;

    my $old = $self->photo || '';
    my $new = $other->photo || '';
    return '' if $old eq $new;

    $old = [ split /,/, $old ];
    $new = [ split /,/, $new ];

    my $diff = Algorithm::Diff->new( $old, $new );
    my (@added, @deleted);
    while ( $diff->Next ) {
        next if $diff->Same;
        push @deleted, $diff->Items(1);
        push @added, $diff->Items(2);
    }
    my $s = (join ', ', map {
            "<del style='background-color:#fcc'>$_</del>";
        } @deleted) . (join ', ', map {
            "<ins style='background-color:#cfc'>$_</ins>";
        } @added);
    return FixMyStreet::Template::SafeString->new($s);
}

sub compare_extra {
    my ($self, $other) = @_;

    my $old = $self->get_extra_metadata;
    my $new = $other->get_extra_metadata;

    my $both = { %$old, %$new };
    my @all_keys = sort keys %$both;
    my @s;
    foreach (@all_keys) {
        if ($old->{$_} && $new->{$_}) {
            push @s, string_diff("$_ = $old->{$_}", "$_ = $new->{$_}");
        } elsif ($new->{$_}) {
            push @s, string_diff("", "$_ = $new->{$_}");
        } else {
            push @s, string_diff("$_ = $old->{$_}", "");
        }
    }
    return join ', ', grep { $_ } @s;
}

sub extra_diff {
    my ($self, $other, $key) = @_;
    my $o = $self->get_extra_metadata($key);
    my $n = $other->get_extra_metadata($key);
    return string_diff($o, $n);
}

sub string_diff {
    my ($old, $new, %options) = @_;

    return '' if $old eq $new;

    $old = FixMyStreet::Template::html_filter($old);
    $new = FixMyStreet::Template::html_filter($new);

    if ($options{single}) {
        return unless $old;
        $old = [ $old ];
        $new = [ $new ];
    }
    $old = [ split //, $old ] unless ref $old;
    $new = [ split //, $new ] unless ref $new;
    my $diff = Algorithm::Diff->new( $old, $new );
    my $string;
    while ($diff->Next) {
        my $d = $diff->Diff;
        if ($d & 1) {
            my $deleted = join '', $diff->Items(1);
            $string .= "<del style='background-color:#fcc'>$deleted</del>";
        }
        my $inserted = join '', $diff->Items(2);
        if ($d & 2) {
            $string .= "<ins style='background-color:#cfc'>$inserted</ins>";
        } else {
            $string .= $inserted;
        }
    }
    return FixMyStreet::Template::SafeString->new($string);
}

1;
