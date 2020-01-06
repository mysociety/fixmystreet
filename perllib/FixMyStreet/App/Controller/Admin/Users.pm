package FixMyStreet::App::Controller::Admin::Users;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use POSIX qw(strcoll);
use mySociety::EmailUtil qw(is_valid_email);
use Text::CSV;

use FixMyStreet::MapIt;
use FixMyStreet::SMS;
use Utils;

=head1 NAME

FixMyStreet::App::Controller::Admin::Users - Catalyst Controller

=head1 DESCRIPTION

Admin pages for editing users

=head1 METHODS

=cut

sub index :Path : Args(0) {
    my ( $self, $c ) = @_;

    if ($c->req->method eq 'POST') {
        my @uids = $c->get_param_list('uid');
        my @role_ids = $c->get_param_list('roles');
        my $user_rs = FixMyStreet::DB->resultset("User")->search({ id => \@uids });
        foreach my $user ($user_rs->all) {
            $user->admin_user_body_permissions->delete;
            $user->user_roles->search({
                role_id => { -not_in => \@role_ids },
            })->delete;
            foreach my $role (@role_ids) {
                $user->user_roles->find_or_create({
                    role_id => $role,
                });
            }
        }
        $c->stash->{status_message} = _('Updated!');
    }

    my $search = $c->get_param('search');
    my $role = $c->get_param('role');
    if ($search || $role) {
        my $users = $c->cobrand->users;
        my $isearch;
        if ($search) {
            $search = $self->trim($search);
            $search =~ s/^<(.*)>$/$1/; # In case email wrapped in <...>
            $c->stash->{searched} = $search;

            $isearch = '%' . $search . '%';
            my $search_n = 0;
            $search_n = int($search) if $search =~ /^\d+$/;

            $users = $users->search(
                {
                    -or => [
                        email => { ilike => $isearch },
                        phone => { ilike => $isearch },
                        name => { ilike => $isearch },
                        from_body => $search_n,
                    ]
                }
            );
        }
        if ($role) {
            $c->stash->{role_selected} = $role;
            $users = $users->search({
                role_id => $role,
            }, {
                join => 'user_roles',
            });
        }

        my @users = $users->all;
        $c->stash->{users} = [ @users ];
        if ($search) {
            $c->forward('/admin/add_flags', [ { email => { ilike => $isearch } } ]);
        }

    } else {
        $c->forward('/auth/get_csrf_token');
        $c->forward('/admin/fetch_all_bodies');
        $c->cobrand->call_hook('admin_user_edit_extra_data');

        # Admin users by default
        my $users = $c->cobrand->users->search(
            { from_body => { '!=', undef } },
            { order_by => 'name' }
        );
        my @users = $users->all;
        $c->stash->{users} = \@users;
    }

    my $rs;
    if ($c->user->is_superuser) {
        $rs = $c->model('DB::Role')->search_rs({}, { join => 'body', order_by => ['body.name', 'me.name'] });
    } elsif ($c->user->from_body) {
        $rs = $c->user->from_body->roles->search_rs({}, { order_by => 'name' });
    }
    $c->stash->{roles} = [ $rs->all ];

    return 1;
}

sub add : Local : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'admin/users/edit.html';
    $c->forward('/auth/get_csrf_token');
    $c->forward('/admin/fetch_all_bodies');
    $c->cobrand->call_hook('admin_user_edit_extra_data');

    return unless $c->get_param('submit');

    $c->forward('/auth/check_csrf_token');

    $c->stash->{field_errors} = {};
    my $email = lc $c->get_param('email');
    my $phone = $c->get_param('phone');
    my $email_v = $c->get_param('email_verified');
    my $phone_v = $c->get_param('phone_verified');

    if ($email && !is_valid_email($email)) {
        $c->stash->{field_errors}->{email} = _('Please enter a valid email');
    }
    unless ($c->get_param('name')) {
        $c->stash->{field_errors}->{name} = _('Please enter a name');
    }

    unless ($email || $phone) {
        $c->stash->{field_errors}->{username} = _('Please enter a valid email or phone number');
    }
    if (!$email_v && !$phone_v) {
        $c->stash->{field_errors}->{username} = _('Please verify at least one of email/phone');
    }

    if ($phone_v) {
        my $parsed_phone = $c->forward('phone_check', [ $phone ]);
        $phone = $parsed_phone if $parsed_phone;
    }

    my $existing_email = $email_v && $c->model('DB::User')->find( { email => $email } );
    my $existing_phone = $phone_v && $c->model('DB::User')->find( { phone => $phone } );
    if ($existing_email || $existing_phone) {
        $c->stash->{field_errors}->{username} = _('User already exists');
    }

    my $user = $c->model('DB::User')->new( {
        name => $c->get_param('name'),
        email => $email ? $email : undef,
        email_verified => $email && $email_v ? 1 : 0,
        phone => $phone || undef,
        phone_verified => $phone && $phone_v ? 1 : 0,
        from_body => $c->get_param('body') || undef,
        flagged => $c->get_param('flagged') || 0,
        # Only superusers can create superusers
        is_superuser => ( $c->user->is_superuser && $c->get_param('is_superuser') ) || 0,
    } );
    $c->stash->{user} = $user;

    return if %{$c->stash->{field_errors}};

    $c->forward('user_cobrand_extra_fields');
    $user->insert;

    $c->forward( '/admin/log_edit', [ $user->id, 'user', 'add' ] );

    $c->flash->{status_message} = _("Updated!");
    $c->detach('post_edit_redirect', [ $user ]);
}

sub fetch_body_roles : Private {
    my ($self, $c, $body ) = @_;

    my $roles = $body->roles->search(undef, { order_by => 'name' });
    unless ($roles) {
        delete $c->stash->{roles}; # Body doesn't have any roles
        return;
    }

    $c->stash->{roles} = [ $roles->all ];
}

sub user : Chained('/') PathPart('admin/users') : CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    my $user = $c->cobrand->users->find( { id => $id } );
    $c->detach( '/page_error_404_not_found', [] ) unless $user;
    $c->stash->{user} = $user;

    unless ( $c->user->has_body_permission_to('user_edit') || $c->cobrand->moniker eq 'zurich' ) {
        $c->detach('/page_error_403_access_denied', []);
    }
}

sub edit : Chained('user') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');

    my $user = $c->stash->{user};
    $c->forward( '/admin/check_username_for_abuse', [ $user ] );

    if ( $user->from_body && $c->user->has_permission_to('user_manage_permissions', $user->from_body->id) ) {
        $c->stash->{available_permissions} = $c->cobrand->available_permissions;
    }

    $c->forward('/admin/fetch_all_bodies');
    $c->forward('/admin/fetch_body_areas', [ $user->from_body ]) if $user->from_body;
    $c->forward('fetch_body_roles', [ $user->from_body ]) if $user->from_body;
    $c->cobrand->call_hook('admin_user_edit_extra_data');

    if ( defined $c->flash->{status_message} ) {
        $c->stash->{status_message} = $c->flash->{status_message};
    }

    $c->forward('/auth/check_csrf_token') if $c->get_param('submit');

    if ( $c->get_param('submit') and $c->get_param('unban') ) {
        $c->forward('unban', [ $user ]);
    } elsif ( $c->get_param('submit') and $c->get_param('logout_everywhere') ) {
        $c->forward('user_logout_everywhere', [ $user ]);
    } elsif ( $c->get_param('submit') and $c->get_param('anon_everywhere') ) {
        $c->forward('user_anon_everywhere', [ $user ]);
    } elsif ( $c->get_param('submit') and $c->get_param('hide_everywhere') ) {
        $c->forward('user_hide_everywhere', [ $user ]);
    } elsif ( $c->get_param('submit') and $c->get_param('remove_account') ) {
        $c->forward('user_remove_account', [ $user ]);
    } elsif ( $c->get_param('submit') and $c->get_param('send_login_email') ) {
        my $email = lc $c->get_param('email');
        my %args = ( email => $email );
        $args{user_id} = $user->id if $user->email ne $email || !$user->email_verified;
        $c->forward('send_login_email', [ \%args ]);
    } elsif ( $c->get_param('update_alerts') ) {
        $c->forward('update_alerts');
    } elsif ( $c->get_param('submit') ) {

        my $name = $c->get_param('name');
        my $email = lc $c->get_param('email');
        my $phone = $c->get_param('phone');
        my $email_v = $c->get_param('email_verified') || 0;
        my $phone_v = $c->get_param('phone_verified') || 0;

        $c->stash->{field_errors} = {};

        unless ($email || $phone) {
            $c->stash->{field_errors}->{username} = _('Please enter a valid email or phone number');
        }
        if (!$email_v && !$phone_v) {
            $c->stash->{field_errors}->{username} = _('Please verify at least one of email/phone');
        }
        if ($email && !is_valid_email($email)) {
            $c->stash->{field_errors}->{email} = _('Please enter a valid email');
        }

        if ($phone_v) {
            my $parsed_phone = $c->forward('phone_check', [ $phone ]);
            $phone = $parsed_phone if $parsed_phone;
        }

        unless ($name) {
            $c->stash->{field_errors}->{name} = _('Please enter a name');
        }

        my $email_params = { email => $email, email_verified => 1, id => { '!=', $user->id } };
        my $phone_params = { phone => $phone, phone_verified => 1, id => { '!=', $user->id } };
        my $existing_email = $email_v && $c->model('DB::User')->search($email_params)->first;
        my $existing_phone = $phone_v && $c->model('DB::User')->search($phone_params)->first;
        my $existing_user = $existing_email || $existing_phone;
        my $existing_email_cobrand = $email_v && $c->cobrand->users->search($email_params)->first;
        my $existing_phone_cobrand = $phone_v && $c->cobrand->users->search($phone_params)->first;
        my $existing_user_cobrand = $existing_email_cobrand || $existing_phone_cobrand;
        if ($existing_phone_cobrand && $existing_email_cobrand && $existing_email_cobrand->id != $existing_phone_cobrand->id) {
            $c->stash->{field_errors}->{username} = _('User already exists');
        }

        return if %{$c->stash->{field_errors}};

        if ($existing_user_cobrand) {
            $existing_user->adopt($user);
            $c->forward( '/admin/log_edit', [ $user->id, 'user', 'merge' ] );
            return $c->res->redirect( $c->uri_for_action( 'admin/users/edit', [ $existing_user->id ] ) );
        }

        $user->email($email) if !$existing_email;
        $user->phone($phone) if !$existing_phone;
        $user->email_verified( $email_v );
        $user->phone_verified( $phone_v );
        $user->name( $name );

        $user->flagged( $c->get_param('flagged') || 0 );
        # Only superusers can grant superuser status
        $user->is_superuser( ( $c->user->is_superuser && $c->get_param('is_superuser') ) || 0 );
        # Superusers can set from_body to any value, but other staff can only
        # set from_body to the same value as their own from_body.
        if ( $c->user->is_superuser || $c->cobrand->moniker eq 'zurich' ) {
            $user->from_body( $c->get_param('body') || undef );
        } elsif ( $c->user->has_body_permission_to('user_assign_body') ) {
            if ($c->get_param('body') && $c->get_param('body') eq $c->user->from_body->id ) {
                $user->from_body( $c->user->from_body );
            } else {
                $user->from_body( undef );
            }
        }

        $c->forward('user_cobrand_extra_fields');

        # Has the user's from_body changed since we fetched areas (if we ever did)?
        # If so, we need to re-fetch areas so the UI is up to date.
        if ( $user->from_body && $user->from_body->id ne $c->stash->{fetched_areas_body_id} ) {
            $c->forward('/admin/fetch_body_areas', [ $user->from_body ]);
            $c->forward('fetch_body_roles', [ $user->from_body ]);
        }

        if (!$user->from_body) {
            # Non-staff users aren't allowed any permissions or to be in an area
            $user->admin_user_body_permissions->delete;
            $user->user_roles->delete;
            $user->area_ids(undef);
            delete $c->stash->{areas};
            delete $c->stash->{roles};
            delete $c->stash->{fetched_areas_body_id};
        } elsif ($c->stash->{available_permissions}) {
            my %valid_roles = map { $_->id => 1 } @{$c->stash->{roles}};
            my @role_ids = grep { $valid_roles{$_} } $c->get_param_list('roles');
            if (@role_ids) {
                # Roles take precedence over permissions
                $user->admin_user_body_permissions->delete;
                $user->user_roles->search({
                    role_id => { -not_in => \@role_ids },
                })->delete;
                foreach my $role (@role_ids) {
                    $user->user_roles->find_or_create({
                        role_id => $role,
                    });
                }
            } else {
                $user->user_roles->delete;
                my @all_permissions = map { keys %$_ } values %{ $c->stash->{available_permissions} };
                my @user_permissions = grep { $c->get_param("permissions[$_]") ? 1 : undef } @all_permissions;
                $user->admin_user_body_permissions->search({
                    body_id => $user->from_body->id,
                    permission_type => { -not_in => \@user_permissions },
                })->delete;
                foreach my $permission_type (@user_permissions) {
                    $user->user_body_permissions->find_or_create({
                        body_id => $user->from_body->id,
                        permission_type => $permission_type,
                    });
                }
            }
        }

        if ( $user->from_body && $c->user->has_permission_to('user_assign_areas', $user->from_body->id) ) {
            my %valid_areas = map { $_->{id} => 1 } @{ $c->stash->{areas} };
            my @area_ids = grep { $valid_areas{$_} } $c->get_param_list('area_ids');
            $user->area_ids( @area_ids ? \@area_ids : undef );
        }

        # Update the categories this user operates in
        if ( $user->from_body ) {
            $c->stash->{body} = $user->from_body;
            $c->forward('/admin/fetch_contacts');
            my @live_contacts = $c->stash->{live_contacts}->all;
            my @live_contact_ids = map { $_->id } @live_contacts;
            my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @live_contact_ids;
            $user->set_extra_metadata('categories', \@new_contact_ids);
        } else {
            $user->unset_extra_metadata('categories');
        }

        $user->update;
        $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );
        $c->flash->{status_message} = _("Updated!");

        $c->detach('post_edit_redirect', [ $user ]);
    }

    if ( $user->from_body ) {
        unless ( $c->stash->{live_contacts} ) {
            $c->stash->{body} = $user->from_body;
            $c->forward('/admin/fetch_contacts');
        }
        my @contacts = @{$user->get_extra_metadata('categories') || []};
        my %active_contacts = map { $_ => 1 } @contacts;
        my @live_contacts = $c->stash->{live_contacts}->all;
        my @all_contacts = map { {
            id => $_->id,
            category => $_->category,
            active => $active_contacts{$_->id},
            group => $_->get_extra_metadata('group') // '',
        } } @live_contacts;
        $c->stash->{contacts} = \@all_contacts;
        $c->forward('/report/stash_category_groups', [ \@all_contacts, 1 ]) if $c->cobrand->enable_category_groups;
    }

    # this goes after in case we've delete any alerts
    unless ( $c->cobrand->moniker eq 'zurich' ) {
        $c->forward('user_alert_details');
    }

    return 1;
}

sub log : Chained('user') : PathPart('log') : Args(0) {
    my ($self, $c) = @_;

    my $user = $c->stash->{user};

    my $after = $c->get_param('after');

    my %time;
    foreach ($user->admin_logs->all) {
        push @{$time{$_->whenedited->epoch}}, { type => 'log', date => $_->whenedited, log => $_ };
    }
    foreach ($c->cobrand->problems->search({ extra => { like => '%contributed_by%' . $user->id . '%' } })->all) {
        next unless $_->get_extra_metadata('contributed_by') == $user->id;
        push @{$time{$_->created->epoch}}, { type => 'problemContributedBy', date => $_->created, obj => $_ };
    }

    foreach ($user->user_planned_reports->all) {
        push @{$time{$_->added->epoch}}, { type => 'shortlistAdded', date => $_->added, obj => $_->report };
        push @{$time{$_->removed->epoch}}, { type => 'shortlistRemoved', date => $_->removed, obj => $_->report } if $_->removed;
    }

    foreach ($user->problems->all) {
        push @{$time{$_->created->epoch}}, { type => 'problem', date => $_->created, obj => $_ };
    }

    foreach ($user->comments->all) {
        push @{$time{$_->created->epoch}}, { type => 'update', date => $_->created, obj => $_};
    }

    $c->stash->{time} = \%time;
}

sub post_edit_redirect : Private {
    my ( $self, $c, $user ) = @_;

    # User may not be visible on this cobrand, e.g. if their from_body
    # wasn't set.
    if ( $c->cobrand->users->find( { id => $user->id } ) ) {
        return $c->res->redirect( $c->uri_for_action( 'admin/users/edit', [ $user->id ] ) );
    } else {
        return $c->res->redirect( $c->uri_for_action( 'admin/users/index' ) );
    }
}

sub import :Local {
    my ( $self, $c, $id ) = @_;

    $c->forward('/auth/get_csrf_token');
    return unless $c->user_exists && $c->user->is_superuser;

    return unless $c->req->method eq 'POST';

    $c->forward('/auth/check_csrf_token');
    $c->stash->{new_users} = [];
    $c->stash->{existing_users} = [];

    my @all_permissions = map { keys %$_ } values %{ $c->cobrand->available_permissions };
    my %available_permissions = map { $_ => 1 } @all_permissions;

    my $csv = Text::CSV->new({ binary => 1});
    my $fh = $c->req->upload('csvfile')->fh;
    $csv->header($fh);
    while (my $row = $csv->getline_hr($fh)) {
        my $email = lc Utils::trim_text($row->{email});

        my $user = FixMyStreet::DB->resultset("User")->find_or_new({ email => $email, email_verified => 1 });
        if ($user->in_storage) {
            push @{$c->stash->{existing_users}}, $user;
            next;
        }

        $user->name($row->{name});
        $user->from_body($row->{from_body} || undef);
        $user->password($row->{passwordhash}, 1) if $row->{passwordhash};
        $user->insert;

        if ($row->{roles}) {
            my @roles = split(/:/, $row->{roles});
            foreach my $role (@roles) {
                $role = FixMyStreet::DB->resultset("Role")->find({
                    body_id => $user->from_body->id,
                    name => $role,
                }) or next;
                $user->add_to_roles($role);
            }
        } else {
            my @permissions = split(/:/, $row->{permissions});
            my @user_permissions = grep { $available_permissions{$_} } @permissions;
            foreach my $permission_type (@user_permissions) {
                $user->user_body_permissions->find_or_create({
                    body_id => $user->from_body->id,
                    permission_type => $permission_type,
                });
            }
        }

        push @{$c->stash->{new_users}}, $user;
    }
}

sub phone_check : Private {
    my ($self, $c, $phone) = @_;
    my $parsed = FixMyStreet::SMS->parse_username($phone);
    if ($parsed->{phone} && $parsed->{may_be_mobile}) {
        return $parsed->{username};
    } elsif ($parsed->{phone}) {
        $c->stash->{field_errors}->{phone} = _('Please enter a mobile number');
    } else {
        $c->stash->{field_errors}->{phone} = _('Please check your phone number is correct');
    }
}

sub user_cobrand_extra_fields : Private {
    my ( $self, $c ) = @_;

    my @extra_fields = @{ $c->cobrand->call_hook('user_extra_fields') || [] };
    foreach ( @extra_fields ) {
        $c->stash->{user}->set_extra_metadata( $_ => $c->get_param("extra[$_]") );
    }
}

sub user_alert_details : Private {
    my ( $self, $c ) = @_;

    my @alerts = $c->stash->{user}->alerts({}, { prefetch => 'alert_type' })->all;
    $c->stash->{alerts} = \@alerts;

    my @wards;

    for my $alert (@alerts) {
        if ($alert->alert_type->ref eq 'ward_problems') {
            push @wards, $alert->parameter2;
        }
    }

    if (@wards) {
        $c->stash->{alert_areas} = FixMyStreet::MapIt::call('areas', join(',', @wards) );
    }

    my %body_names = map { $_->{id} => $_->{name} } @{ $c->stash->{bodies} };
    $c->stash->{body_names} = \%body_names;
}

sub update_alerts : Private {
    my ($self, $c) = @_;

    my $changes;
    for my $alert ( $c->stash->{user}->alerts ) {
        my $edit_option = $c->get_param('edit_alert[' . $alert->id . ']');
        next unless $edit_option;
        $changes = 1;
        if ( $edit_option eq 'delete' ) {
            $alert->delete;
        } elsif ( $edit_option eq 'disable' ) {
            $alert->disable;
        } elsif ( $edit_option eq 'enable' ) {
            $alert->confirm;
        }
    }
    $c->flash->{status_message} = _("Updated!") if $changes;
}

sub user_logout_everywhere : Private {
    my ( $self, $c, $user ) = @_;
    my $sessions = $user->get_extra_metadata('sessions');
    foreach (grep { $_ ne $c->sessionid } @$sessions) {
        $c->delete_session_data("session:$_");
    }
    $c->stash->{status_message} = _('That user has been logged out.');
}

sub user_anon_everywhere : Private {
    my ( $self, $c, $user ) = @_;
    $user->problems->update({anonymous => 1});
    $user->comments->update({anonymous => 1});
    $c->stash->{status_message} = _('That user has been made anonymous on all reports and updates.');
}

sub user_hide_everywhere : Private {
    my ( $self, $c, $user ) = @_;
    my $problems = $user->problems->search({ state => { '!=' => 'hidden' } });
    while (my $problem = $problems->next) {
        $problem->get_photoset->delete_cached(plus_updates => 1);
        $problem->update({ state => 'hidden' });
    }
    my $updates = $user->comments->search({ state => { '!=' => 'hidden' } });
    while (my $update = $updates->next) {
        $update->hide;
    }
    $c->stash->{status_message} = _('That user’s reports and updates have been hidden.');
}

sub send_login_email : Private {
    my ( $self, $c, $args ) = @_;

    my $token_data = {
        email => $args->{email},
    };

    $token_data->{old_user_id} = $args->{user_id} if $args->{user_id};
    $token_data->{name} = $args->{name} if $args->{name};

    my $token_obj = $c->model('DB::Token')->create({
        scope => 'email_sign_in',
        data  => $token_data,
    });

    $c->stash->{token} = $token_obj->token;
    my $template = 'login.txt';

    # do not use relative URIs in the email, obvs.
    $c->uri_disposition('absolute');
    $c->send_email( $template, { to => $args->{email} } );

    $c->stash->{status_message} = _('The user has been sent a login email');
}

# Anonymize and remove name from all problems/updates, disable all alerts.
# Remove their account's email address, phone number, password, etc.
sub user_remove_account : Private {
    my ( $self, $c, $user ) = @_;
    $c->forward('user_logout_everywhere', [ $user ]);
    $user->anonymize_account;
    $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );
    $c->stash->{status_message} = _('That user’s personal details have been removed.');
}

=head2 ban

Add the user's email address/phone number to the abuse table if they are not
already in there and sets status_message accordingly.

=cut

sub ban : Private {
    my ( $self, $c ) = @_;

    my $user;
    if ($c->stash->{problem}) {
        $user = $c->stash->{problem}->user;
    } elsif ($c->stash->{update}) {
        $user = $c->stash->{update}->user;
    }
    return unless $user;

    if ($user->email_verified && $user->email) {
        my $abuse = $c->model('DB::Abuse')->find_or_new({ email => $user->email });
        if ( $abuse->in_storage ) {
            $c->stash->{status_message} = _('User already in abuse list');
        } else {
            $abuse->insert;
            $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );
            $c->stash->{status_message} = _('User added to abuse list');
        }
        $c->stash->{username_in_abuse} = 1;
    }
    if ($user->phone_verified && $user->phone) {
        my $abuse = $c->model('DB::Abuse')->find_or_new({ email => $user->phone });
        if ( $abuse->in_storage ) {
            $c->stash->{status_message} = _('User already in abuse list');
        } else {
            $abuse->insert;
            $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );
            $c->stash->{status_message} = _('User added to abuse list');
        }
        $c->stash->{username_in_abuse} = 1;
    }
    return 1;
}

sub unban : Private {
    my ( $self, $c, $user ) = @_;

    my @username;
    if ($user->email_verified && $user->email) {
        push @username, $user->email;
    }
    if ($user->phone_verified && $user->phone) {
        push @username, $user->phone;
    }
    if (@username) {
        my $abuse = $c->model('DB::Abuse')->search({ email => \@username });
        if ( $abuse ) {
            $abuse->delete;
            $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );
            $c->stash->{status_message} = _('user removed from abuse list');
        } else {
            $c->stash->{status_message} = _('user not in abuse list');
        }
        $c->stash->{username_in_abuse} = 0;
    }
}

=head2 flag

Sets the flag on a user

=cut

sub flag : Private {
    my ( $self, $c ) = @_;

    my $user;
    if ($c->stash->{problem}) {
        $user = $c->stash->{problem}->user;
    } elsif ($c->stash->{update}) {
        $user = $c->stash->{update}->user;
    }

    if ( !$user ) {
        $c->stash->{status_message} = _('Could not find user');
    } else {
        $user->flagged(1);
        $user->update;
        $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );
        $c->stash->{status_message} = _('User flagged');
    }

    $c->stash->{user_flagged} = 1;

    return 1;
}

=head2 flag_remove

Remove the flag on a user

=cut

sub flag_remove : Private {
    my ( $self, $c ) = @_;

    my $user;
    if ($c->stash->{problem}) {
        $user = $c->stash->{problem}->user;
    } elsif ($c->stash->{update}) {
        $user = $c->stash->{update}->user;
    }

    if ( !$user ) {
        $c->stash->{status_message} = _('Could not find user');
    } else {
        $user->flagged(0);
        $user->update;
        $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );
        $c->stash->{status_message} = _('User flag removed');
    }

    return 1;
}


sub trim {
    my $self = shift;
    my $e = shift;
    $e =~ s/^\s+//;
    $e =~ s/\s+$//;
    return $e;
}

=head1 AUTHOR

mySociety

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
