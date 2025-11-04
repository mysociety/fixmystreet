package FixMyStreet::App::Controller::Report;

use utf8;
use Moose;
use namespace::autoclean;
use JSON::MaybeXS;
use List::MoreUtils qw(any);
use Utils;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Report - display a report

=head1 DESCRIPTION

Show a report

=head1 ACTIONS

=head2 index

Redirect to homepage unless we have a homepage template,
in which case show that.

=cut

sub index : Path('') : Args(0) {
    my ( $self, $c ) = @_;

    if ($c->stash->{homepage_template}) {
        $c->stash->{template} = 'index.html';
    } else {
        $c->res->redirect('/');
    }
}

=head2 id

Load in ID, for use by chained pages.

=cut

sub id :PathPart('report') :Chained :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    if (
        $id =~ m{ ^ 3D (\d+) $ }x         # Some council with bad email software
        || $id =~ m{ ^(\d+) \D .* $ }x    # trailing garbage
      )
    {
        $c->res->redirect( $c->uri_for($1), 301 );
        $c->detach;
    }

    $c->forward( 'load_problem_or_display_error', [ $id ] );
}

=head2 ajax

Return JSON formatted details of a report.
URL used by mobile app so remains /report/ajax/N.

=cut

sub ajax : Path('ajax') : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash->{ajax} = 1;
    $c->forward('/set_app_cors_header');
    $c->forward('load_problem_or_display_error', [ $id ]);
    $c->forward('display');
}

=head2 display

Display a report.

=cut

sub display :PathPart('') :Chained('id') :Args(0) {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};
    if ($problem->cobrand_data eq 'waste' && ($problem->category eq 'Bulky collection' || $problem->category eq 'Small items collection')) {
        $c->detach('/waste/bulky/view');
    }

    $c->forward('/auth/get_csrf_token');
    $c->forward( 'load_updates' );
    $c->forward( 'format_problem_for_display' );

    my $permissions = $c->stash->{permissions} ||= $c->forward('fetch_permissions');

    my $staff_user = $c->user_exists && ($c->user->is_superuser || $c->user->belongs_to_body($c->stash->{problem}->bodies_str));

    if ($staff_user) {
        # Check assigned categories feature
        my $okay = 1;
        my $contact = $c->stash->{problem}->contact;
        if ($contact && ($c->user->get_extra_metadata('assigned_categories_only') || $contact->get_extra_metadata('assigned_users_only'))) {
            my $user_cats = $c->user->categories || [];
            $okay = any { $contact->category eq $_ } @$user_cats;
        }
        if ($okay) {
            $c->stash->{relevant_staff_user} = 1;
        } else {
            # Remove all staff permissions
            $permissions = $c->stash->{permissions} = {};
        }
    }

    if (grep { $permissions->{$_} } qw/report_inspect report_edit_category report_edit_priority report_mark_private triage/) {
        $c->stash->{template} = 'report/inspect.html';
        $c->forward('inspect');
    }

    if ($permissions->{contribute_as_another_user}) {
        $c->stash->{email} = $c->user->email;
    }
}

sub moderate_report :PathPart('moderate') :Chained('id') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->user_exists && $c->user->can_moderate($c->stash->{problem})) {
        $c->stash->{show_moderation} = 'report';
        $c->stash->{template} = 'report/display.html';
        $c->detach('display');
    }
    $c->res->redirect($c->stash->{problem}->url);
}

sub moderate_update :PathPart('moderate') :Chained('id') :Args(1) {
    my ( $self, $c, $update_id ) = @_;

    my $comment = $c->stash->{problem}->comments->find($update_id);
    if ($c->user_exists && $comment && $c->user->can_moderate($comment)) {
        $c->stash->{show_moderation} = $update_id;
        $c->stash->{template} = 'report/display.html';
        $c->detach('display');
    }
    $c->res->redirect($c->stash->{problem}->url);
}

sub support :Chained('id') :Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->cobrand->can_support_problems && $c->user && $c->user->from_body ) {
        $c->stash->{problem}->update( { interest_count => \'interest_count +1' } );
    }

    $c->res->redirect($c->stash->{problem}->url);
}

sub load_problem_or_display_error : Private {
    my ( $self, $c, $id ) = @_;

    my $attrs = { prefetch => 'contact' };

    # try to load a report if the id is a number
    my $problem
      = ( !$id || $id =~ m{\D} ) # is id non-numeric?
      ? undef                    # ...don't even search
      : $c->cobrand->problems->find( { id => $id }, $attrs )
          or $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );

    # check that the problem is suitable to show.
    # hidden_states includes partial and unconfirmed, but they have specific handling,
    # so we check for them first.
    if ( $problem->state eq 'partial' ) {
        $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );
    }
    elsif ( $problem->state eq 'unconfirmed' ) {
        $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] )
            unless $c->cobrand->show_unconfirmed_reports ;
    }
    elsif ( $problem->hidden_states->{ $problem->state } ) {
        $c->detach(
            '/page_error_410_gone',
            [ _('That report has been removed from FixMyStreet.') ]    #
        );
    } elsif ( $problem->non_public ) {
        # Creator, and inspection users can see non_public reports
        $c->stash->{problem} = $problem;
        my $permissions = $c->stash->{permissions} = $c->forward('fetch_permissions');

        # If someone has clicked a unique token link in an email to them
        my $from_email = $c->sessionid && $c->flash->{alert_to_reporter} && $c->flash->{alert_to_reporter} == $problem->id;

        my $allowed = 0;
        $allowed = 1 if $from_email;
        $allowed = 1 if $c->user_exists && $c->user->id == $problem->user->id;
        $allowed = 1 if $permissions->{report_inspect} || $permissions->{report_mark_private};

        unless  ($allowed) {
            my $url = '/auth?r=report/' . $problem->id;
            $c->detach(
                '/page_error_403_access_denied',
                [ sprintf(_('Sorry, you don’t have permission to do that. If you are the problem reporter, or a member of staff, please <a href="%s">sign in</a> to view this report.'), $url) ]
            );
        }
    }

    $c->cobrand->call_hook(munge_problem_list => $problem);
    $c->stash->{problem} = $problem;
    if ( $c->user_exists && $c->user->can_moderate($problem) ) {
        $c->stash->{original} = $problem->find_or_new_related(
            moderation_original_data => {
                title => $problem->title,
                detail => $problem->detail,
                photo => $problem->photo,
                anonymous => $problem->anonymous,
            }
        );
    }

    return 1;
}

sub load_updates : Private {
    my ( $self, $c ) = @_;

    my $updates = $c->cobrand->updates->search(
        { problem_id => $c->stash->{problem}->id, "me.state" => 'confirmed' },
        { order_by => [ 'me.confirmed', 'me.id' ] }
    );

    my $questionnaires_still_open = $c->model('DB::Questionnaire')->search(
        {
            problem_id => $c->stash->{problem}->id,
            whenanswered => { '!=', undef },
            -or => [ {
                # Any steady state open/closed
                old_state => [ -and =>
                    { -in => [ FixMyStreet::DB::Result::Problem::closed_states, FixMyStreet::DB::Result::Problem::open_states ] },
                    \'= new_state',
                ],
            }, {
                # Any reopening
                new_state => 'confirmed',
            } ]
        },
        { order_by => 'whenanswered' }
    );

    my $questionnaires_fixed = $c->model('DB::Questionnaire')->search(
        {
            problem_id => $c->stash->{problem}->id,
            whenanswered => { '!=', undef },
            old_state => { -not_in => [ FixMyStreet::DB::Result::Problem::fixed_states ] },
            new_state => { -in => [ FixMyStreet::DB::Result::Problem::fixed_states ] },
        },
        { order_by => 'whenanswered' }
    );

    my @combined;
    my %questionnaires_with_updates;
    while (my $update = $updates->next) {
        $c->cobrand->call_hook(munge_update_list => $update);
        push @combined, [ $update->confirmed, $update ];
        if (my $qid = $update->get_extra_metadata('questionnaire_id')) {
            $questionnaires_with_updates{$qid} = $update;
        }
    }
    while (my $q = $questionnaires_still_open->next) {
        if (my $update = $questionnaires_with_updates{$q->id}) {
            $update->set_extra_metadata('open_from_questionnaire', 1);
            next;
        }
        push @combined, [ $q->whenanswered, $q ];
    }
    while (my $q = $questionnaires_fixed->next) {
        next if $questionnaires_with_updates{$q->id};
        push @combined, [ $q->whenanswered, $q ];
    }

    # And include moderation changes...
    my $problem = $c->stash->{problem};
    my $public_history = $c->cobrand->call_hook(public_moderation_history => $problem);
    my $user_can_moderate = $c->user_exists && $c->user->can_moderate($problem);
    if ($public_history || $user_can_moderate) {
        my @history = $problem->moderation_history;
        my $last_history = $problem;
        foreach my $history (@history) {
            push @combined, [ $history->created, {
                id => 'm' . $history->id,
                type => 'moderation',
                last => $last_history,
                entry => $history,
            } ];
            $last_history = $history;
        }
    }

    @combined = map { $_->[1] } sort { $a->[0] <=> $b->[0] } @combined;
    $c->stash->{updates} = \@combined;

    if ($c->sessionid) {
        foreach (qw(alert_to_reporter anonymized)) {
            $c->stash->{$_} = $c->flash->{$_} if $c->flash->{$_};
        }
    }

    return 1;
}

sub format_problem_for_display : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    # upload_fileid is used by the update form on this page
    $c->stash->{problem_upload_fileid} = $problem->get_photoset->data;

    ( $c->stash->{latitude}, $c->stash->{longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $problem->latitude, $problem->longitude );

    unless ( $c->get_param('submit_update') ) {
        $c->stash->{add_alert} = 1;
    }

    my $first_body = (values %{$problem->bodies})[0];
    $c->stash->{extra_name_info} = $first_body && $first_body->get_column('name') =~ /Bromley/ ? 1 : 0;

    $c->forward('generate_map_tags');

    if ( $c->stash->{ajax} ) {
        $c->res->content_type('application/json; charset=utf-8');

        # encode_json doesn't like DateTime objects, so strip them out
        my $report_hashref = $c->cobrand->problem_as_hashref( $problem );
        delete $report_hashref->{created};
        delete $report_hashref->{confirmed};

        my $json = JSON::MaybeXS->new( convert_blessed => 1, utf8 => 1 );
        my $content = $json->encode(
            {
                report => $report_hashref,
                updates => $c->cobrand->updates_as_hashref( $problem ),
            }
        );
        $c->res->body( $content );
        return 1;
    }

    return 1;
}

sub generate_map_tags : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    $c->stash->{page} = 'report';
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        no_compass => 1,
        pins      => $problem->used_map
            ? [ $problem->pin_data('report', type => 'big', draggable => 1) ]
            : [],
    );

    return 1;
}

=head2 delete

Endpoint for the council report hiding feature enabled for
C<users_can_hide> bodies, and Bromley. The latter is migrating
to moderation, however we'd need to inform all the other
users too about this change, at which point we can delete:

 - this method
 - the call to it in templates/web/base/report/display_tools.html
 - the users_can_hide cobrand method, in favour of user->has_permission_to

=cut

sub delete :Chained('id') :Args(0) {
    my ($self, $c) = @_;

    $c->forward('/auth/check_csrf_token');

    my $p = $c->stash->{problem};

    return $c->res->redirect($p->url) unless $c->user_exists;

    my $body = $c->user->obj->from_body;
    return $c->res->redirect($p->url) unless $body;
    return $c->res->redirect($p->url) unless $p->bodies->{$body->id};

    $p->state('hidden');
    $p->lastupdate( \'current_timestamp' );
    $p->update;

    $c->model('DB::AdminLog')->create( {
        user => $c->user->obj,
        admin_user => $c->user->from_body->name,
        object_type => 'problem',
        action => 'state_change',
        object_id => $p->id,
    } );

    return $c->res->redirect($p->url);
}

sub inspect : Private {
    my ( $self, $c ) = @_;
    my $problem = $c->stash->{problem};
    my $permissions = $c->stash->{permissions};

    $c->forward('/admin/reports/categories_for_point');
    $c->stash->{report_meta} = { map { 'x' . $_->{name} => $_ } @{ $c->stash->{problem}->get_extra_fields() } };

    if ($c->cobrand->body) {
        my $priorities_by_category = $c->model('DB::ResponsePriority')->by_categories(
            $c->stash->{contacts},
            body_id => $c->cobrand->body->id,
            problem => $problem,
        );
        $c->stash->{priorities_by_category} = $priorities_by_category;
        my $templates_by_category = $c->model('DB::ResponseTemplate')->by_categories(
            $c->stash->{contacts},
            body_id => $c->cobrand->body->id
        );
        $c->stash->{templates_by_category} = $templates_by_category;
    }

    if ($c->user->has_body_permission_to('planned_reports')) {
        $c->stash->{post_inspect_url} = $c->req->referer;
    }

    if ($c->user->has_body_permission_to('report_edit_priority') or
        $c->user->has_body_permission_to('report_inspect')
      ) {
        $c->stash->{has_default_priority} = scalar( grep { $_->is_default } $problem->response_priorities );
    }

    $c->stash->{max_detailed_info_length} = $c->cobrand->max_detailed_info_length;

    if ( $c->get_param('triage') ) {
        $c->forward('/auth/check_csrf_token');
        $c->forward('/admin/triage/update');
        my $redirect_uri = $c->uri_for( '/admin/triage' );
        $c->log->debug( "Redirecting to: " . $redirect_uri );
        $c->res->redirect( $redirect_uri );
    }
    elsif ( $c->get_param('save') ) {
        $c->forward('/auth/check_csrf_token');

        my $valid = 1;
        my $update_text = '';
        my %update_params = ();

        if ($permissions->{report_inspect}) {
            my $old_detailed_information
                = $problem->get_extra_metadata('detailed_information') // '';
            if ( my $info = $c->get_param('detailed_information') ) {
                $problem->set_extra_metadata( detailed_information => $info );
                if ($c->cobrand->max_detailed_info_length &&
                    length($info) > $c->cobrand->max_detailed_info_length
                ) {
                    $valid = 0;
                    push @{ $c->stash->{errors} },
                        sprintf(
                            _('Detailed information is limited to %d characters.'),
                            $c->cobrand->max_detailed_info_length
                        );
                }
            } else {
                $problem->unset_extra_metadata('detailed_information');
            }

            my $handler
                = $c->cobrand->call_hook(
                    get_body_handler_for_problem => $problem
                ) || $c->cobrand;
            my $record_extra
                = $handler->call_hook('record_update_extra_fields');
            if (
                $record_extra->{detailed_information}
                && ( $problem->get_extra_metadata('detailed_information') // '' )
                ne $old_detailed_information
            ) {
                $update_params{extra}{detailed_information} = 1;
            }

            if ( $c->get_param('include_update') or $c->get_param('raise_defect') ) {
                $update_text = Utils::cleanup_text( $c->get_param('public_update'), { allow_multiline => 1 } );
                if (!$update_text) {
                    $valid = 0;
                    $c->stash->{errors} ||= [];
                    push @{ $c->stash->{errors} }, _('Please provide a public update for this report.');
                }
            }

            # Handle the state changing
            my $old_state = $problem->state;
            $problem->state($c->get_param('state'));
            if ( $problem->is_visible() and $old_state eq 'unconfirmed' ) {
                $problem->confirmed( \'current_timestamp' );
            }
            if ( $problem->state eq 'hidden' ) {
                $problem->get_photoset->delete_cached(plus_updates => 1);
            }
            if ( $problem->state eq 'duplicate') {
                if (my $duplicate_of = $c->get_param('duplicate_of')) {
                    $problem->set_duplicate_of($duplicate_of);
                } elsif (not $c->get_param('include_update')) {
                    $valid = 0;
                    push @{ $c->stash->{errors} }, _('Please provide a duplicate ID or public update for this report.');
                }
            } else {
                $problem->unset_extra_metadata('duplicate_of');
            }

            if ( $problem->state ne $old_state ) {
                $c->forward( '/admin/log_edit', [ $problem->id, 'problem', 'state_change' ] );

                $update_params{problem_state} = $problem->state;

                # If an inspector has changed the state, subscribe them to
                # updates
                my $options = {
                    cobrand      => $c->cobrand->moniker,
                    cobrand_data => $problem->cobrand_data,
                    lang         => $problem->lang,
                };
                $c->user->create_alert($problem->id, $options);
            }

            # If the state has been changed to action scheduled and they've said
            # they want to raise a defect, consider the report to be inspected.
            if ($problem->state eq 'action scheduled' && $c->get_param('raise_defect') && !$problem->get_extra_metadata('inspected')) {
                $update_params{extra}{defect_raised} = 1;
                $problem->set_extra_metadata( inspected => 1 );
                $c->forward( '/admin/log_edit', [ $problem->id, 'problem', 'inspected' ] );
            }
        }

        # set assignment
        my $assigned = ($c->get_param('assignment'));
        if ($assigned && $assigned eq 'unassigned') {
            # take off shortlist
            my $current_assignee = $problem->shortlisted_user;
            $current_assignee->remove_from_planned_reports($problem)
                if $current_assignee;
        } elsif ($assigned) {
            my $assignee = $c->model('DB::User')->find({ id => $assigned });
            $assignee->add_to_planned_reports($problem);
        }

        my $non_public = $c->get_param('non_public') ? 1 : 0;
        if ($non_public != $problem->non_public) {
            my $change = $non_public ? _('Marked private') : _('Marked public');
            $c->forward( '/admin/log_edit', [ $problem->id, 'problem', $change ] );
            $problem->non_public($non_public);
        }

        if ($problem->non_public) {
            $problem->get_photoset->delete_cached(plus_updates => 1);
        }

        if ( !$c->forward( '/admin/reports/edit_location', [ $problem ] ) ) {
            # New lat/lon isn't valid, show an error
            $valid = 0;
            $c->stash->{errors} ||= [];
            push @{ $c->stash->{errors} }, _('Invalid location. New location must be covered by the same council.');
        }

        if ($permissions->{report_inspect} || $permissions->{report_edit_category}) {
            $c->forward( '/admin/reports/edit_category', [ $problem, 1 ] );

            if ($c->stash->{update_text}) {
                $update_text .= "\n\n" if $update_text;
                $update_text .= $c->stash->{update_text};
            }

            # The new category might require extra metadata (e.g. pothole size), so
            # we need to update the problem with the new values.
            my $param_prefix = lc $problem->category;
            $param_prefix =~ s/[^a-z]//g;
            $param_prefix = "category_" . $param_prefix . "_";
            my @contacts = grep { $_->category eq $problem->category } @{$c->stash->{contacts}};
            $c->forward('/report/new/set_report_extras', [ \@contacts, $param_prefix ]);
        }

        # Updating priority/defect type must come after category, in case
        # category has changed (and so might have priorities/defect types)
        if ($permissions->{report_inspect} || $permissions->{report_edit_priority}) {
            if ($c->get_param('priority')) {
                $problem->response_priority( $problem->response_priorities->find({ id => $c->get_param('priority') }) );
            } else {
                $problem->response_priority(undef);
            }
        }

        $c->cobrand->call_hook(report_inspect_update_extra => $problem);

        $c->forward('/photo/process_photo');
        if ( my $photo_error  = delete $c->stash->{photo_error} ) {
            $valid = 0;
            push @{ $c->stash->{errors} }, $photo_error;
        }

        if ($valid) {
            $problem->lastupdate( \'current_timestamp' );
            $problem->update;
            $c->forward( '/admin/log_edit', [ $problem->id, 'problem', 'edit' ] );
            if ($update_text || %update_params) {
                my $timestamp = \'current_timestamp';
                if (my $saved_at = $c->get_param('saved_at')) {
                    # this comes in as a UTC epoch but the database expects everything
                    # to have the FMS timezone so we need to add the timezone otherwise
                    # dates come back out the database at time +/- timezone offset.
                    $timestamp = DateTime->from_epoch(
                        time_zone => FixMyStreet->local_time_zone,
                        epoch => $saved_at
                    );
                }
                $problem->add_to_comments( {
                    text => $update_text,
                    created => $timestamp,
                    confirmed => $timestamp,
                    user => $c->user->obj,
                    photo => $c->stash->{upload_fileid} || undef,
                    problem_state => $problem->state,
                    %update_params,
                } );
            }

            my $redirect_uri;
            $problem->discard_changes;

            # If inspector, redirect back to the map view they came from
            # with the right filters. If that wasn't set, go to /around at this
            # report's location.
            # We go here rather than the shortlist because it makes it much
            # simpler to inspect many reports in the same location. The
            # shortlist is always a single click away, being on the main nav.
            if ($c->user->has_body_permission_to('planned_reports')) {
                unless ($redirect_uri = $c->get_param("post_inspect_url")) {
                    my $categories = $c->user->categories_string;
                    my $params = {
                        lat => $problem->latitude,
                        lon => $problem->longitude,
                    };
                    $params->{filter_category} = $categories if $categories;
                    $params->{js} = 1 if $c->get_param('js');
                    $redirect_uri = $c->uri_for( "/around", $params );
                }
            } elsif ( $c->cobrand->is_council && !$c->cobrand->owns_problem($problem) ) {
                # This problem might no longer be visible on the current cobrand,
                # if its body has changed (e.g. by virtue of the category changing)
                # so redirect to a cobrand where it can be seen if necessary
                $redirect_uri = $c->cobrand->base_url_for_report( $problem ) . $problem->url;
            } else {
                $redirect_uri = $c->uri_for( $problem->url );
            }

            $c->log->debug( "Redirecting to: " . $redirect_uri );
            $c->res->redirect( $redirect_uri );
        }
    }
};

sub map :Chained('id') :Args(0) {
    my ($self, $c) = @_;

    my %params;
    if ( $c->get_param('inline_duplicate') ) {
        $params{full_size} = 1;
        $params{zoom} = 5;
    }

    my $image = $c->stash->{problem}->static_map(%params);
    $c->res->content_type($image->{content_type});
    $c->res->body($image->{data});
}

sub confirmation : Path('confirmation') : Args(1) {
    my ( $self, $c, $id ) = @_;

    # First of all check that the report ID is valid
    my $report = FixMyStreet::DB->resultset('Problem')->find( { id => $id } );
    unless ( $report ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    # Now verify the token we've been given is correct
    my $token_param = $c->get_param('token') || "";
    unless ( $token_param eq $report->confirmation_token ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    # If the token is valid but expired then may as well be helpful and bounce
    # the user to report page rather than 404.
    # (NB the report may still be unconfirmed, but end result is the same - a 404)
    # As each test file runs in a single transaction, it's possible for creation timestamps to be quite old
    my $expiry = FixMyStreet->test_mode ? 30 : 3;
    my $cutoff = DateTime->now()->subtract( minutes => $expiry );
    my $timestamp = $report->confirmed || $report->created;
    if ( $timestamp < $cutoff ) {
        # there's a chance it's not available on this cobrand (e.g. made on Oxon
        # cobrand but sent to district) so get the full URL where we're sure it
        # can be viewed.
        my $base = $c->cobrand->relative_url_for_report( $report );
        return $c->res->redirect($base . $report->url);
    }

    # We're now confident the user is allowed to view this report so stick it on
    # the stash and load up the correct template.
    $c->stash->{problem} = $report;
    if ( $report->confirmed ) {
        $c->stash->{template} = 'tokens/confirm_problem.html';
        $c->stash->{created_report} = "loggedin";
        $c->stash->{report} = $c->stash->{problem};
    } else {
        $c->stash->{non_public} = $report->non_public;
        $c->stash->{template} = 'email_sent.html';
        $c->stash->{email_type} = 'problem';
    }
}


sub nearby_json :PathPart('nearby.json') :Chained('id') :Args(0) {
    my ($self, $c) = @_;

    my $p = $c->stash->{problem};
    $c->forward('_nearby_json', [ {
        latitude => $p->latitude,
        longitude => $p->longitude,
        categories => [ $p->category ],
        ids => [ $p->id ],
    } ]);
}

sub _nearby_json :Private {
    my ($self, $c, $params) = @_;

    if ($params->{fms_no_duplicate}) {
        $c->res->content_type('application/json; charset=utf-8');
        $c->res->body(encode_json({ 'pins' => ''}));
    } else {
        # This is for the list template, this is a list on that page.
        $c->stash->{page} = 'report';

        if (my $dist = $self->_find_distance($c, $params)) { # distance of 0 means we can skip lookup entirely
            $params->{distance} = $dist / 1000 unless $params->{distance}; # DB measures in km

            my $pin_size = $c->get_param('pin_size') || '';
            $pin_size = 'small' unless $pin_size =~ /^(mini|small|normal|big)$/;

            $params->{extra} = $c->cobrand->call_hook('display_location_extra_params');
            $params->{limit} = 5;

            my $nearby = $c->model('DB::Nearby')->nearby($c, %$params);

            # Want to treat these as if they were on map
            $nearby = [ map { $_->problem } @$nearby ];
            my @pins = map {
                my $p = $_->pin_data('around');
                [ $p->{latitude}, $p->{longitude}, $p->{colour},
                $p->{id}, $p->{title}, $pin_size, JSON->false
                ]
            } @$nearby;

            my @extra_pins = $c->cobrand->call_hook('extra_nearby_pins', $params->{latitude}, $params->{longitude}, $dist);
            @pins = (@pins, @extra_pins) if @extra_pins;

            my $list_html = $c->render_fragment(
                'report/nearby.html',
                { reports => $nearby, inline_maps => $c->get_param("inline_maps") ? 1 : 0, extra_pins => \@extra_pins }
            );
            my $json = { pins => \@pins };
            $json->{reports_list} = $list_html if $list_html;
            my $body = encode_json($json);
            $c->res->content_type('application/json; charset=utf-8');
            $c->res->body($body);
        } else {
            $c->res->content_type('application/json; charset=utf-8');
            $c->res->body(encode_json({ 'pins' => []}));
        }
    }
}

# distance in metres
#
# A cobrand may optionally have configured:
# a) distances for an individual (sub)category
# b) distances for a group/parent category
# c) distances by mode
#
# NOTES:
#  - Distances for category or group only apply for the 'suggestions' mode.
#  - Returning a distance of 0 means we can skip the nearby lookup entirely.
sub _find_distance {
    my ($self, $c, $params) = @_;

    my $dist;
    my $mode = $c->get_param('mode');
    my $cobrand_distances = $c->cobrand->nearby_distances;

    if ($mode) {
        if ( $mode eq 'suggestions' && ref $cobrand_distances->{$mode} eq 'HASH' ) {
            my $category = $params->{categories}[0];
            my $group    = $params->{group};

            $dist = $category && defined $cobrand_distances->{$mode}{$category}
            ? $cobrand_distances->{$mode}{$category}
            : $group && defined $cobrand_distances->{$mode}{$group}
            ? $cobrand_distances->{$mode}{$group}
            : $cobrand_distances->{$mode}{_fallback};
        } else {
            $dist = $cobrand_distances->{$mode};
        }
    }

    $dist //= $c->get_param('distance') || '';
    $dist = 1000 unless $dist =~ /^\d+$/;
    $dist = 1000 if $dist > 1000;

    return $dist;
}

=head2 fetch_permissions

Returns a hash of the user's permissions, applied to the problem
in $c->stash->{problem}.

=cut

sub fetch_permissions : Private {
    my ( $self, $c ) = @_;
    return {} unless $c->user_exists;
    return $c->user->permissions($c->stash->{problem});
};

sub stash_category_groups : Private {
    my ( $self, $c, $contacts, $opts ) = @_;

    my %category_groups = ();
    for my $category (@$contacts) {
        my $group = $category->{group} // $category->groups;
        my @groups = @$group;
        if (scalar @groups > 1 && $opts->{combine_multiple}) {
            @groups = sort @groups;
            $category->{group} = \@groups;
            push( @{$category_groups{_('Multiple Groups')}}, $category );
        } else {
            push( @{$category_groups{$_}}, $category ) for @groups;
        }
    }

    # New reporting, top level mixes groups and categories not in a group
    # (or where the category is the only entry in the group)
    if ($opts->{mix_in}) {
        my $no_group = delete $category_groups{""};
        my @list = map { [ $_->category_display, $_ ]  } @$no_group;
        foreach (keys %category_groups) {
            (my $id = $_) =~ s/[^a-zA-Z]+//g;
            if (@{$category_groups{$_}} == 1) {
                my $contact = $category_groups{$_}[0];
                $contact->set_extra_metadata(hoisted => $_);
                push @list, [ $contact->category_display, $contact ];
            } else {
                my $cats = $category_groups{$_};
                @$cats = sort {
                    my $aa = $a->category_display;
                    return 1 if $aa eq _('Other');
                    my $bb = $b->category_display;
                    return -1 if $bb eq _('Other');
                    $aa cmp $bb;
                } @$cats;
                push @list, [ $_, { id => $id, name => $_, categories => $cats } ];
            }
        }
        @list = sort {
            return 1 if $a->[0] eq _('Other');
            return -1 if $b->[0] eq _('Other');
            $a->[0] cmp $b->[0];
        } @list;
        @list = map { $_->[1] } @list;

        $c->cobrand->call_hook(munge_mixed_category_groups => \@list);
        $c->stash->{category_groups} = \@list;
        return;
    }

    # Change empty group to 'No Group' if multiple groups and combining multiple
    if ($opts->{combine_multiple} && scalar keys %category_groups > 1 && $category_groups{""}) {
        $category_groups{_('No Group')} = delete $category_groups{""};
    }

    my @category_groups = ();
    for my $group ( sort keys %category_groups ) {
        next if $group eq _('Other') || $group eq _('Multiple Groups') || $group eq _('No Group');
        push @category_groups, { name => $group, categories => $category_groups{$group} };
    }
    push @category_groups, { name => _('Other'), categories => $category_groups{_('Other')} } if ($category_groups{_('Other')});
    push @category_groups, { name => _('Multiple Groups'), categories => $category_groups{_('Multiple Groups')} } if ($category_groups{_('Multiple Groups')});
    unshift @category_groups, { name => _('No Group'), categories => $category_groups{_('No Group')} } if $category_groups{_('No Group')};

    $c->cobrand->call_hook(munge_unmixed_category_groups => \@category_groups, $opts);

    $c->stash->{category_groups}  = \@category_groups;
}

sub assigned_users_only : Private {
    my ($self, $c, $categories) = @_;

    # Assigned only category checking
    if ($c->user_exists && $c->user->from_body) {
        my @assigned_users_only = grep { $_->get_extra_metadata('assigned_users_only') } @$categories;
        $c->stash->{assigned_users_only} = { map { $_->category => 1 } @assigned_users_only };
        $c->stash->{assigned_categories_only} = $c->user->get_extra_metadata('assigned_categories_only');

        $c->stash->{user_categories} = { map { $_ => 1 } @{$c->user->categories} };
    }
}

__PACKAGE__->meta->make_immutable;

1;
