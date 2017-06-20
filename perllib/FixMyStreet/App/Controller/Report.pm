package FixMyStreet::App::Controller::Report;

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

Redirect to homepage unless C<id> parameter in query, in which case redirect to
'/report/$id'.

=cut

sub index : Path('') : Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->get_param('id');

    my $uri =
        $id
      ? $c->uri_for( '/report', $id )
      : $c->uri_for('/');

    $c->res->redirect($uri);
}

=head2 report_display

Display a report.

=cut

sub display : Path('') : Args(1) {
    my ( $self, $c, $id ) = @_;

    if (
        $id =~ m{ ^ 3D (\d+) $ }x         # Some council with bad email software
        || $id =~ m{ ^(\d+) \D .* $ }x    # trailing garbage
      )
    {
        return $c->res->redirect( $c->uri_for($1), 301 );
    }

    $c->forward( '_display', [ $id ] );
}

=head2 ajax

Return JSON formatted details of a report

=cut

sub ajax : Path('ajax') : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash->{ajax} = 1;
    $c->forward( '_display', [ $id ] );
}

sub _display : Private {
    my ( $self, $c, $id ) = @_;

    $c->forward('/auth/get_csrf_token');
    $c->forward( 'load_problem_or_display_error', [ $id ] );
    $c->forward( 'load_updates' );
    $c->forward( 'format_problem_for_display' );

    my $permissions = $c->stash->{_permissions} = $c->forward( 'check_has_permission_to',
        [ qw/report_inspect report_edit_category report_edit_priority/ ] );
    if (any { $_ } values %$permissions) {
        $c->stash->{template} = 'report/inspect.html';
        $c->forward('inspect');
    }
}

sub support : Path('support') : Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->get_param('id');

    my $uri =
        $id
      ? $c->uri_for( '/report', $id )
      : $c->uri_for('/');

    if ( $id && $c->cobrand->can_support_problems && $c->user && $c->user->from_body ) {
        $c->forward( 'load_problem_or_display_error', [ $id ] );
        $c->stash->{problem}->update( { interest_count => \'interest_count +1' } );
    }
    $c->res->redirect( $uri );
}

sub load_problem_or_display_error : Private {
    my ( $self, $c, $id ) = @_;

    # try to load a report if the id is a number
    my $problem
      = ( !$id || $id =~ m{\D} ) # is id non-numeric?
      ? undef                    # ...don't even search
      : $c->cobrand->problems->find( { id => $id } )
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
    elsif ( $problem->hidden_states->{ $problem->state } or
            (($problem->get_extra_metadata('closure_status')||'') eq 'hidden')) {
        $c->detach(
            '/page_error_410_gone',
            [ _('That report has been removed from FixMyStreet.') ]    #
        );
    } elsif ( $problem->non_public ) {
        if ( !$c->user || $c->user->id != $problem->user->id ) {
            $c->detach(
                '/page_error_403_access_denied',
                [ sprintf(_('That report cannot be viewed on %s.'), $c->stash->{site_name}) ]
            );
        }
    }

    $c->stash->{problem} = $problem;
    if ( $c->user_exists && $c->user->has_permission_to(moderate => $problem->bodies_str_ids) ) {
        $c->stash->{problem_original} = $problem->find_or_new_related(
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

    my $updates = $c->model('DB::Comment')->search(
        { problem_id => $c->stash->{problem}->id, state => 'confirmed' },
        { order_by => [ 'confirmed', 'id' ] }
    );

    my $questionnaires = $c->model('DB::Questionnaire')->search(
        {
            problem_id => $c->stash->{problem}->id,
            whenanswered => { '!=', undef },
            old_state => 'confirmed', new_state => 'confirmed',
        },
        { order_by => 'whenanswered' }
    );

    my @combined;
    while (my $update = $updates->next) {
        push @combined, [ $update->confirmed, $update ];
    }
    while (my $update = $questionnaires->next) {
        push @combined, [ $update->whenanswered, $update ];
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

    ( $c->stash->{latitude}, $c->stash->{longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $problem->latitude, $problem->longitude );

    unless ( $c->get_param('submit_update') ) {
        $c->stash->{add_alert} = 1;
    }

    my $first_body = (values %{$problem->bodies})[0];
    $c->stash->{extra_name_info} = $first_body && $first_body->name =~ /Bromley/ ? 1 : 0;

    $c->forward('generate_map_tags');

    if ( $c->stash->{ajax} ) {
        $c->res->content_type('application/json; charset=utf-8');
        my $content = encode_json(
            {
                report => $c->cobrand->problem_as_hashref( $problem, $c ),
                updates => $c->cobrand->updates_as_hashref( $problem, $c ),
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
        pins      => $problem->used_map
            ? [ $problem->pin_data($c, 'report', type => 'big') ]
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

sub delete :Local :Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->forward('/auth/check_csrf_token');

    $c->forward( 'load_problem_or_display_error', [ $id ] );
    my $p = $c->stash->{problem};

    my $uri = $c->uri_for( '/report', $id );

    return $c->res->redirect($uri) unless $c->user_exists;

    my $body = $c->user->obj->from_body;
    return $c->res->redirect($uri) unless $body;

    return $c->res->redirect($uri) unless $p->bodies->{$body->id};

    $p->state('hidden');
    $p->lastupdate( \'current_timestamp' );
    $p->update;

    $p->user->update_reputation(-1);

    $c->model('DB::AdminLog')->create( {
        user => $c->user->obj,
        admin_user => $c->user->from_body->name,
        object_type => 'problem',
        action => 'state_change',
        object_id => $id,
    } );

    return $c->res->redirect($uri);
}

=head2 action_router

A router for dispatching handlers for sub-actions on a particular report,
e.g. /report/1/inspect

=cut

sub action_router : Path('') : Args(2) {
    my ( $self, $c, $id, $action ) = @_;

    $c->go( 'map', [ $id ] ) if $action eq 'map';
    $c->go( 'nearby_json', [ $id ] ) if $action eq 'nearby.json';

    $c->detach( '/page_error_404_not_found', [] );
}

sub inspect : Private {
    my ( $self, $c ) = @_;
    my $problem = $c->stash->{problem};
    my $permissions = $c->stash->{_permissions};

    $c->forward('/admin/categories_for_point');
    $c->stash->{report_meta} = { map { $_->{name} => $_ } @{ $c->stash->{problem}->get_extra_fields() } };

    if ($c->cobrand->can('council_area_id')) {
        my $priorities_by_category = FixMyStreet::App->model('DB::ResponsePriority')->by_categories($c->cobrand->council_area_id, @{$c->stash->{contacts}});
        $c->stash->{priorities_by_category} = $priorities_by_category;
    }

    if ( $c->get_param('save') ) {
        $c->forward('/auth/check_csrf_token');

        my $valid = 1;
        my $update_text;
        my $reputation_change = 0;
        my %update_params = ();

        if ($permissions->{report_inspect}) {
            foreach (qw/detailed_information traffic_information duplicate_of/) {
                $problem->set_extra_metadata( $_ => $c->get_param($_) );
            }

            if ( $c->get_param('defect_type') ) {
                $problem->defect_type($problem->defect_types->find($c->get_param('defect_type')));
            } else {
                $problem->defect_type(undef);
            }

            if ( $c->get_param('include_update') ) {
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
                $problem->get_photoset->delete_cached;
            }
            if ( $problem->state eq 'duplicate' && $old_state ne 'duplicate' ) {
                # If the report is being closed as duplicate, make sure the
                # update records this.
                $update_params{problem_state} = "duplicate";
            }
            if ( $problem->state ne 'duplicate' ) {
                $problem->unset_extra_metadata('duplicate_of');
            }
            if ( $problem->state ne $old_state ) {
                $c->forward( '/admin/log_edit', [ $problem->id, 'problem', 'state_change' ] );

                # If the state has been changed by an inspector, consider the
                # report to be inspected.
                unless ($problem->get_extra_metadata('inspected')) {
                    $problem->set_extra_metadata( inspected => 1 );
                    $c->forward( '/admin/log_edit', [ $problem->id, 'problem', 'inspected' ] );
                    my $state = $problem->state;
                    $reputation_change = 1 if $c->cobrand->reputation_increment_states->{$state};
                    $reputation_change = -1 if $c->cobrand->reputation_decrement_states->{$state};
                }

                # If an inspector has changed the state, subscribe them to
                # updates
                my $options = {
                    cobrand      => $c->cobrand->moniker,
                    cobrand_data => $problem->cobrand_data,
                    lang         => $problem->lang,
                };
                $problem->user->create_alert($problem->id, $options);
            }
        }

        if ( !$c->forward( '/admin/report_edit_location', [ $problem ] ) ) {
            # New lat/lon isn't valid, show an error
            $valid = 0;
            $c->stash->{errors} ||= [];
            push @{ $c->stash->{errors} }, _('Invalid location. New location must be covered by the same council.');
        }

        if ($permissions->{report_inspect} || $permissions->{report_edit_category}) {
            $c->forward( '/admin/report_edit_category', [ $problem ] );

            # The new category might require extra metadata (e.g. pothole size), so
            # we need to update the problem with the new values.
            my $param_prefix = lc $problem->category;
            $param_prefix =~ s/[^a-z]//g;
            $param_prefix = "category_" . $param_prefix . "_";
            my @contacts = grep { $_->category eq $problem->category } @{$c->stash->{contacts}};
            $c->forward('/report/new/set_report_extras', [ \@contacts, $param_prefix ]);
        }

        # Updating priority must come after category, in case category has changed (and so might have priorities)
        if ($c->get_param('priority') && ($permissions->{report_inspect} || $permissions->{report_edit_priority})) {
            $problem->response_priority( $problem->response_priorities->find({ id => $c->get_param('priority') }) );
        }

        if ($valid) {
            if ( $reputation_change != 0 ) {
                $problem->user->update_reputation($reputation_change);
            }
            $problem->lastupdate( \'current_timestamp' );
            $problem->update;
            if ( defined($update_text) ) {
                my $timestamp = \'current_timestamp';
                if (my $saved_at = $c->get_param('saved_at')) {
                    $timestamp = DateTime->from_epoch( epoch => $saved_at );
                }
                my $name = $c->user->from_body ? $c->user->from_body->name : $c->user->name;
                $problem->add_to_comments( {
                    text => $update_text,
                    created => $timestamp,
                    confirmed => $timestamp,
                    user_id => $c->user->id,
                    name => $name,
                    state => 'confirmed',
                    mark_fixed => 0,
                    anonymous => 0,
                    %update_params,
                } );
            }
            # This problem might no longer be visible on the current cobrand,
            # if its body has changed (e.g. by virtue of the category changing)
            # so redirect to a cobrand where it can be seen if necessary
            my $redirect_uri;
            if ( $c->cobrand->is_council && !$c->cobrand->owns_problem($problem) ) {
                $redirect_uri = $c->cobrand->base_url_for_report( $problem ) . $problem->url;
            } else {
                $redirect_uri = $c->uri_for( $problem->url );
            }

            # Or if inspector, redirect back to shortlist
            if ($c->user->has_body_permission_to('planned_reports')) {
                $redirect_uri = $c->uri_for_action('my/planned');
            }

            $c->log->debug( "Redirecting to: " . $redirect_uri );
            $c->res->redirect( $redirect_uri );
        }
    }
};

sub map : Private {
    my ( $self, $c, $id ) = @_;

    $c->forward( 'load_problem_or_display_error', [ $id ] );

    my $image = $c->stash->{problem}->static_map;
    $c->res->content_type($image->{content_type});
    $c->res->body($image->{data});
}


sub nearby_json : Private {
    my ( $self, $c, $id ) = @_;

    $c->forward( 'load_problem_or_display_error', [ $id ] );
    my $p = $c->stash->{problem};
    my $dist = 1000;

    my $nearby = $c->model('DB::Nearby')->nearby(
        $c, $dist, [ $p->id ], 5, $p->latitude, $p->longitude, undef, [ $p->category ], undef
    );
    my @pins = map {
        my $p = $_->problem;
        my $colour = $c->cobrand->pin_colour( $p, 'around' );
        [ $p->latitude, $p->longitude,
          $colour,
          $p->id, $p->title_safe, 'small', JSON->false
        ]
    } @$nearby;

    my $on_map_list_html = $c->render_fragment(
        'around/on_map_list_items.html',
        { on_map => [], around_map => $nearby }
    );

    my $json = { pins => \@pins };
    $json->{current} = $on_map_list_html if $on_map_list_html;
    my $body = encode_json($json);
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);
}


=head2 check_has_permission_to

Ensure the currently logged-in user has any of the provided permissions applied
to the current Problem in $c->stash->{problem}. Shows the 403 page if not.

=cut

sub check_has_permission_to : Private {
    my ( $self, $c, @permissions ) = @_;
    return {} unless $c->user_exists;
    my $bodies = $c->stash->{problem}->bodies_str_ids;
    my %permissions = map { $_ => $c->user->has_permission_to($_, $bodies) } @permissions;
    return \%permissions;
};

__PACKAGE__->meta->make_immutable;

1;
