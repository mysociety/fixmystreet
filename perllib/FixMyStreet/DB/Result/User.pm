use utf8;
package FixMyStreet::DB::Result::User;

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
  { data_type => "text", is_nullable => 1 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "phone",
  { data_type => "text", is_nullable => 1 },
  "password",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "flagged",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "from_body",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "facebook_id",
  { data_type => "bigint", is_nullable => 1 },
  "twitter_id",
  { data_type => "bigint", is_nullable => 1 },
  "is_superuser",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "extra",
  { data_type => "text", is_nullable => 1 },
  "email_verified",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "phone_verified",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_active",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "area_ids",
  { data_type => "integer[]", is_nullable => 1 },
  "oidc_ids",
  { data_type => "text[]", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("users_facebook_id_key", ["facebook_id"]);
__PACKAGE__->add_unique_constraint("users_twitter_id_key", ["twitter_id"]);
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
__PACKAGE__->has_many(
  "user_planned_reports",
  "FixMyStreet::DB::Result::UserPlannedReport",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_roles",
  "FixMyStreet::DB::Result::UserRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-06-20 16:31:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ryb6giJm/7N7svg/d+2GeA

# These are not fully unique constraints (they only are when the *_verified
# is true), but this is managed in ResultSet::User's find() wrapper.
__PACKAGE__->add_unique_constraint("users_email_verified_key", ["email", "email_verified"]);
__PACKAGE__->add_unique_constraint("users_phone_verified_key", ["phone", "phone_verified"]);

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('extra');

use Moo;
use Text::CSV;
use List::MoreUtils 'uniq';
use FixMyStreet::SMS;
use mySociety::EmailUtil;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::Extra';

__PACKAGE__->many_to_many( planned_reports => 'user_planned_reports', 'report' );
__PACKAGE__->many_to_many( roles => 'user_roles', 'role' );

sub cost {
    FixMyStreet->test_mode ? 1 : 12;
}

__PACKAGE__->add_columns(
    "password" => {
        encode_column => 1,
        encode_class => 'Crypt::Eksblowfish::Bcrypt',
        encode_args => { cost => cost() },
        encode_check_method => '_check_password',
    },
);

sub check_password {
    my $self = shift;
    my $cobrand = $self->result_source->schema->cobrand;
    if ($cobrand->moniker eq 'tfl') {
        my $col_v = $self->get_extra_metadata('tfl_password');
        return unless defined $col_v;
        $self->_column_encoders->{password}->($_[0], $col_v) eq $col_v;
    } else {
        $self->_check_password(@_);
    }
}

around password => sub {
    my ($orig, $self) = (shift, shift);
    if (@_) {
        $self->set_extra_metadata(last_password_change => time());
    }
    $self->$orig(@_);
};

=head2 username

Returns a verified email or phone for this user, preferring email,
or undef if neither verified (shouldn't happen).

=cut

sub username {
    my $self = shift;
    return $self->email if $self->email_verified;
    return $self->phone_display if $self->phone_verified;
}

sub phone_display {
    my $self = shift;
    return $self->phone unless $self->phone;
    my $country = FixMyStreet->config('PHONE_COUNTRY');
    my $parsed = FixMyStreet::SMS->parse_username($self->phone);
    return $parsed->{phone} ? $parsed->{phone}->format_for_country($country) : $self->phone;
}

sub latest_anonymity {
    my $self = shift;
    my $p = $self->problems->search(undef, { rows => 1, order_by => { -desc => 'id' } } )->first;
    my $c = $self->comments->search(undef, { rows => 1, order_by => { -desc => 'id' } } )->first;
    my $p_created = $p ? $p->created->epoch : 0;
    my $c_created = $c ? $c->created->epoch : 0;
    my $obj = $p_created >= $c_created ? $p : $c;
    return $obj ? $obj->anonymous : 0;
}

sub latest_visible_problem {
    my $self = shift;
    return $self->problems->search({
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ]
    }, {
        order_by => { -desc => 'id' }
    })->single;
}

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

    if ($self->email_verified) {
        if ($self->email !~ /\S/) {
            $errors{username} = _('Please enter your email');
        } elsif (!mySociety::EmailUtil::is_valid_email($self->email)) {
            $errors{username} = _('Please enter a valid email');
        }
    } elsif ($self->phone_verified) {
        my $parsed = FixMyStreet::SMS->parse_username($self->phone);
        if (!$parsed->{phone}) {
            # Errors with the phone number may apply to both the username or
            # phone field depending on the form.
            $errors{username} = _('Please check your phone number is correct');
            $errors{phone} = _('Please check your phone number is correct');
        } elsif (!$parsed->{may_be_mobile}) {
            $errors{username} = _('Please enter a mobile number');
            $errors{phone} = _('Please enter a mobile number');
        }
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

=head2 create_alert

Sign a user up to receive alerts on a given problem

=cut

sub create_alert {
    my ( $self, $id, $options ) = @_;
    my $alert = $self->alert_for_problem($id);

    unless ( $alert ) {
      $alert = $self->alerts->create({
          %$options,
          alert_type   => 'new_updates',
          parameter    => $id,
      });
    }

    $alert->confirm();
}

sub body {
    my $self = shift;
    return '' unless $self->from_body;
    return $self->from_body->name;
}

sub moderating_user_name {
    my $self = shift;
    my $body = $self->body;
    if ( $body && $body eq 'Isle of Wight Council' ) {
        $body = 'Island Roads';
    }
    return $body || _('an administrator');
}

=head2 belongs_to_body

    $belongs_to_body = $user->belongs_to_body( $bodies );

Returns true if the user belongs to the comma seperated list of body ids passed in

=cut

sub belongs_to_body {
    my $self = shift;
    my $bodies = shift;

    return 0 unless $bodies && $self->from_body;

    my %bodies = map { $_ => 1 } split ',', $bodies;

    return 1 if $bodies{ $self->from_body->id };
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

sub can_moderate {
    my ($self, $object, $perms) = @_;

    my ($type, $ids);
    if ($object->isa("FixMyStreet::DB::Result::Comment")) {
        $type = 'update';
        $ids = $object->problem->bodies_str_ids;
    } else {
        $type = 'problem';
        $ids = $object->bodies_str_ids;
    }

    my $staff_perm = exists($perms->{staff}) ? $perms->{staff} : $self->has_permission_to(moderate => $ids);
    return 1 if $staff_perm;

    # See if the cobrand wants to allow it in some circumstance
    my $cobrand = $self->result_source->schema->cobrand;
    return $cobrand->call_hook('moderate_permission', $self, $type => $object);
}

sub can_moderate_title {
    my ($self, $problem, $perm) = @_;

    # Must have main permission, this is to potentially restrict only
    return 0 unless $perm;

    # If hook returns anything use it, otherwise default to yes
    my $cobrand = $self->result_source->schema->cobrand;
    return $cobrand->call_hook('moderate_permission_title', $self, $problem) // 1;
}

has body_permissions => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $perms = [];
        foreach my $role ($self->roles->all) {
            push @$perms, map { {
                body_id => $role->body_id,
                permission => $_,
            } } @{$role->permissions};
        }
        push @$perms, map { {
            body_id => $_->body_id,
            permission => $_->permission_type,
        } } $self->user_body_permissions->all;
        return $perms;
    },
);

sub permissions {
    my ($self, $problem) = @_;
    my $cobrand = $self->result_source->schema->cobrand;

    if ($self->is_superuser) {
        my $perms = $cobrand->available_permissions;
        return { map { %$_ } values %$perms };
    }

    my $body_id = $problem->bodies_str;

    return unless $self->belongs_to_body($body_id);

    my @permissions = grep { $_->{body_id} == $self->from_body->id } @{$self->body_permissions};
    return { map { $_->{permission} => 1 } @permissions };
}

sub has_permission_to {
    my ($self, $permission_type, $body_ids) = @_;

    # Nobody, including superusers, can have a permission which isn't available
    # in the current cobrand.
    my $cobrand = $self->result_source->schema->cobrand;
    my $cobrand_perms = $cobrand->available_permissions;
    my %available = map { %$_ } values %$cobrand_perms;
    return 0 unless $available{$permission_type};

    return 1 if $self->is_superuser;
    return 0 if !$body_ids || (ref $body_ids eq 'ARRAY' && !@$body_ids);
    $body_ids = [ $body_ids ] unless ref $body_ids eq 'ARRAY';
    my %body_ids = map { $_ => 1 } @$body_ids;

    foreach (@{$self->body_permissions}) {
        return 1 if $_->{permission} eq $permission_type && $body_ids{$_->{body_id}};
    }
    return 0;
}

=head2 has_body_permission_to

Checks if the User has a from_body set, the specified permission on that body,
and optionally that their from_body is one particular body.

Instead of saying:

    ($user->from_body && $user->from_body->id == $body_id && $user->has_permission_to('user_edit', $body_id))

You can just say:

    $user->has_body_permission_to('user_edit', $body_id)

=cut

sub has_body_permission_to {
    my ($self, $permission_type, $body_id) = @_;

    return 1 if $self->is_superuser;

    return unless $self->from_body;
    return if $body_id && $self->from_body->id != $body_id;

    return $self->has_permission_to($permission_type, $self->from_body->id);
}

=head2 admin_user_body_permissions

Some permissions aren't managed in the normal way via the admin, e.g. the
'trusted' permission. This method returns a query that excludes such exceptional
permissions.

=cut

sub admin_user_body_permissions {
    my $self = shift;

    return $self->user_body_permissions->search({
        permission_type => { '!=' => 'trusted' },
    });
}

sub has_2fa {
    my $self = shift;
    return $self->get_extra_metadata('2fa_secret');
}

sub contributing_as {
    my ($self, $other, $c, $bodies) = @_;
    $bodies = [ keys %$bodies ] if ref $bodies eq 'HASH';
    my $form_as = $c->get_param('form_as') || '';
    return 1 if $form_as eq $other && $self->has_permission_to("contribute_as_$other", $bodies);
}

sub adopt {
    my ($self, $other) = @_;

    return if $self->id == $other->id;

    # Move most things from $other to $self
    foreach (qw(Problem Comment Alert AdminLog )) {
        $self->result_source->schema->resultset($_)
            ->search({ user_id => $other->id })
            ->update({ user_id => $self->id });
    }

    # It's possible the user permissions for the other user exist, so
    # try updating, and then delete anyway.
    foreach ($self->result_source->schema->resultset("UserBodyPermission")
                ->search({ user_id => $other->id })->all) {
        eval {
            $_->update({ user_id => $self->id });
        };
        $_->delete if $@;
    }

    # Delete the now empty user
    $other->delete;
}

sub anonymize_account {
    my $self = shift;

    $self->problems->update({ anonymous => 1, name => '', send_questionnaire => 0 });
    $self->comments->update({ anonymous => 1, name => '' });
    $self->alerts->update({ whendisabled => \'current_timestamp' });
    $self->password('', 1);
    $self->update({
        email => 'removed-' . $self->id . '@' . FixMyStreet->config('EMAIL_DOMAIN'),
        email_verified => 0,
        name => '',
        phone => '',
        phone_verified => 0,
        title => undef,
        twitter_id => undef,
        facebook_id => undef,
        oidc_ids => undef,
    });
}

# Planned reports / shortlist

# Override the default auto-created function as we only want one live entry so
# we need to delete it anywhere else and return an existing one if present.
around add_to_planned_reports => sub {
    my ( $orig, $self ) = ( shift, shift );
    my ( $report_col ) = @_;

    $self->result_source->schema->resultset("UserPlannedReport")
        ->active
        ->for_report($report_col->id)
        ->search_rs({ user_id => { '!=', $self->id } })
        ->remove();
    my $existing = $self->user_planned_reports->active->for_report($report_col->id)->first;
    return $existing if $existing;
    return $self->$orig(@_);
};

# Override the default auto-created function as we don't want to ever delete anything
around remove_from_planned_reports => sub {
    my ($orig, $self, $report) = @_;
    $self->user_planned_reports->active->for_report($report->id)->remove();
    $report->unset_extra_metadata('order');
    $report->update;
};

sub active_planned_reports {
    my $self = shift;
    $self->planned_reports->search({ removed => undef });
}

has active_user_planned_reports => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        [ $self->user_planned_reports->search({ removed => undef })->all ];
    },
);

sub is_planned_report {
    my ($self, $problem) = @_;
    my $id = $problem->id;
    return scalar grep { $_->report_id == $id } @{$self->active_user_planned_reports};
}

has categories => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        return [] unless $self->get_extra_metadata('categories');
        my @categories = $self->result_source->schema->resultset("Contact")->search({
            id => $self->get_extra_metadata('categories'),
        }, {
            order_by => 'category',
        })->get_column('category')->all;
        return \@categories;
    },
);

has categories_string => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $csv = Text::CSV->new;
        $csv->combine(@{$self->categories});
        return $csv->string;
    },
);

sub set_last_active {
    my $self = shift;
    my $time = shift;
    $self->unset_extra_metadata('inactive_email_sent');
    $self->last_active($time or \'current_timestamp');
}

has areas_hash => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my %ids = map { $_ => 1 } @{$self->area_ids || []};
        return \%ids;
    },
);

sub in_area {
    my ($self, $area) = @_;
    return $self->areas_hash->{$area};
}

has roles_hash => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my %ids = map { $_->role_id => 1 } $self->user_roles->all;
        return \%ids;
    },
);

sub in_role {
    my ($self, $role) = @_;
    return $self->roles_hash->{$role};
}

sub add_oidc_id {
    my ($self, $oidc_id) = @_;

    my $oidc_ids = $self->oidc_ids || [];
    my @oidc_ids = uniq ( $oidc_id, @$oidc_ids );
    $self->oidc_ids(\@oidc_ids);
}

sub remove_oidc_id {
    my ($self, $oidc_id) = @_;

    my $oidc_ids = $self->oidc_ids || [];
    my @oidc_ids = grep { $_ ne $oidc_id } @$oidc_ids;
    $self->oidc_ids(scalar @oidc_ids ? \@oidc_ids : undef);
}

1;
