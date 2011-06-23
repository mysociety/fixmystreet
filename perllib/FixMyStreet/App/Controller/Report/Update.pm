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

         $c->forward( '/report/load_problem_or_display_error', [ $c->req->param('id') ] )
      && $c->forward('process_user')
      && $c->forward('process_update')
      && $c->forward('/report/new/process_photo')
      && $c->forward('check_for_errors')
      or $c->go( '/report/display', [ $c->req->param('id') ] );

    return $c->forward('save_update')
      && $c->forward('redirect_or_confirm_creation');
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

    if ( $update->mark_fixed ) {
        $problem->state('fixed');

        if ( $update->user->id == $problem->user->id ) {
            $problem->send_questionnaire(0);

            if ( $c->cobrand->ask_ever_reported
                && !$problem->user->answered_ever_reported )
            {
                $display_questionnaire = 1;
            }
        }
    }

    $problem->lastupdate( \'ms_current_timestamp()' );
    $problem->update;

    $c->stash->{problem_id} = $problem->id;

    if ($display_questionnaire) {
        $c->detach('/questionnaire/creator_fixed');
    }

    return 1;
}

=head2 process_user

Load user from the database or prepare a new one.

=cut

sub process_user : Private {
    my ( $self, $c ) = @_;

    my $update_user;
    if ( $c->user ) {

        $update_user = $c->user->obj;

    } else {

        # Extract all the params to a hash to make them easier to work with
        my %params =    #
          map { $_ => scalar $c->req->param($_) }    #
          ( 'rznvy', 'name' );

        # cleanup the email address
        my $email = $params{rznvy} ? lc $params{rznvy} : '';
        $email =~ s{\s+}{}g;

        $update_user = $c->model('DB::User')->find_or_new( { email => $email } );
        $update_user->name( Utils::trim_text( $params{name} ) );

    }

    $c->stash->{update_user} = $update_user;

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

    my %params =
      map { $_ => scalar $c->req->param($_) } ( 'update', 'name', 'fixed' );

    $params{update} =
      Utils::cleanup_text( $params{update}, { allow_multiline => 1 } );

    my $name = Utils::trim_text( $params{name} );

    my $anonymous = 1;

    $anonymous = 0 if ( $name && $c->req->param('may_show_name') );

    my $update = $c->model('DB::Comment')->new(
        {
            text         => $params{update},
            name         => $name,
            problem      => $c->stash->{problem},
            user         => $c->stash->{update_user},
            state        => 'unconfirmed',
            mark_fixed   => $params{fixed} ? 1 : 0,
            cobrand      => $c->cobrand->moniker,
            cobrand_data => $c->cobrand->extra_update_data,
            lang         => $c->stash->{lang_code},
            anonymous    => $anonymous,
        }
    );

    $c->stash->{update}        = $update;
    $c->stash->{add_alert}     = $c->req->param('add_alert');

    return 1;
}


=head2 check_for_errors

Examine the user and the report for errors. If found put them on stash and
return false.

=cut

sub check_for_errors : Private {
    my ( $self, $c ) = @_;

    # let the model check for errors
    my %field_errors = (
        %{ $c->stash->{update}->user->check_for_errors },
        %{ $c->stash->{update}->check_for_errors },
    );

    # we don't care if there are errors with this...
    delete $field_errors{name};

    # all good if no errors
    return 1
      unless ( scalar keys %field_errors
        || ( $c->stash->{errors} && scalar @{ $c->stash->{errors} } )
        || $c->stash->{photo_error} );

    $c->stash->{field_errors} = \%field_errors;

    $c->stash->{errors} ||= [];
    push @{ $c->stash->{errors} },
      _('There were problems with your update. Please see below.');

    return;
}

=head2 save_update

Save the update and the user as appropriate.

=cut

sub save_update : Private {
    my ( $self, $c ) = @_;

    my $update = $c->stash->{update};

    if ( !$update->user->in_storage ) {
        $update->user->insert;
    }
    elsif ( $c->user && $c->user->id == $update->user->id ) {
        # Logged in and same user, so can confirm update straight away
        $update->user->update;
        $update->confirm;
    }

    # If there was a photo add that too
    if ( my $fileid = $c->stash->{upload_fileid} ) {
        my $file = file( $c->config->{UPLOAD_CACHE}, "$fileid.jpg" );
        my $blob = $file->slurp;
        $file->remove;
        $update->photo($blob);
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
        my $report_uri = $c->uri_for( '/report', $update->problem_id );
        $c->res->redirect($report_uri);
        $c->detach;
    }

    # otherwise create a confirm token and email it to them.
    my $token = $c->model("DB::Token")->create(
        {
            scope => 'comment',
            data  => {
                id        => $update->id,
                add_alert => ( $c->req->param('add_alert') ? 1 : 0 ),
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
new_updates alert.

NB: this does not check if they are a registered user so that should
happen before calling this.

=cut

sub signup_for_alerts : Private {
    my ( $self, $c ) = @_;

    if ( $c->stash->{add_alert} ) {
        my $update = $c->stash->{update};
        my $alert = $c->model('DB::Alert')->find_or_create(
            user         => $update->user,
            alert_type   => 'new_updates',
            parameter    => $update->problem_id,
            cobrand      => $update->cobrand,
            cobrand_data => $update->cobrand_data,
            lang         => $update->lang,
        );

        $alert->confirm();
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
