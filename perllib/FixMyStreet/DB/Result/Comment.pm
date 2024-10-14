use utf8;
package FixMyStreet::DB::Result::Comment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "FilterColumn",
  "+FixMyStreet::DB::JSONBColumn",
  "FixMyStreet::InflateColumn::DateTime",
  "FixMyStreet::EncodedColumn",
);
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
    default_value => \"CURRENT_TIMESTAMP",
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
  { data_type => "jsonb", is_nullable => 1 },
  "send_state",
  { data_type => "text", default_value => "unprocessed", is_nullable => 0 },
  "send_fail_count",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "send_fail_reason",
  { data_type => "text", is_nullable => 1 },
  "send_fail_timestamp",
  { data_type => "timestamp", is_nullable => 1 },
  "whensent",
  { data_type => "timestamp", is_nullable => 1 },
  "private_email_text",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "moderation_original_datas",
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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2023-05-10 17:09:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8R6NBLI7UWER4zQ6sM7G5Q
#

use Moo;
use FixMyStreet::Template::SafeString;
use namespace::clean -except => [ 'meta' ];
use FixMyStreet::Template;

with 'FixMyStreet::Roles::DB::Abuser',
     'FixMyStreet::Roles::DB::Extra',
     'FixMyStreet::Roles::DB::Moderation',
     'FixMyStreet::Roles::DB::PhotoSet';

=head2 FOREIGNBUILDARGS

Make sure that when creating a new Comment object, certain
other fields are set based upon the supplied data.

=cut

sub FOREIGNBUILDARGS {
    my ($class, $opts) = @_;

    if (my $user = $opts->{user}) {
        my $name;
        if ($user->is_superuser) {
            $opts->{extra}->{is_superuser} = 1;
            $name = _('an administrator');
        } elsif (my $body = $user->from_body) {
            $opts->{extra}->{is_body_user} = $body->id;
            $name = $body->name;
            $name = 'Island Roads' if $name eq 'Isle of Wight Council';
        } else {
            $name = $user->name;
        }
        $opts->{name} //= $name;
    }

    $opts->{anonymous} //= 0;
    $opts->{mark_fixed} //= 0;
    $opts->{state} //= 'confirmed'; # it's only public updates that need to be unconfirmed
    if ($opts->{state} eq 'confirmed') {
        $opts->{confirmed} //= \'current_timestamp';
    }

    return $opts;
};

=head2 around user

Also make sure we catch the setting of a user on an object at a time other than
object creation, to set the extra field needed.

=cut

around user => sub {
    my ( $orig, $self ) = ( shift, shift );
    my $res = $self->$orig(@_);
    if (@_) {
        if ($_[0]->is_superuser) {
            $self->set_extra_metadata( is_superuser => 1 );
        } elsif (my $body = $_[0]->from_body) {
            $self->set_extra_metadata( is_body_user => $body->id );
        }
    }
    return $res;
};

=head2 get_cobrand_logged

Get a cobrand object for the cobrand the update was made on.

e.g. if an update was logged at www.fixmystreet.com, this will be a
FixMyStreet::Cobrand::FixMyStreet object.

=cut

has get_cobrand_logged => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $cobrand_class = FixMyStreet::Cobrand->get_class_for_moniker( $self->cobrand );
        return $cobrand_class->new;
    },
);


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

__PACKAGE__->has_many(
  "admin_log_entries",
  "FixMyStreet::DB::Result::AdminLog",
  { "foreign.object_id" => "self.id" },
  {
      cascade_copy => 0, cascade_delete => 0,
      where => { 'object_type' => 'update' },
  }
);

# This will return the oldest moderation_original_data, if any.
# The plural can be used to return all entries.
__PACKAGE__->might_have(
  "moderation_original_data",
  "FixMyStreet::DB::Result::ModerationOriginalData",
  { "foreign.comment_id" => "self.id",
    "foreign.problem_id" => "self.problem_id",
  },
  { order_by => 'id',
    rows => 1,
    cascade_copy => 0, cascade_delete => 1 },
);

sub moderation_filter {
    my $self = shift;
    { problem_id => $self->problem_id };
}

sub update_send_failed {
    my $self = shift;
    my $msg  = shift;

    $self->update( {
        send_fail_count => $self->send_fail_count + 1,
        send_fail_timestamp => \'current_timestamp',
        send_fail_reason => $msg
    } );
}

=head2 meta_line

Returns a string to be used on a report update, describing some of the metadata
about an update. Can include HTML.

=cut

sub meta_line {
    my ( $self, $user ) = @_;
    my $cobrand = $self->result_source->schema->cobrand;

    my $meta = '';

    my $contributed_as = $self->get_extra_metadata('contributed_as') || '';
    my $staff = $self->user->from_body || $self->get_extra_metadata('is_body_user') || $self->get_extra_metadata('is_superuser');
    my $anon = $self->anonymous || !$self->name || $cobrand->call_hook('is_comment_anonymous');

    if ($anon && (!$staff || $contributed_as eq 'anonymous_user' || $contributed_as eq 'another_user')) {
        $meta = $cobrand->call_hook(update_anonymous_message => $self);
        $meta ||= sprintf( _( 'Posted anonymously at %s' ), Utils::prettify_dt( $self->confirmed ) )
    } elsif ($staff) {
        my $user_name = FixMyStreet::Template::html_filter($self->user->name);
        my $body;
        if ($self->get_extra_metadata('is_superuser')) {
            $body = _('an administrator');
        } else {
            # use this meta data in preference to the user's from_body setting
            # in case they are no longer with the body, or have changed body.
            if (my $body_id = $self->get_extra_metadata('is_body_user')) {
                $body = FixMyStreet::DB->resultset('Body')->find({id => $body_id})->name;
            } else {
                $body = $self->user->body;
            }
            $body = FixMyStreet::Template::html_filter($body);
            if ($body eq 'Bromley Council') {
                $body = "$body <img src='/cobrands/bromley/favicon.png' alt=''>";
            } elsif ($body eq 'Royal Borough of Greenwich') {
                $body = "$body <img src='/cobrands/greenwich/favicon.png' alt=''>";
            } elsif ($body eq 'Hounslow Borough Council') {
                $body = 'Hounslow Highways';
            } elsif ($body eq 'Isle of Wight Council') {
                $body = 'Island Roads';
            } elsif ($body eq 'Thamesmead') {
               $body = 'Peabody';
            } elsif ($body eq 'National Highways') {
                # Always use what was saved on the comment
                $body = FixMyStreet::Template::html_filter($self->name);
            }
        }
        my $cobrand_always_view_body_user = $cobrand->call_hook(always_view_body_contribute_details => $contributed_as);
        my $can_view_contribute = $cobrand_always_view_body_user ||
            ($user && $user->has_permission_to('view_body_contribute_details', $self->problem->bodies_str_ids));
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

    return FixMyStreet::Template::SafeString->new($meta);
};

sub problem_state_processed {
    my $self = shift;
    return 'fixed - user' if $self->mark_fixed;
    return 'confirmed' if $self->mark_open;
    my $cobrand = $self->result_source->schema->cobrand;
    my $cobrand_state = $cobrand->call_hook(problem_state_processed => $self);

    return $cobrand_state || $self->problem_state;
}

sub problem_state_display {
    my $self = shift;

    my $state = $self->problem_state_processed;
    return '' unless $state;

    my $cobrand = $self->result_source->schema->cobrand;
    my $cobrand_name = $self->problem->cobrand_name_for_state($cobrand);
    return FixMyStreet::DB->resultset("State")->display($state, 1, $cobrand_name);
}

sub is_latest {
    my $self = shift;
    my $latest_update = $self->result_source->resultset->search(
        { problem_id => $self->problem_id, state => 'confirmed' },
        { order_by => [ { -desc => 'confirmed' }, { -desc => 'id' } ] }
    )->first;
    return unless $latest_update;
    return $latest_update->id == $self->id;
}

sub hide {
    my $self = shift;

    my $ret = {};

    # If we're hiding an update, see if it marked as fixed and unfix if so
    if ($self->mark_fixed && $self->is_latest && $self->problem->state =~ /^fixed/) {
        $self->problem->state('confirmed');
        $self->problem->update;
        $ret->{reopened} = 1;
    }
    $self->get_photoset->delete_cached;
    $self->update({ state => 'hidden' });
    return $ret;
}

sub as_hashref {
    my ($self, $cols) = @_;
    my $cobrand = $self->result_source->schema->cobrand;

    my $out = {
        id => $self->id,
        problem_id => $self->problem_id,
        text => $self->text,
        state => $self->state,
        created => $self->created,
    };

    $out->{problem_state} = $self->problem_state_processed;

    $out->{photos} = [ map { $_->{url} } @{$self->photos} ] if !$cols || $cols->{photos};

    if ($self->confirmed) {
        $out->{confirmed} = $self->confirmed if !$cols || $cols->{confirmed};
        $out->{confirmed_pp} = $cobrand->prettify_dt( $self->confirmed ) if !$cols || $cols->{confirmed_pp};
    }

    return $out;
}

1;
