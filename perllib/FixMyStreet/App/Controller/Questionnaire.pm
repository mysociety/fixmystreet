package FixMyStreet::App::Controller::Questionnaire;

use Moose;
use namespace::autoclean;
#use Utils;
#use Error qw(:try);
#use CrossSell;
#use mySociety::Locale;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Questionnaire - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub load_questionnaire : Private {
    my ( $self, $c ) = @_;

    my $questionnaire = $c->model('DB::Questionnaire')->find(
        { id => $c->stash->{id} },
        { prefetch => 'problem' }
    );
    $c->stash->{questionnaire} = $questionnaire;

    my $problem_id = $questionnaire->problem_id;

    if ( $questionnaire->whenanswered ) {
        my $problem_url = $c->uri_for( "/report/$problem_id" );
        my $contact_url = $c->uri_for( "/contact" );
        $c->stash->{message} = sprintf(_("You have already answered this questionnaire. If you have a question, please <a href='%s'>get in touch</a>, or <a href='%s'>view your problem</a>.\n"), $contact_url, $problem_url);
        $c->stash->{template} = 'questionnaire/error.html';
        $c->detach;
    }

    # FIXME problem fetched information
    # extract(epoch from confirmed) as time, extract(epoch from whensent-confirmed) as whensent
    # state in ('confirmed','fixed')
    $c->stash->{problem} = $questionnaire->problem;
    # throw Error::Simple(_("I'm afraid we couldn't locate your problem in the database.\n")) unless $problem;

    $c->stash->{answered_ever_reported} = $c->model('DB::Questionnaire')->count(
        { 'problem.user_id' => $c->stash->{problem}->user_id,
          ever_reported     => { '!=', undef },
        },
        { join => 'problem' }
    );
}

sub submit : Path('submit') {
    my ( $self, $c ) = @_;

    if ( $c->req->params->{token} ) {
        $c->forward('submit_standard');
    } elsif ( $c->req->params->{problem} ) {
        $c->forward('submit_creator_fixed');
    } else {
        return;
    }

    return 1;
}

sub submit_creator_fixed : Private {
    my ( $self, $c ) = @_;

    my @errors;

    map { $c->stash->{$_} = $c->req->params->{$_} || '' } qw(reported problem);

    push @errors, _('Please say whether you\'ve ever reported a problem to your council before') unless $c->stash->{reported};

    $c->stash->{problem_id} = $c->stash->{problem};
    $c->stash->{errors} = \@errors;
    $c->detach( 'creator_fixed' ) if scalar @errors;

    my $questionnaire = $c->model( 'DB::Questionnaire' )->find_or_new(
        {
            problem_id => $c->stash->{problem},
            old_state  => 'confirmed',
            new_state  => 'fixed',
        }
    );

    unless ( $questionnaire->in_storage ) {
        $questionnaire->ever_reported( $c->stash->{reported} eq 'Yes' ? 'y' : 'n' );
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

    $c->forward( '/tokens/load_questionnaire_id', [ $c->req->params->{token} ] );
    $c->forward( 'load_questionnaire' );

    my $questionnaire = $c->stash->{questionnaire};
    my $problem = $questionnaire->problem;

    $c->stash->{num_questionnaire} = $c->model('DB::Questionnaire')->count(
        { problem_id => $problem->id }
    );

    map { $c->stash->{$_} = $c->req->params->{$_} || '' } qw(been_fixed reported another update);
    # EHA questionnaires done for you
    if ($c->cobrand->moniker eq 'emptyhomes') {
        $c->stash->{another} = $c->stash->{num_questionnaire}==1 ? 'Yes' : 'No';
    }

    my @errors;
    push @errors, _('Please state whether or not the problem has been fixed') unless $c->stash->{been_fixed};
    my $ask_ever_reported = $c->cobrand->ask_ever_reported;
    if ($ask_ever_reported) {
        push @errors, _('Please say whether you\'ve ever reported a problem to your council before') unless $c->stash->{reported} || $c->stash->{answered_ever_reported};
    }
    push @errors, _('Please indicate whether you\'d like to receive another questionnaire')
        if ($c->stash->{been_fixed} eq 'No' || $c->stash->{been_fixed} eq 'Unknown') && !$c->stash->{another};
    push @errors, _('Please provide some explanation as to why you\'re reopening this report')
        if $c->stash->{been_fixed} eq 'No' && $problem->state eq 'fixed' && !$c->stash->{update};
    if (@errors) {
        $c->stash->{errors} = [ @errors ];
        $c->detach( 'display' );
    }

#     my $fh = $q->upload('photo');
#     my $image;
#     if ($fh) {
#         my $err = Page::check_photo($q, $fh);
#         push @errors, $err if $err;
#         try {
#             $image = Page::process_photo($fh) unless $err;
#         } catch Error::Simple with {
#             my $e = shift;
#             push(@errors, "That image doesn't appear to have uploaded correctly ($e), please try again.");
#         };
#     }
#     push @errors, _('Please provide some text as well as a photo')
#         if $image && !$input{update};
#     return display_questionnaire($q, @errors) if @errors;
# 
#     my $new_state = '';
#     $new_state = 'fixed' if $input{been_fixed} eq 'Yes' && $problem->{state} eq 'confirmed';
#     $new_state = 'confirmed' if $input{been_fixed} eq 'No' && $problem->{state} eq 'fixed';
# 
#     # Record state change, if there was one
#     dbh()->do("update problem set state=?, lastupdate=ms_current_timestamp()
#         where id=?", {}, $new_state, $problem->{id})
#         if $new_state;
# 
#     # If it's not fixed and they say it's still not been fixed, record time update
#     dbh()->do("update problem set lastupdate=ms_current_timestamp()
#         where id=?", {}, $problem->{id})
#         if $input{been_fixed} eq 'No' && $problem->{state} eq 'confirmed';
# 
#     # Record questionnaire response
#     my $reported = $input{reported}
#         ? ($input{reported} eq 'Yes' ? 't' : ($input{reported} eq 'No' ? 'f' : undef))
#         : undef;
#     dbh()->do('update questionnaire set whenanswered=ms_current_timestamp(),
#         ever_reported=?, old_state=?, new_state=? where id=?', {},
#         $reported, $problem->{state}, $input{been_fixed} eq 'Unknown'
#             ? 'unknown'
#             : ($new_state ? $new_state : $problem->{state}),
#         $questionnaire->{id});
# 
#     # Record an update if they've given one, or if there's a state change
#     my $name = $problem->{anonymous} ? undef : $problem->{name};
#     my $update = $input{update} ? $input{update} : _('Questionnaire filled in by problem reporter');
#     Utils::workaround_pg_bytea("insert into comment
#         (problem_id, name, email, website, text, state, mark_fixed, mark_open, photo, lang, cobrand, cobrand_data, confirmed)
#         values (?, ?, ?, '', ?, 'confirmed', ?, ?, ?, ?, ?, ?, ms_current_timestamp())", 7,
#         $problem->{id}, $name, $problem->{email}, $update,
#         $new_state eq 'fixed' ? 't' : 'f', $new_state eq 'confirmed' ? 't' : 'f',
#         $image, $mySociety::Locale::lang, $cobrand, $c->cobrand->extra_data
#     )
#         if $new_state || $input{update};
# 
#     # If they've said they want another questionnaire, mark as such
#     dbh()->do("update problem set send_questionnaire = 't' where id=?", {}, $problem->{id})
#         if ($input{been_fixed} eq 'No' || $input{been_fixed} eq 'Unknown') && $input{another} eq 'Yes';
#     dbh()->commit();
# 
#     my $out;
#     my $message;
#     my $advert_outcome = 1;
#     if ($input{been_fixed} eq 'Unknown') {
#         $message = _(<<EOF);
# <p>Thank you very much for filling in our questionnaire; if you
# get some more information about the status of your problem, please come back to the
# site and leave an update.</p>
# EOF
#     } elsif ($new_state eq 'confirmed' || (!$new_state && $problem->{state} eq 'confirmed')) {
#         my $wtt_url = Cobrand::writetothem_url($cobrand, $c->cobrand->extra_data);
#         $wtt_url = "http://www.writetothem.com" if (! $wtt_url);
#         $message = sprintf(_(<<EOF), $wtt_url);
# <p style="font-size:150%%">We're sorry to hear that. We have two suggestions: why not try
# <a href="%s">writing direct to your councillor(s)</a>
# or, if it's a problem that could be fixed by local people working together,
# why not <a href="http://www.pledgebank.com/new">make and publicise a pledge</a>?
# </p>
# EOF
#         $advert_outcome = 0;
#     } else {
#         $message = _(<<EOF);
# <p style="font-size:150%">Thank you very much for filling in our questionnaire; glad to hear it's been fixed.</p>
# EOF
#     }
#     $out = $message;
#     my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
#     if ($display_advert && $advert_outcome) {
#         $out .= CrossSell::display_advert($q, $problem->{email}, $problem->{name},
#             council => $problem->{council});
#     }
#     my %vars = (message => $message);
#     my $template_page = Page::template_include('questionnaire-completed', $q, Page::template_root($q), %vars);
#     return $template_page if ($template_page);
#     return $out;
}

# Sent here from email token action. Simply load and display questionnaire.
sub index : Private {
    my ( $self, $c ) = @_;
    $c->forward( 'load_questionnaire' );
    $c->forward( 'display' );
}

# Displays the questionnaire, either after bad submission or from email token
sub display : Private {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'questionnaire/index.html';

    my $problem = $c->stash->{questionnaire}->problem;

    ( $c->stash->{short_latitude}, $c->stash->{short_longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $problem->latitude, $problem->longitude );

    my $updates = $c->model('DB::Comment')->search(
        { problem_id => $problem->id, state => 'confirmed' },
        { order_by => 'confirmed' }
    );
    $c->stash->{updates} = $updates;

    $c->stash->{map_start_html} = FixMyStreet::Map::display_map(
        $c,
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        pins      => [ {
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            colour    => $problem->state eq 'fixed' ? 'green' : 'red',
        } ],
    );
    $c->stash->{map_js}                = FixMyStreet::Map::header_js();
    $c->stash->{cobrand_form_elements} = $c->cobrand->form_elements('questionnaireForm');
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

