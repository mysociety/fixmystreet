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

    $c->detach('add') if $c->req->method eq 'POST'; # Add a user

    if (my $search = $c->get_param('search')) {
        $search = $self->trim($search);
        $search =~ s/^<(.*)>$/$1/; # In case email wrapped in <...>
        $c->stash->{searched} = $search;

        my $isearch = '%' . $search . '%';
        my $search_n = 0;
        $search_n = int($search) if $search =~ /^\d+$/;

        my $users = $c->cobrand->users->search(
            {
                -or => [
                    email => { ilike => $isearch },
                    phone => { ilike => $isearch },
                    name => { ilike => $isearch },
                    from_body => $search_n,
                ]
            }
        );
        my @users = $users->all;
        $c->stash->{users} = [ @users ];
        $c->forward('/admin/add_flags', [ { email => { ilike => $isearch } } ]);

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

    return if %{$c->stash->{field_errors}};

    my $user = $c->model('DB::User')->create( {
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
    $c->forward('user_cobrand_extra_fields');
    $user->update;

    $c->forward( '/admin/log_edit', [ $user->id, 'user', 'edit' ] );

    $c->flash->{status_message} = _("Updated!");
    $c->res->redirect( $c->uri_for_action( 'admin/users/edit', $user->id ) );
}

sub edit : Path : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->forward('/auth/get_csrf_token');

    my $user = $c->cobrand->users->find( { id => $id } );
    $c->detach( '/page_error_404_not_found', [] ) unless $user;

    unless ( $c->user->has_body_permission_to('user_edit') || $c->cobrand->moniker eq 'zurich' ) {
        $c->detach('/page_error_403_access_denied', []);
    }

    $c->stash->{user} = $user;
    $c->forward( '/admin/check_username_for_abuse', [ $user ] );

    if ( $user->from_body && $c->user->has_permission_to('user_manage_permissions', $user->from_body->id) ) {
        $c->stash->{available_permissions} = $c->cobrand->available_permissions;
    }

    $c->forward('/admin/fetch_all_bodies');
    $c->forward('/admin/fetch_body_areas', [ $user->from_body ]) if $user->from_body;
    $c->cobrand->call_hook('admin_user_edit_extra_data');

    if ( defined $c->flash->{status_message} ) {
        $c->stash->{status_message} =
            '<p><em>' . $c->flash->{status_message} . '</em></p>';
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
        $args{user_id} = $id if $user->email ne $email || !$user->email_verified;
        $c->forward('send_login_email', [ \%args ]);
    } elsif ( $c->get_param('update_alerts') ) {
        $c->forward('update_alerts');
    } elsif ( $c->get_param('submit') ) {

        my $edited = 0;

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

        if ( ($user->email || "") ne $email ||
            $user->name ne $name ||
            ($user->phone || "") ne $phone ||
            ($user->from_body && $c->get_param('body') && $user->from_body->id ne $c->get_param('body')) ||
            (!$user->from_body && $c->get_param('body'))
        ) {
                $edited = 1;
        }

        if ($existing_user_cobrand) {
            $existing_user->adopt($user);
            $c->forward( '/admin/log_edit', [ $id, 'user', 'merge' ] );
            return $c->res->redirect( $c->uri_for_action( 'admin/users/edit', $existing_user->id ) );
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
        }

        if (!$user->from_body) {
            # Non-staff users aren't allowed any permissions or to be in an area
            $user->admin_user_body_permissions->delete;
            $user->area_ids(undef);
            delete $c->stash->{areas};
            delete $c->stash->{fetched_areas_body_id};
        } elsif ($c->stash->{available_permissions}) {
            my @all_permissions = map { keys %$_ } values %{ $c->stash->{available_permissions} };
            my @user_permissions = grep { $c->get_param("permissions[$_]") ? 1 : undef } @all_permissions;
            $user->admin_user_body_permissions->search({
                body_id => $user->from_body->id,
                permission_type => { '!=' => \@user_permissions },
            })->delete;
            foreach my $permission_type (@user_permissions) {
                $user->user_body_permissions->find_or_create({
                    body_id => $user->from_body->id,
                    permission_type => $permission_type,
                });
            }
        }

        if ( $user->from_body && $c->user->has_permission_to('user_assign_areas', $user->from_body->id) ) {
            my %valid_areas = map { $_->{id} => 1 } @{ $c->stash->{areas} };
            my @area_ids = grep { $valid_areas{$_} } $c->get_param_list('area_ids');
            $user->area_ids( @area_ids ? \@area_ids : undef );
        }

        # Handle 'trusted' flag(s)
        my @trusted_bodies = $c->get_param_list('trusted_bodies');
        if ( $c->user->is_superuser ) {
            $user->user_body_permissions->search({
                body_id => { '!=' => \@trusted_bodies },
                permission_type => 'trusted',
            })->delete;
            foreach my $body_id (@trusted_bodies) {
                $user->user_body_permissions->find_or_create({
                    body_id => $body_id,
                    permission_type => 'trusted',
                });
            }
        } elsif ( $c->user->from_body ) {
            my %trusted = map { $_ => 1 } @trusted_bodies;
            my $body_id = $c->user->from_body->id;
            if ( $trusted{$body_id} ) {
                $user->user_body_permissions->find_or_create({
                    body_id => $body_id,
                    permission_type => 'trusted',
                });
            } else {
                $user->user_body_permissions->search({
                    body_id => $body_id,
                    permission_type => 'trusted',
                })->delete;
            }
        }

        # Update the categories this user operates in
        if ( $user->from_body ) {
            $c->stash->{body} = $user->from_body;
            $c->forward('/admin/fetch_contacts');
            my @live_contacts = $c->stash->{live_contacts}->all;
            my @live_contact_ids = map { $_->id } @live_contacts;
            my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @live_contact_ids;
            $user->set_extra_metadata('categories', \@new_contact_ids);
        }

        $user->update;
        if ($edited) {
            $c->forward( '/admin/log_edit', [ $id, 'user', 'edit' ] );
        }
        $c->flash->{status_message} = _("Updated!");
        return $c->res->redirect( $c->uri_for_action( 'admin/users/edit', $user->id ) );
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
        } } @live_contacts;
        $c->stash->{contacts} = \@all_contacts;
    }

    # this goes after in case we've delete any alerts
    unless ( $c->cobrand->moniker eq 'zurich' ) {
        $c->forward('user_alert_details');
    }

    return 1;
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
    $csv->getline($fh); # discard the header
    while (my $row = $csv->getline($fh)) {
        my ($name, $email, $from_body, $permissions) = @$row;
        $email = lc Utils::trim_text($email);
        my @permissions = split(/:/, $permissions);

        my $user = FixMyStreet::DB->resultset("User")->find_or_new({ email => $email, email_verified => 1 });
        if ($user->in_storage) {
            push @{$c->stash->{existing_users}}, $user;
            next;
        }

        $user->name($name);
        $user->from_body($from_body || undef);
        $user->update_or_insert;

        my @user_permissions = grep { $available_permissions{$_} } @permissions;
        foreach my $permission_type (@user_permissions) {
            $user->user_body_permissions->find_or_create({
                body_id => $user->from_body->id,
                permission_type => $permission_type,
            });
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
        $problem->get_photoset->delete_cached;
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
