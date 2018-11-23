package FixMyStreet::App::Controller::Report::Update;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use Path::Class;
use List::Util 'first';
use Utils;

=head1 NAME

FixMyStreet::App::Controller::Report::Update

=head1 DESCRIPTION

Creates an update to a report

=cut

sub report_update : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('initialize_update');
    $c->forward('load_problem');
    $c->forward('check_form_submitted')
      or $c->go( '/report/display', [ $c->stash->{problem}->id ], [] );

    $c->forward('/auth/check_csrf_token');
    $c->forward('process_update');
    $c->forward('process_user');
    $c->forward('/photo/process_photo');
    $c->forward('check_for_errors')
      or $c->go( '/report/display', [ $c->stash->{problem}->id ], [] );

    $c->forward('save_update');
    $c->forward('redirect_or_confirm_creation');
}

sub update_problem : Private {
    my ( $self, $c ) = @_;

    my $display_questionnaire = 0;

    my $update = $c->stash->{update};
    my $problem = $c->stash->{problem} || $update->problem;

    # we may need this if we display the questionnaire
    my $old_state = $problem->state;

    if ( $update->mark_fixed ) {
        $problem->state('fixed - user');

        if ( $update->user->id == $problem->user->id ) {
            $problem->send_questionnaire(0);

            if ( $c->cobrand->ask_ever_reported
                && !$problem->user->answered_ever_reported )
            {
                $display_questionnaire = 1;
            }
        }
    }

    if ( $update->problem_state ) {
        $problem->state( $update->problem_state );
    }

    if ( $update->mark_open && $update->user->id == $problem->user->id ) {
        $problem->state('confirmed');
    }

    if ( $c->cobrand->can_support_problems && $c->user && $c->user->from_body && $c->get_param('external_source_id') ) {
        $problem->interest_count( \'interest_count + 1' );
    }

    $problem->lastupdate( \'current_timestamp' );
    $problem->update;

    $c->stash->{problem_id} = $problem->id;

    if ($display_questionnaire) {
        $c->flash->{old_state} = $old_state;
        $c->detach('/questionnaire/creator_fixed');
    }

    return 1;
}

=head2 process_user

Load user from the database or prepare a new one.

=cut

sub process_user : Private {
    my ( $self, $c ) = @_;

    my $update = $c->stash->{update};

    # Extract all the params to a hash to make them easier to work with
    my %params = map { $_ => $c->get_param($_) }
      ( 'name', 'password_register', 'fms_extra_title' );

    # Update form includes two username fields: #form_username_register and #form_username_sign_in
    $params{username} = (first { $_ } $c->get_param_list('username')) || '';

    # Extra block to use 'last'
    if ( $c->user_exists ) { {
        my $user = $c->user->obj;

        if ($c->stash->{contributing_as_another_user} = $user->contributing_as('another_user', $c, $update->problem->bodies_str_ids)) {
            # Act as if not logged in (and it will be auto-confirmed later on)
            last;
        }

        $user->name( Utils::trim_text( $params{name} ) ) if $params{name};
        my $title = Utils::trim_text( $params{fms_extra_title} );
        $user->title( $title ) if $title;
        $update->user( $user );

        # Just in case, make sure the user will have a name
        if ($c->stash->{contributing_as_body} or $c->stash->{contributing_as_anonymous_user}) {
            $user->name($user->from_body->name) unless $user->name;
        }

        return 1;
    } }

    my $parsed = FixMyStreet::SMS->parse_username($params{username});
    my $type = $parsed->{type} || 'email';
    $type = 'email' unless FixMyStreet->config('SMS_AUTHENTICATION') || $c->stash->{contributing_as_another_user};
    $update->user( $c->model('DB::User')->find_or_new( { $type => $parsed->{username} } ) )
        unless $update->user;

    $c->stash->{phone_may_be_mobile} = $type eq 'phone' && $parsed->{may_be_mobile};

    # The user is trying to sign in. We only care about username from the params.
    if ( $c->get_param('submit_sign_in') || $c->get_param('password_sign_in') ) {
        $c->stash->{tfa_data} = {
            detach_to => '/report/update/report_update',
            login_success => 1,
            oauth_update => { $update->get_inflated_columns }
        };
        unless ( $c->forward( '/auth/sign_in', [ $params{username} ] ) ) {
            $c->stash->{field_errors}->{password} = _('There was a problem with your login information. If you cannot remember your password, or do not have one, please fill in the &lsquo;No&rsquo; section of the form.');
            return 1;
        }
        my $user = $c->user->obj;
        $update->user( $user );
        $update->name( $user->name );
        $c->stash->{login_success} = 1;
        return 1;
    }

    $update->user->name( Utils::trim_text( $params{name} ) )
        if $params{name};
    $update->user->title( Utils::trim_text( $params{fms_extra_title} ) )
        if $params{fms_extra_title};

    if ($params{password_register}) {
        $c->forward('/auth/test_password', [ $params{password_register} ]);
        $update->user->password($params{password_register});
    }

    return 1;
}

=head2 oauth_callback

Called when we successfully login via OAuth. Stores the token so we can look up
what we have so far.

=cut

sub oauth_callback : Private {
    my ( $self, $c, $token_code ) = @_;
    my $auth_token = $c->forward('/tokens/load_auth_token',
        [ $token_code, 'update/social' ]);
    $c->stash->{oauth_update} = $auth_token->data;
    $c->detach('report_update');
}

=head2 initialize_update

Create an initial update object, either empty or from stored OAuth data.

=cut

sub initialize_update : Private {
    my ( $self, $c ) = @_;

    my $update;
    if ($c->stash->{oauth_update}) {
        $update = $c->model("DB::Comment")->new($c->stash->{oauth_update});
    }

    if ($update) {
        $c->stash->{upload_fileid} = $update->get_photoset->data;
    } else {
        $update = $c->model('DB::Comment')->new({
            state => 'unconfirmed',
            cobrand => $c->cobrand->moniker,
            cobrand_data => '',
            lang => $c->stash->{lang_code},
        });
    }

    if ( $c->get_param('first_name') && $c->get_param('last_name') ) {
        my $first_name = $c->get_param('first_name');
        my $last_name = $c->get_param('last_name');
        $c->set_param('name', sprintf( '%s %s', $first_name, $last_name ));

        $c->stash->{first_name} = $first_name;
        $c->stash->{last_name} = $last_name;
    }

    $c->stash->{update} = $update;
}

=head2 load_problem

Our update could be prefilled, or we could be submitting a form containing an
ID. Look up the relevant report either way.

=cut

sub load_problem : Private {
    my ( $self, $c ) = @_;

    my $update = $c->stash->{update};
    # Problem ID could come from existing update in token, or from query parameter
    my $problem_id = $update->problem_id || $c->get_param('id');
    $c->forward( '/report/load_problem_or_display_error', [ $problem_id ] );
    $update->problem($c->stash->{problem});
}

=head2 check_form_submitted

This makes sure we only proceed to processing if we've had the form submitted
(we may have come here via an OAuth login, for example).

=cut

sub check_form_submitted : Private {
    my ( $self, $c ) = @_;
    return if $c->stash->{problem}->get_extra_metadata('closed_updates');
    return if $c->cobrand->call_hook(updates_disallowed => $c->stash->{problem});
    return $c->get_param('submit_update') || '';
}

=head2 process_update

Take the submitted params and updates our update item. Does not save
anything to the database.

=cut

sub process_update : Private {
    my ( $self, $c ) = @_;

    my %params =
      map { $_ => $c->get_param($_) } ( 'update', 'name', 'fixed', 'state', 'reopen' );

    $params{update} =
      Utils::cleanup_text( $params{update}, { allow_multiline => 1 } );

    my $name = Utils::trim_text( $params{name} );

    $params{reopen} = 0 unless $c->user && $c->user->id == $c->stash->{problem}->user->id;

    my $update = $c->stash->{update};
    $update->text($params{update});

    $update->mark_fixed($params{fixed} ? 1 : 0);
    $update->mark_open($params{reopen} ? 1 : 0);

    $c->stash->{contributing_as_body} = $c->user_exists && $c->user->contributing_as('body', $c, $update->problem->bodies_str_ids);
    $c->stash->{contributing_as_anonymous_user} = $c->user_exists && $c->user->contributing_as('anonymous_user', $c, $update->problem->bodies_str_ids);
    if ($c->stash->{contributing_as_body}) {
        $update->name($c->user->from_body->name);
        $update->anonymous(0);
    } elsif ($c->stash->{contributing_as_anonymous_user}) {
        $update->name($c->user->from_body->name);
        $update->anonymous(1);
    } else {
        $update->name($name);
        $update->anonymous($c->get_param('may_show_name') ? 0 : 1);
    }

    if ( $params{state} ) {
        $update->problem_state( $params{state} );
    } else {
        # we do this so we have a record of the state of the problem at this point
        # for use when sending updates to external parties
        if ( $update->mark_fixed ) {
            $update->problem_state( 'fixed - user' );
        } elsif ( $update->mark_open ) {
            $update->problem_state( 'confirmed' );
        # if there is not state param and neither of the above conditions apply
        # then we are not changing the state of the problem so can use the current
        # problem state
        } else {
            my $problem = $c->stash->{problem} || $update->problem;
            $update->problem_state( $problem->state );
        }
    }


    my @extra; # Next function fills this, but we don't need it here.
    # This is just so that the error checking for these extra fields runs.
    # TODO Use extra here as it is used on reports.
    my $body = (values %{$update->problem->bodies})[0];
    $c->cobrand->process_open311_extras( $c, $body, \@extra );

    if ( $c->get_param('fms_extra_title') ) {
        my %extras = ();
        $extras{title} = $c->get_param('fms_extra_title');
        $extras{email_alerts_requested} = $c->get_param('add_alert');
        $update->extra( \%extras );
    }

    if ( $c->stash->{ first_name } && $c->stash->{ last_name } ) {
        my $extra = $update->extra || {};
        $extra->{first_name} = $c->stash->{ first_name };
        $extra->{last_name} = $c->stash->{ last_name };
        $update->extra( $extra );
    }

    $c->stash->{add_alert} = $c->get_param('add_alert');

    return 1;
}


=head2 check_for_errors

Examine the user and the report for errors. If found put them on stash and
return false.

=cut

sub check_for_errors : Private {
    my ( $self, $c ) = @_;

    # they have to be an authority user to update the state
    my $state = $c->get_param('state');
    if ( $state && $state ne $c->stash->{update}->problem->state ) {
        my $error = 0;
        $error = 1 unless $c->user && ($c->user->is_superuser || $c->user->belongs_to_body($c->stash->{update}->problem->bodies_str));
        $error = 1 unless grep { $state eq $_ } FixMyStreet::DB::Result::Problem->visible_states();
        if ( $error ) {
            $c->stash->{errors} ||= [];
            push @{ $c->stash->{errors} }, _('There was a problem with your update. Please try again.');
            return;
        }

    }

    # let the model check for errors
    $c->stash->{field_errors} ||= {};
    my %field_errors = (
        %{ $c->stash->{field_errors} },
        %{ $c->stash->{update}->user->check_for_errors },
        %{ $c->stash->{update}->check_for_errors },
    );

    # if using social login then we don't care about name and email errors
    $c->stash->{is_social_user} = $c->get_param('facebook_sign_in') || $c->get_param('twitter_sign_in');
    if ( $c->stash->{is_social_user} ) {
        delete $field_errors{name};
        delete $field_errors{username};
    }

    # if we're contributing as someone else then allow landline numbers
    if ( $field_errors{phone} && $c->stash->{contributing_as_another_user} && !$c->stash->{phone_may_be_mobile}) {
        delete $field_errors{username};
        delete $field_errors{phone};
    }

    if ( my $photo_error  = delete $c->stash->{photo_error} ) {
        $field_errors{photo} = $photo_error;
    }

    # all good if no errors
    return 1
      unless ( scalar keys %field_errors
        || $c->stash->{login_success}
        || ( $c->stash->{errors} && scalar @{ $c->stash->{errors} } ) );

    $c->stash->{field_errors} = \%field_errors;

    $c->stash->{errors} ||= [];
    #push @{ $c->stash->{errors} },
    #  _('There were problems with your update. Please see below.');

    return;
}

# Store changes in token for when token is validated.
sub tokenize_user : Private {
    my ($self, $c, $update) = @_;
    $c->stash->{token_data} = {
        name => $update->user->name,
        password => $update->user->password,
    };
    $c->stash->{token_data}{facebook_id} = $c->session->{oauth}{facebook_id}
        if $c->get_param('oauth_need_email') && $c->session->{oauth}{facebook_id};
    $c->stash->{token_data}{twitter_id} = $c->session->{oauth}{twitter_id}
        if $c->get_param('oauth_need_email') && $c->session->{oauth}{twitter_id};
}

=head2 save_update

Save the update and the user as appropriate.

=cut

sub save_update : Private {
    my ( $self, $c ) = @_;

    my $update = $c->stash->{update};

    # If there was a photo add that too
    if ( my $fileid = $c->stash->{upload_fileid} ) {
        $update->photo($fileid);
    }

    if ( $update->is_from_abuser ) {
        $c->stash->{template} = 'tokens/abuse.html';
        $c->detach;
    }

    if ( $c->stash->{is_social_user} ) {
        my $token = $c->model("DB::Token")->create( {
            scope => 'update/social',
            data => { $update->get_inflated_columns },
        } );

        $c->stash->{detach_to} = '/report/update/oauth_callback';
        $c->stash->{detach_args} = [$token->token];

        if ( $c->get_param('facebook_sign_in') ) {
            $c->detach('/auth/social/facebook_sign_in');
        } elsif ( $c->get_param('twitter_sign_in') ) {
            $c->detach('/auth/social/twitter_sign_in');
        }
    }

    if ( $c->cobrand->never_confirm_updates ) {
        $update->user->update_or_insert;
        $update->confirm();
    # If created on behalf of someone else, we automatically confirm it,
    # but we don't want to update the user account
    } elsif ($c->stash->{contributing_as_another_user}) {
        $update->set_extra_metadata( contributed_as => 'another_user');
        $update->set_extra_metadata( contributed_by => $c->user->id );
        $update->confirm();
    } elsif ($c->stash->{contributing_as_body}) {
        $update->set_extra_metadata( contributed_as => 'body' );
        $update->confirm();
    } elsif ($c->stash->{contributing_as_anonymous_user}) {
        $update->set_extra_metadata( contributed_as => 'anonymous_user' );
        $update->confirm();
    } elsif ( !$update->user->in_storage ) {
        # User does not exist.
        $c->forward('tokenize_user', [ $update ]);
        $update->user->name( undef );
        $update->user->password( '', 1 );
        $update->user->insert;
    }
    elsif ( $c->user && $c->user->id == $update->user->id ) {
        # Logged in and same user, so can confirm update straight away
        $update->user->update;
        $update->confirm;
    } else {
        # User exists and we are not logged in as them.
        $c->forward('tokenize_user', [ $update ]);
        $update->user->discard_changes();
    }

    $update->update_or_insert;

    return 1;
}

=head2 redirect_or_confirm_creation

Now that the update has been created either redirect the user to problem page if it
has been confirmed or email them a token if it has not been.

=cut

sub redirect_or_confirm_creation : Private {
    my ( $self, $c ) = @_;
    my $update = $c->stash->{update};

    # If confirmed send the user straight there.
    if ( $update->confirmed ) {
        $c->forward( 'update_problem' );
        $c->forward( 'signup_for_alerts' );
        if ($c->stash->{contributing_as_another_user} && $update->user->email) {
            $c->send_email( 'other-updated.txt', {
                to => [ [ $update->user->email, $update->name ] ],
            } );
        }
        $c->stash->{template} = 'tokens/confirm_update.html';
        return 1;
    }

    # Superusers using 2FA can not log in by code
    $c->detach( '/page_error_403_access_denied', [] ) if $update->user->has_2fa;

    my $data = $c->stash->{token_data};
    $data->{id} = $update->id;
    $data->{add_alert} = $c->get_param('add_alert') ? 1 : 0;

    if ($update->user->email_verified) {
        $c->forward('send_confirmation_email');
        # tell user that they've been sent an email
        $c->stash->{template}   = 'email_sent.html';
        $c->stash->{email_type} = 'update';
    } elsif ($update->user->phone_verified) {
        $c->forward('send_confirmation_text');
    } else {
        warn "Reached update confirmation with no username verification";
    }

    return 1;
}

sub send_confirmation_email : Private {
    my ( $self, $c ) = @_;

    my $update = $c->stash->{update};
    my $token = $c->model("DB::Token")->create( {
        scope => 'comment',
        data  => $c->stash->{token_data},
    } );
    my $template = 'update-confirm.txt';
    $c->stash->{token_url} = $c->uri_for_email( '/C', $token->token );
    $c->send_email( $template, {
        to => [ $update->name ? [ $update->user->email, $update->name ] : $update->user->email ],
    } );
}

sub send_confirmation_text : Private {
    my ( $self, $c ) = @_;
    my $update = $c->stash->{update};
    $c->forward('/auth/phone/send_token', [ $c->stash->{token_data}, 'comment', $update->user->phone ]);
    $c->stash->{submit_url} = '/report/update/text';
}

sub confirm_by_text : Path('text') {
    my ( $self, $c ) = @_;

    $c->stash->{submit_url} = '/report/update/text';
    $c->forward('/auth/phone/code', [ 'comment', '/report/update/process_confirmation' ]);
}

sub process_confirmation : Private {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'tokens/confirm_update.html';
    my $data = $c->stash->{token_data};

    unless ($c->stash->{update}) {
        $c->stash->{update} = $c->model('DB::Comment')->find({ id => $data->{id} }) || return;
    }
    my $comment = $c->stash->{update};

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $comment->is_from_abuser ) {
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    if ( $comment->state ne 'unconfirmed' ) {
        my $report_uri = $c->cobrand->base_url_for_report( $comment->problem ) . $comment->problem->url;
        $c->res->redirect($report_uri);
        return;
    }

    if ( $data->{name} || $data->{password} ) {
        for (qw(name facebook_id twitter_id)) {
            $comment->user->$_( $data->{$_} ) if $data->{$_};
        }
        $comment->user->password( $data->{password}, 1 ) if $data->{password};
        $comment->user->update;
    }

    if ($comment->user->email_verified) {
        $c->authenticate( { email => $comment->user->email, email_verified => 1 }, 'no_password' );
    } elsif ($comment->user->phone_verified) {
        $c->authenticate( { phone => $comment->user->phone, phone_verified => 1 }, 'no_password' );
    } else {
        warn "Reached user authentication with no username verification";
    }
    $c->set_session_cookie_expire(0);

    $c->stash->{update}->confirm;
    $c->stash->{update}->update;
    $c->forward('update_problem');
    $c->stash->{add_alert} = $data->{add_alert};
    $c->forward('signup_for_alerts');

    return 1;
}

=head2 signup_for_alerts

If the user has selected to be signed up for alerts then create a
new_updates alert. Or if they're logged in and they've unticked the
box, disable their alert.

NB: this does not check if they are a registered user so that should
happen before calling this.

=cut

sub signup_for_alerts : Private {
    my ( $self, $c ) = @_;

    my $update = $c->stash->{update};
    my $user = $update->user;
    my $problem_id = $update->problem_id;

    if ( $c->stash->{add_alert} ) {
        my $options = {
            cobrand => $update->cobrand,
            cobrand_data => $update->cobrand_data,
            lang => $update->lang,
        };
        $user->create_alert($problem_id, $options);
    } elsif ( my $alert = $user->alert_for_problem($problem_id) ) {
        $alert->disable();
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
