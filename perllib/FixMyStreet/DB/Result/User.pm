use utf8;
package FixMyStreet::DB::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("users");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "users_id_seq",
  },
  "email",
  { data_type => "text", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "phone",
  { data_type => "text", is_nullable => 1 },
  "password",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "from_body",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "flagged",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("users_email_key", ["email"]);
__PACKAGE__->has_many(
  "admin_logs",
  "FixMyStreet::DB::Result::AdminLog",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "alerts",
  "FixMyStreet::DB::Result::Alert",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "bodies",
  "FixMyStreet::DB::Result::Body",
  { "foreign.comment_user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "comments",
  "FixMyStreet::DB::Result::Comment",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "from_body",
  "FixMyStreet::DB::Result::Body",
  { id => "from_body" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "problems",
  "FixMyStreet::DB::Result::Problem",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_body_permissions",
  "FixMyStreet::DB::Result::UserBodyPermission",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2014-07-29 13:54:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Y41/jGp93IxSpyJ/o6Q1gQ

__PACKAGE__->add_columns(
    "password" => {
        encode_column => 1,
        encode_class => 'Crypt::Eksblowfish::Bcrypt',
        encode_args => { cost => 8 },
        encode_check_method => 'check_password',
    },
);

use mySociety::EmailUtil;

=head2 check_for_errors

    $error_hashref = $user->check_for_errors();

Look at all the fields and return a hashref with all errors found, keyed on the
field name. This is intended to be passed back to the form to display the
errors.

TODO - ideally we'd pass back error codes which would be humanised in the
templates (eg: 'missing','email_not_valid', etc).

=cut

sub check_for_errors {
    my $self = shift;

    my %errors = ();

    if ( !$self->name || $self->name !~ m/\S/ ) {
        $errors{name} = _('Please enter your name');
    }

    if ( $self->email !~ /\S/ ) {
        $errors{email} = _('Please enter your email');
    }
    elsif ( !mySociety::EmailUtil::is_valid_email( $self->email ) ) {
        $errors{email} = _('Please enter a valid email');
    }

    return \%errors;
}

=head2 answered_ever_reported

Check if the user has ever answered a questionnaire.

=cut

sub answered_ever_reported {
    my $self = shift;

    my $has_answered =
      $self->result_source->schema->resultset('Questionnaire')->search(
        {
            ever_reported => { not => undef },
            problem_id => { -in =>
                $self->problems->get_column('id')->as_query },
        }
      );

    return $has_answered->count > 0;
}

=head2 alert_for_problem

Returns whether the user is already subscribed to an
alert for the problem ID provided.

=cut

sub alert_for_problem {
    my ( $self, $id ) = @_;

    return $self->alerts->find( {
        alert_type => 'new_updates',
        parameter  => $id,
    } );
}

sub body {
    my $self = shift;
    return '' unless $self->from_body;
    return $self->from_body->name;
}

=head2 belongs_to_body

    $belongs_to_body = $user->belongs_to_body( $bodies );

Returns true if the user belongs to the comma seperated list of body ids passed in

=cut

sub belongs_to_body {
    my $self = shift;
    my $bodies = shift;

    my %bodies = map { $_ => 1 } split ',', $bodies;

    return 1 if $self->from_body && $bodies{ $self->from_body->id };

    return 0;
}

=head2 split_name

    $name = $user->split_name;
    printf( 'Welcome %s %s', $name->{first}, $name->{last} );

Returns a hashref with first and last keys with first name(s) and last name.
NB: the spliting algorithm is extremely basic.

=cut

sub split_name {
    my $self = shift;

    my ($first, $last) = $self->name =~ /^(\S*)(?: (.*))?$/;

    return { first => $first || '', last => $last || '' };
}

sub has_permission_to {
    my ($self, $permission_type, $body_id) = @_;

    return unless $self->belongs_to_body($body_id);

    my $permission = $self->user_body_permissions->find({ 
            permission_type => $permission_type,
            body_id => $self->from_body->id,
        });
    return $permission ? 1 : undef;
}

sub print {
    my $self = shift;
    return '[' . (join '-', @_) . ']';
}

1;
