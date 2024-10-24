use utf8;
package FixMyStreet::DB::Result::User;

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
  "email_verified",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "phone",
  { data_type => "text", is_nullable => 1 },
  "phone_verified",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "password",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "from_body",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "flagged",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_superuser",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "last_active",
  {
    data_type     => "timestamp",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "title",
  { data_type => "text", is_nullable => 1 },
  "twitter_id",
  { data_type => "bigint", is_nullable => 1 },
  "facebook_id",
  { data_type => "bigint", is_nullable => 1 },
  "oidc_ids",
  { data_type => "text[]", is_nullable => 1 },
  "area_ids",
  { data_type => "integer[]", is_nullable => 1 },
  "extra",
  { data_type => "jsonb", is_nullable => 1 },
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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2023-05-10 17:03:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FturQPxHq1lLoflaefwmyg

__PACKAGE__->has_many(
  active_user_planned_reports => "FixMyStreet::DB::Result::UserPlannedReport",
  sub {
      my $args = shift;
      return {
          "$args->{foreign_alias}.user_id" => { -ident => "$args->{self_alias}.id" },
          "$args->{foreign_alias}.removed" => undef,
      };
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

# These are not fully unique constraints (they only are when the *_verified
# is true), but this is managed in ResultSet::User's find() wrapper.
__PACKAGE__->add_unique_constraint("users_email_verified_key", ["email", "email_verified"]);
__PACKAGE__->add_unique_constraint("users_phone_verified_key", ["phone", "phone_verified"]);

use Moo;
use Text::CSV;
use List::MoreUtils 'uniq';
use FixMyStreet::SMS;
use mySociety::EmailUtil;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::DB::Extra';

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

sub access_token {
    my $self = shift;
    return $self->get_extra_metadata('access_token');
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
    return undef;
}

sub phone_display {
    my $self = shift;
    return $self->phone unless $self->phone;
    my $country = FixMyStreet->config('PHONE_COUNTRY');
    my $parsed = FixMyStreet::SMS->parse_username($self->phone);
    return $parsed->{phone} ? $parsed->{phone}->format_for_country($country) : $self->phone;
}

sub alert_by {
    my ($self, $is_update, $cobrand) = @_;
    return $is_update
        ? $self->alert_updates_by($cobrand)
        : $self->alert_local_by;
}

# How does this user want to receive local alerts?
# email or none, so will be none for a phone-only user
sub alert_local_by {
    my $self = shift;
    my $pref = $self->get_extra_metadata('alert_notify') || '';
    return 'none' if $pref eq 'none';
    return 'none' unless $self->email_verified;
    return 'email';
}

# How does this user want to receive update alerts?
# If the cobrand allows text, this could include phone
sub alert_updates_by {
    my ($self, $cobrand) = @_;
    my $pref = $self->get_extra_metadata('update_notify') || '';
    return 'none' if $pref eq 'none';

    # Only send text alerts for new report updates at present
    my $parsed = FixMyStreet::SMS->parse_username($self->phone);
    my $allow_phone_update = ($self->phone_verified && $cobrand->sms_authentication && $parsed->{may_be_mobile});

    return 'none' unless $self->email_verified || $allow_phone_update;
    return 'phone' if $allow_phone_update && (!$self->email_verified || $pref eq 'phone');
    return 'email';
}

# Whether user has opted to receive questionnaires.
# Defaults to true if not set in extra metadata.
sub questionnaire_notify {
    return $_[0]->get_extra_metadata('questionnaire_notify') // 1;
}

sub latest_anonymity {
    my $self = shift;
    my $p = $self->problems->order_by('-id')->search(undef, { rows => 1 } )->first;
    my $c = $self->comments->order_by('-id')->search(undef, { rows => 1 } )->first;
    my $p_created = $p ? $p->created->epoch : 0;
    my $c_created = $c ? $c->created->epoch : 0;
    my $obj = $p_created >= $c_created ? $p : $c;
    return $obj ? $obj->anonymous : 0;
}

sub latest_visible_problem {
    my $self = shift;
    return $self->problems->search({
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ]
    })->order_by('-id')->first;
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

Returns true if the user belongs to the arrayref or comma seperated list of body ids passed in

=cut

sub belongs_to_body {
    my $self = shift;
    my $bodies = shift;

    return 0 unless $bodies && $self->from_body;

    $bodies = [ split ',', $bodies ] unless ref $bodies eq 'ARRAY';
    my %bodies = map { $_ => 1 } @$bodies;

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

sub remove_staff {
    my $self = shift;
    $self->user_roles->delete;
    $self->admin_user_body_permissions->delete;
    $self->from_body(undef);
    $self->user_planned_reports->active->remove();
    $self->area_ids(undef);
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

    my $body_id = $problem->bodies_str_ids;
    $body_id = $cobrand->call_hook(permission_body_override => $body_id) || $body_id;

    return {} unless $self->belongs_to_body($body_id);

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
    $body_ids = $cobrand->call_hook(permission_body_override => $body_ids) || $body_ids;

    my %body_ids = map { $_ => 1 } @$body_ids;
    foreach (@{$self->body_permissions}) {
        return 1 if $_->{permission} eq $permission_type && $body_ids{$_->{body_id}};
    }
    return 0;
}

=head2 has_body_permission_to

Checks if the User has a from_body set and the specified permission on that
body. Instead of saying:

    ($user->from_body && $user->has_permission_to('user_edit', $user->from_body->id))

You can just say:

    $user->has_body_permission_to('user_edit')

=cut

sub has_body_permission_to {
    my ($self, $permission_type) = @_;

    return 1 if $self->is_superuser;
    return unless $self->from_body;
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
    $self->remove_staff;
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

after add_to_planned_reports => sub {
    my ( $self, $report, $no_comment ) = @_;

    unless ($no_comment) {
        my $cobrand = $report->get_cobrand_logged;
        $cobrand
            = $cobrand->call_hook( get_body_handler_for_problem => $report )
            || $cobrand;

        my $report_extra = $cobrand->call_hook('record_update_extra_fields');
        $report->add_to_comments(
            {   text  => '',
                user  => $self,
                extra => { shortlisted_user => $self->email },
            }
        ) if $report_extra->{shortlisted_user};
    }
};

# Override the default auto-created function as we don't want to ever delete anything
around remove_from_planned_reports => sub {
    my ($orig, $self, $report) = @_;
    $self->user_planned_reports->active->for_report($report->id)->remove();
    $report->unset_extra_metadata('order');
    $report->update;
};

after remove_from_planned_reports => sub {
    my ( $self, $report, $no_comment ) = @_;

    unless ($no_comment) {
        my $cobrand = $report->get_cobrand_logged;
        $cobrand
            = $cobrand->call_hook( get_body_handler_for_problem => $report )
            || $cobrand;

        my $report_extra = $cobrand->call_hook('record_update_extra_fields');
        $report->add_to_comments(
            {   text  => '',
                user  => $self,
                extra => { shortlisted_user => undef },
            }
        ) if $report_extra->{shortlisted_user};
    }
};

sub active_planned_reports {
    my $self = shift;
    $self->planned_reports->search({ removed => undef });
}

sub is_planned_report {
    my ($self, $problem) = @_;
    my $id = $problem->id;
    return scalar grep { $_->report_id == $id } $self->active_user_planned_reports->all;
}

has categories => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;

        my @category_ids;
        my $user_categories = $self->get_extra_metadata('categories');
        push @category_ids, @$user_categories if scalar $user_categories;
        foreach my $role ($self->roles) {
            my $role_categories = $role->get_extra_metadata('categories');
            push @category_ids, @$role_categories if scalar $role_categories;
        }
        return [] unless @category_ids;

        my @categories = $self->result_source->schema->resultset("Contact")->search({
            id => \@category_ids,
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
