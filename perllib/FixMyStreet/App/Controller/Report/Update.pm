package FixMyStreet::App::Controller::Report::Update;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use Path::Class;
use Utils;

=head1 NAME

FixMyStreet::App::Controller::Report::Update

=head1 DESCRIPTION

Creates an update to a report

=cut

sub report_update : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward( '/report/load_problem_or_display_error', [ $c->get_param('id') ] );
    $c->forward('process_update');
    $c->forward('process_user');
    $c->forward('/photo/process_photo');
    $c->forward('check_for_errors')
      or $c->go( '/report/display', [ $c->get_param('id') ] );

    $c->forward('save_update');
    $c->forward('redirect_or_confirm_creation');
}

sub confirm : Private {
    my ( $self, $c ) = @_;

    $c->stash->{update}->confirm;
    $c->stash->{update}->update;

    $c->forward('update_problem');
    $c->forward('signup_for_alerts');

    return 1;
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

    if ( $c->user_exists ) {
        my $user = $c->user->obj;
        my $name = $c->get_param('name');
        $user->name( Utils::trim_text( $name ) ) if $name;
        my $title = $c->get_param('fms_extra_title');
        if ( $title ) {
            $c->log->debug( 'user exists and title is ' . $title );
            $user->title( Utils::trim_text( $title ) );
        }
        $update->user( $user );
        return 1;
    }

    # Extract all the params to a hash to make them easier to work with
    my %params = map { $_ => $c->get_param($_) }
      ( 'rznvy', 'name', 'password_register', 'fms_extra_title' );

    # cleanup the email address
    my $email = $params{rznvy} ? lc $params{rznvy} : '';
    $email =~ s{\s+}{}g;

    $update->user( $c->model('DB::User')->find_or_new( { email => $email } ) )
        unless $update->user;

    # The user is trying to sign in. We only care about email from the params.
    if ( $c->get_param('submit_sign_in') || $c->get_param('password_sign_in') ) {
        unless ( $c->forward( '/auth/sign_in', [ $email ] ) ) {
            $c->stash->{field_errors}->{password} = _('There was a problem with your email/password combination. If you cannot remember your password, or do not have one, please fill in the &lsquo;sign in by email&rsquo; section of the form.');
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
    $update->user->password( Utils::trim_text( $params{password_register} ) )
        if $params{password_register};
    $update->user->title( Utils::trim_text( $params{fms_extra_title} ) )
        if $params{fms_extra_title};

    return 1;
}

=head2 process_update

Take the submitted params and create a new update item. Does not save
anything to the database.

NB: relies on their being a problem and update_user in the stash. May
want to move adding these elsewhere

=cut

sub process_update : Private {
    my ( $self, $c ) = @_;

    if ( $c->get_param('first_name') && $c->get_param('last_name') ) {
        my $first_name = $c->get_param('first_name');
        my $last_name = $c->get_param('last_name');
        $c->set_param('name', sprintf( '%s %s', $first_name, $last_name ));

        $c->stash->{first_name} = $first_name;
        $c->stash->{last_name} = $last_name;
    }

    my %params =
      map { $_ => $c->get_param($_) } ( 'update', 'name', 'fixed', 'state', 'reopen' );

    $params{update} =
      Utils::cleanup_text( $params{update}, { allow_multiline => 1 } );

    my $name = Utils::trim_text( $params{name} );
    my $anonymous = $c->get_param('may_show_name') ? 0 : 1;

    $params{reopen} = 0 unless $c->user && $c->user->id == $c->stash->{problem}->user->id;

    my $update = $c->model('DB::Comment')->new(
        {
            text         => $params{update},
            name         => $name,
            problem      => $c->stash->{problem},
            state        => 'unconfirmed',
            mark_fixed   => $params{fixed} ? 1 : 0,
            mark_open    => $params{reopen} ? 1 : 0,
            cobrand      => $c->cobrand->moniker,
            cobrand_data => '',
            lang         => $c->stash->{lang_code},
            anonymous    => $anonymous,
        }
    );

    if ( $params{state} ) {
        $params{state} = 'fixed - council' 
            if $params{state} eq 'fixed' && $c->user && $c->user->belongs_to_body( $update->problem->bodies_str );
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
    # This is just so that the error checkign for these extra fields runs.
    # TODO Use extra here as it is used on reports.
    $c->cobrand->process_extras( $c, $update->problem->bodies_str, \@extra );

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

    $c->log->debug( 'name is ' . $c->get_param('name') );

    $c->stash->{update} = $update;
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
    if ( $c->get_param('state') ) {
        my $error = 0;
        $error = 1 unless $c->user && $c->user->belongs_to_body( $c->stash->{update}->problem->bodies_str );

        my $state = $c->get_param('state');
        $state = 'fixed - council' if $state eq 'fixed';
        $error = 1 unless ( grep { $state eq $_ } ( FixMyStreet::DB::Result::Problem->council_states() ) );

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

=head2 save_update

Save the update and the user as appropriate.

=cut

sub save_update : Private {
    my ( $self, $c ) = @_;

    my $update = $c->stash->{update};

    if ( $c->cobrand->never_confirm_updates ) {
        if ( $update->user->in_storage() ) {
            $update->user->update();
        } else {
            $update->user->insert();
        }
        $update->confirm();
    } elsif ( !$update->user->in_storage ) {
        # User does not exist.
        # Store changes in token for when token is validated.
        $c->stash->{token_data} = {
            name => $update->user->name,
            password => $update->user->password,
        };
        $update->user->name( undef );
        $update->user->password( '', 1 );
        $update->user->insert;
    }
    elsif ( $c->user && $c->user->id == $update->user->id ) {
        # Logged in and same user, so can confirm update straight away
        $c->log->debug( 'user exists' );
        $update->user->update;
        $update->confirm;
    } else {
        # User exists and we are not logged in as them.
        # Store changes in token for when token is validated.
        $c->stash->{token_data} = {
            name => $update->user->name,
            password => $update->user->password,
        };
        $update->user->discard_changes();
    }

    # If there was a photo add that too
    if ( my $fileid = $c->stash->{upload_fileid} ) {
        $update->photo($fileid);
    }

    if ( $update->in_storage ) {
        $update->update;
    }
    else {
        $update->insert;
    }

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
        $c->stash->{template} = 'tokens/confirm_update.html';
        return 1;
    }

    # otherwise create a confirm token and email it to them.
    my $data = $c->stash->{token_data} || {};
    my $token = $c->model("DB::Token")->create(
        {
            scope => 'comment',
            data  => {
                %$data,
                id        => $update->id,
                add_alert => ( $c->get_param('add_alert') ? 1 : 0 ),
            }
        }
    );
    $c->stash->{token_url} = $c->uri_for_email( '/C', $token->token );
    $c->send_email( 'update-confirm.txt', {
        to => $update->name
            ? [ [ $update->user->email, $update->name ] ]
            : $update->user->email,
    } );

    # tell user that they've been sent an email
    $c->stash->{template}   = 'email_sent.html';
    $c->stash->{email_type} = 'update';

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
    if ( $c->stash->{add_alert} ) {
        my $options = {
            user => $update->user,
            alert_type => 'new_updates',
            parameter => $update->problem_id,
        };
        my $alert = $c->model('DB::Alert')->find($options);
        unless ($alert) {
            $alert = $c->model('DB::Alert')->create({
                %$options,
                cobrand      => $update->cobrand,
                cobrand_data => $update->cobrand_data,
                lang         => $update->lang,
            });
        }
        $alert->confirm();

    } elsif ( my $alert = $update->user->alert_for_problem($update->problem_id) ) {
        $alert->disable();
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
