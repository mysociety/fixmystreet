package FixMyStreet::App::Controller::Questionnaire;

use Moose;
use namespace::autoclean;
use Path::Class;
use Utils;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Questionnaire - Catalyst Controller

=head1 DESCRIPTION

Deals with report questionnaires.

=head1 METHODS

=cut

=head2 check_questionnaire

Checks the questionnaire still needs answering and is in the right state. Also
finds out if this user has answered the "ever reported" question before.

=cut

sub check_questionnaire : Private {
    my ( $self, $c ) = @_;

    my $questionnaire = $c->stash->{questionnaire};

    my $problem = $questionnaire->problem;

    if ( $questionnaire->whenanswered ) {
        my $problem_url = $c->cobrand->base_url_for_report( $problem ) . $problem->url;
        my $contact_url = $c->uri_for( "/contact" );
        $c->stash->{message} = sprintf(_("You have already answered this questionnaire. If you have a question, please <a href='%s'>get in touch</a>, or <a href='%s'>view your problem</a>.\n"), $contact_url, $problem_url);
        $c->stash->{template} = 'errors/generic.html';
        $c->detach;
    }

    unless ( $problem->is_visible ) {
        $c->detach('missing_problem');
    }

    $c->stash->{problem} = $problem;
    $c->stash->{answered_ever_reported} = $problem->user->answered_ever_reported;

    # EHA needs to know how many to alter display, and whether to send another or not
    if ($c->cobrand->moniker eq 'emptyhomes') {
        $c->stash->{num_questionnaire} = $c->model('DB::Questionnaire')->count(
            { problem_id => $problem->id }
        );
    }

}

=head2 submit

If someone submits a questionnaire - either a full style one (when we'll have a
token), or the mini own-report one (when we'll have a problem ID).

=cut

sub submit : Path('submit') {
    my ( $self, $c ) = @_;

    if (my $token = $c->get_param('token')) {
        if ($token eq '_test_') {
            $c->stash->{been_fixed} = $c->get_param('been_fixed');
            $c->stash->{new_state} = $c->get_param('new_state');
            $c->stash->{template} = 'questionnaire/completed.html';
            return;
        }
        $c->forward('submit_standard');
    } elsif (my $p = $c->get_param('problem')) {
        $c->detach('creator_fixed') if $p eq '_test_';
        $c->forward('submit_creator_fixed');
    } else {
        $c->detach( '/page_error_404_not_found' );
    }

    return 1;
}

=head2 missing_problem

Display couldn't locate problem error message

=cut

sub missing_problem : Private {
    my ( $self, $c ) = @_;

    $c->stash->{message} = _("I'm afraid we couldn't locate your problem in the database.\n");
    $c->stash->{template} = 'errors/generic.html';
}

sub submit_creator_fixed : Private {
    my ( $self, $c ) = @_;

    my @errors;

    $c->stash->{reported} = $c->get_param('reported');
    $c->stash->{problem_id} = $c->get_param('problem');

    # should only be able to get to here if we are logged and we have a
    # problem
    unless ( $c->user && $c->stash->{problem_id} ) {
        $c->detach('missing_problem');
    }

    my $problem = $c->cobrand->problems->find( { id => $c->stash->{problem_id} } );
    $c->stash->{problem} = $problem;

    # you should not be able to answer questionnaires about problems
    # that you've not submitted
    if ( $c->user->id != $problem->user->id ) {
        $c->detach('missing_problem');
    }

    push @errors, _('Please say whether you\'ve ever reported a problem to your council before') unless $c->stash->{reported};

    $c->stash->{errors} = \@errors;
    $c->detach( 'creator_fixed' ) if scalar @errors;

    my $questionnaire = $c->model( 'DB::Questionnaire' )->find_or_new(
        {
            problem_id => $c->stash->{problem_id},
            # we want to look for any previous questionnaire here rather than one for
            # this specific open state -> fixed transistion
            old_state  => [ FixMyStreet::DB::Result::Problem->open_states() ],
            new_state  => 'fixed - user',
        }
    );

    unless ( $questionnaire->in_storage ) {
        my $old_state = $c->flash->{old_state};
        $old_state = 'confirmed' unless FixMyStreet::DB::Result::Problem->open_states->{$old_state};

        $questionnaire->ever_reported( $c->stash->{reported} eq 'Yes' ? 1 : 0 );
        $questionnaire->old_state( $old_state );
        $questionnaire->whensent( \'ms_current_timestamp()' );
        $questionnaire->whenanswered( \'ms_current_timestamp()' );
        $questionnaire->insert;
    }

    $c->stash->{creator_fixed} = 1;
    $c->stash->{template} = 'tokens/confirm_update.html';

    return 1;
}

sub submit_standard : Private {
    my ( $self, $c ) = @_;

    $c->forward( '/tokens/load_questionnaire', [ $c->get_param('token') ] );
    $c->forward( 'check_questionnaire' );
    $c->forward( 'process_questionnaire' );

    my $problem = $c->stash->{problem};
    my $old_state = $problem->state;
    my $new_state = '';
    $new_state = 'fixed - user' if $c->stash->{been_fixed} eq 'Yes' && 
        FixMyStreet::DB::Result::Problem->open_states()->{$old_state};
    $new_state = 'fixed - user' if $c->stash->{been_fixed} eq 'Yes' &&
        FixMyStreet::DB::Result::Problem->closed_states()->{$old_state};
    $new_state = 'confirmed' if $c->stash->{been_fixed} eq 'No' &&
        FixMyStreet::DB::Result::Problem->fixed_states()->{$old_state};

    # Record state change, if there was one
    if ( $new_state ) {
        $problem->state( $new_state );
        $problem->lastupdate( \'ms_current_timestamp()' );
    }

    # If it's not fixed and they say it's still not been fixed, record time update
    if ( $c->stash->{been_fixed} eq 'No' &&
        FixMyStreet::DB::Result::Problem->open_states->{$old_state} ) {
        $problem->lastupdate( \'ms_current_timestamp()' );
    }

    # Record questionnaire response
    my $reported = undef;
    $reported = 1 if $c->stash->{reported} eq 'Yes';
    $reported = 0 if $c->stash->{reported} eq 'No';

    my $q = $c->stash->{questionnaire};
    $q->update( {
        whenanswered  => \'ms_current_timestamp()',
        ever_reported => $reported,
        old_state     => $old_state,
        new_state     => $c->stash->{been_fixed} eq 'Unknown' ? 'unknown' : ($new_state || $old_state),
    } );

    # Record an update if they've given one, or if there's a state change
    if ( $new_state || $c->stash->{update} ) {
        my $update = $c->stash->{update} || _('Questionnaire filled in by problem reporter');
        $update = $c->model('DB::Comment')->new(
            {
                problem      => $problem,
                name         => $problem->name,
                user         => $problem->user,
                text         => $update,
                state        => 'confirmed',
                mark_fixed   => $new_state eq 'fixed - user' ? 1 : 0,
                mark_open    => $new_state eq 'confirmed' ? 1 : 0,
                lang         => $c->stash->{lang_code},
                cobrand      => $c->cobrand->moniker,
                cobrand_data => '',
                confirmed    => \'ms_current_timestamp()',
                anonymous    => $problem->anonymous,
            }
        );
        if ( my $fileid = $c->stash->{upload_fileid} ) {
            $update->photo( $fileid );
        }
        $update->insert;
    }

    # If they've said they want another questionnaire, mark as such
    $problem->send_questionnaire( 1 )
        if ($c->stash->{been_fixed} eq 'No' || $c->stash->{been_fixed} eq 'Unknown') && $c->stash->{another} eq 'Yes';
    $problem->update;

    $c->stash->{new_state} = $new_state;
    $c->stash->{template} = 'questionnaire/completed.html';
}

sub process_questionnaire : Private {
    my ( $self, $c ) = @_;

    map { $c->stash->{$_} = $c->get_param($_) || '' } qw(been_fixed reported another update);

    # EHA questionnaires done for you
    if ($c->cobrand->moniker eq 'emptyhomes') {
        $c->stash->{another} = $c->stash->{num_questionnaire}==1 ? 'Yes' : 'No';
    }

    my @errors;
    push @errors, _('Please state whether or not the problem has been fixed')
        unless $c->stash->{been_fixed};

    if ($c->cobrand->ask_ever_reported) {
        push @errors, _('Please say whether you\'ve ever reported a problem to your council before')
            unless $c->stash->{reported} || $c->stash->{answered_ever_reported};
    }

    push @errors, _('Please indicate whether you\'d like to receive another questionnaire')
        if ($c->stash->{been_fixed} eq 'No' || $c->stash->{been_fixed} eq 'Unknown') && !$c->stash->{another};

    push @errors, _('Please provide some explanation as to why you\'re reopening this report')
        if $c->stash->{been_fixed} eq 'No' && $c->stash->{problem}->is_fixed() && !$c->stash->{update};

    $c->forward('/photo/process_photo');
    push @errors, $c->stash->{photo_error}
        if $c->stash->{photo_error};

    push @errors, _('Please provide some text as well as a photo')
        if $c->stash->{upload_fileid} && !$c->stash->{update};

    if (@errors) {
        $c->stash->{errors} = [ @errors ];
        $c->detach( 'display' );
    }
}

# Sent here from email token action. Simply load and display questionnaire.
sub show : Private {
    my ( $self, $c ) = @_;
    $c->forward( 'check_questionnaire' );
    $c->forward( 'display' );
}

=head2 display

Displays a questionnaire, either after bad submission or directly from email token.

=cut

sub display : Private {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'questionnaire/index.html';

    my $problem = $c->stash->{questionnaire}->problem;

    $c->stash->{updates} = [ $c->model('DB::Comment')->search(
        { problem_id => $problem->id, state => 'confirmed' },
        { order_by => 'confirmed' }
    )->all ];

    $c->stash->{page} = 'questionnaire';
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        pins      => [ {
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            colour    => $c->cobrand->pin_colour( $problem, 'questionnaire' ),
        } ],
    );
}

=head2 creator_fixed

Display the reduced questionnaire that we display when the reporter of a
problem submits an update marking it as fixed.

=cut

sub creator_fixed : Private {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'questionnaire/creator_fixed.html';

    return 1;
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;

