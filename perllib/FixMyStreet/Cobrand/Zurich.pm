package FixMyStreet::Cobrand::Zurich;
use base 'FixMyStreet::Cobrand::Default';

use DateTime;
use POSIX qw(strcoll);
use RABX;
use List::Util qw(min);
use Scalar::Util 'blessed';
use DateTime::Format::Pg;
use Try::Tiny;

use strict;
use warnings;
use utf8;

=head1 NAME

Zurich FixMyStreet cobrand

=head1 DESCRIPTION

This module provides the specific functionality for the Zurich FMS cobrand.

=head1 DEVELOPMENT NOTES

The admin for Zurich is different to the other cobrands. To access it you need
to be logged in as a user associated with an appropriate body.

You can create the bodies needed to develop by running the 't/cobrand/zurich.t'
test script with the three C<$mech->delete...> lines at the end commented out.
This should leave you with the bodies and users correctly set up.

The entries will be something like this (but with different ids).

    Bodies:
         id |     name      | parent |         endpoint
        ----+---------------+--------+---------------------------
          1 | Zurich        |        |
          2 | Division 1    |      1 | division@example.org
          3 | Subdivision A |      2 | subdivision@example.org
          4 | External Body |        | external_body@example.org

    Users:
         id |      email       | from_body
        ----+------------------+-----------
          1 | super@example.org|         1
          2 | dm1@example.org  |         2
          3 | sdm1@example.org |         3

The passwords for the users is 'secret'.

Note: the password hashes are salted with the user's id so cannot be easily
changed. High ids have been used so that it should not conflict with anything
you already have, and the countres set so that they shouldn't in future.

=cut

sub setup_states {
    FixMyStreet::DB::Result::Problem->visible_states_remove('not contactable');
}

sub shorten_recency_if_new_greater_than_fixed {
    return 0;
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'submitted' || $p->state eq 'confirmed';
    return 'yellow';
}

# This isn't used
sub find_closest {
    my ( $self, $problem ) = @_;
    return '';
}

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Enter a Z&uuml;rich street name');
}

sub example_places {
    return [ 'Langstrasse', 'Basteiplatz' ];
}

sub languages { [ 'de-ch,Deutsch,de_CH' ] }
sub language_override { 'de-ch' }

sub prettify_dt {
    my $self = shift;
    my $dt = shift;

    return Utils::prettify_dt( $dt, 'zurich' );
}

sub zurich_public_response_states {
    my $states = {
        'fixed - council' => 1,
        'external' => 1,
        'wish' => 1,
    };

    return wantarray ? keys %{ $states } : $states;
}

sub zurich_user_response_states {
    my $states = {
        'jurisdiction unknown' => 1,
        'hidden'          => 1,
        'not contactable' => 1,
    };

    return wantarray ? keys %{ $states } : $states;
}

sub problem_has_public_response {
    my ($self, $problem) = @_;
    return exists $self->zurich_public_response_states->{ $problem->state } ? 1 : 0;
}

sub problem_has_user_response {
    my ($self, $problem) = @_;
    my $state_matches = exists $self->zurich_user_response_states->{ $problem->state } ? 1 : 0;
    return $state_matches && $problem->get_extra_metadata('public_response');
}

sub problem_as_hashref {
    my $self = shift;
    my $problem = shift;
    my $ctx = shift;

    my $hashref = $problem->as_hashref( $ctx );

    if ( $problem->state eq 'submitted' ) {
        for my $var ( qw( photo is_fixed meta ) ) {
            delete $hashref->{ $var };
        }
        $hashref->{detail} = _('This report is awaiting moderation.');
        $hashref->{title} = _('This report is awaiting moderation.');
        $hashref->{banner_id} = 'closed';
    } else {
        if ( $problem->state eq 'confirmed' || $problem->state eq 'external' ) {
            $hashref->{banner_id} = 'closed';
        } elsif ( $problem->is_fixed || $problem->is_closed ) {
            $hashref->{banner_id} = 'fixed';
        } else {
            $hashref->{banner_id} = 'progress';
        }

        if ( $problem->state eq 'confirmed' ) {
            $hashref->{state} = 'open';
            $hashref->{state_t} = _('Open');
        } elsif ( $problem->state eq 'wish' ) {
            $hashref->{state_t} = _('Closed');
        } elsif ( $problem->is_fixed ) {
            $hashref->{state} = 'closed';
            $hashref->{state_t} = _('Closed');
        } elsif ( $problem->state eq 'feedback pending' ) {
            $hashref->{state} = 'in progress';
            $hashref->{state_t} = FixMyStreet::DB->resultset("State")->display('in progress');
        }
    }

    return $hashref;
}

sub updates_as_hashref {
    my $self = shift;
    my $problem = shift;
    my $ctx = shift;

    my $hashref = {};

    if ($self->problem_has_public_response($problem)) {
        $hashref->{update_pp} = $self->prettify_dt( $problem->lastupdate );

        if ( $problem->state ne 'external' ) {
            $hashref->{details} = FixMyStreet::App::View::Web::add_links(
                $problem->get_extra_metadata('public_response') || '' );
        } else {
            $hashref->{details} = sprintf( _('Assigned to %s'), $problem->body($ctx)->name );
        }
    }

    return $hashref;
}

# If $num is undefined, we want to return the minimum photo number that can be
# shown (1-indexed), or false for no display. If $num is defined, return
# boolean whether that indexed photo can be shown.
sub allow_photo_display {
    my ( $self, $r, $num ) = @_;
    return unless $r;
    my $publish_photo;
    if (blessed $r) {
        $publish_photo = $r->get_extra_metadata('publish_photo');
    } else {
        # additional munging in case $r isn't an object, TODO see if we can remove this
        my $extra = $r->{extra};
        utf8::encode($extra) if utf8::is_utf8($extra);
        my $h = new IO::String($extra);
        $extra = RABX::wire_rd($h);
        return unless ref $extra eq 'HASH';
        $publish_photo = $extra->{publish_photo};
    }
    # Old style stored 1/0 integer, which can still be used if present.
    return $publish_photo unless ref $publish_photo;
    return $publish_photo->{$num} if defined $num;

    # We return a 1-indexed number so that '0' can be taken as 'not allowed'
    my $i = min grep { $publish_photo->{$_} } keys %$publish_photo;
    return $i + 1;
}

sub get_body_sender {
    my ( $self, $body, $category ) = @_;
    return { method => 'Zurich' };
}

# Report overdue functions

my %public_holidays = map { $_ => 1 } (
    # New Year's Day, Saint Berchtold, Good Friday, Easter Monday,
    # Sechseläuten, Labour Day, Ascension Day, Whit Monday,
    # Swiss National Holiday, Knabenschiessen, Christmas, St Stephen's Day
    # Extra holidays

    '2018-01-01', '2018-01-02', '2018-03-30', '2018-04-02',
    '2018-04-16', '2018-05-01', '2018-05-10', '2018-05-21',
    '2018-08-01', '2018-09-10', '2018-12-25', '2018-12-26',
    '2018-03-29', '2018-05-11', '2018-12-27', '2018-12-28', '2018-12-31',

    '2019-01-01', '2019-01-02', '2019-04-19', '2019-04-22',
    '2019-04-08', '2019-05-01', '2019-05-30', '2019-06-10',
    '2019-08-01', '2019-09-09', '2019-12-25', '2019-12-26',
    '2019-04-18', '2019-05-29', '2019-05-31', '2019-12-24', '2019-12-27', '2019-12-30', '2019-12-31',

    '2020-01-01', '2020-01-02', '2020-04-10', '2020-04-13',
    '2020-04-20', '2020-05-01', '2020-05-21', '2020-06-01',
    '2020-09-14', '2020-12-25',
    '2020-05-20', '2020-05-22', '2020-12-24', '2020-12-28', '2020-12-29', '2020-12-30', '2020-12-31',

    '2021-01-01', '2021-04-02', '2021-04-05',
    '2021-04-19', '2021-05-13', '2021-05-24',
    '2021-09-13',
);

sub is_public_holiday {
    my $dt = shift;
    return $public_holidays{$dt->ymd};
}

sub is_weekend {
    my $dt = shift;
    return $dt->dow > 5;
}

sub add_days {
    my ( $dt, $days ) = @_;
    $dt = $dt->clone;
    while ( $days > 0 ) {
        $dt->add ( days => 1 );
        next if is_public_holiday($dt) or is_weekend($dt);
        $days--;
    }
    return $dt;
}

sub sub_days {
    my ( $dt, $days ) = @_;
    $dt = $dt->clone;
    while ( $days > 0 ) {
        $dt->subtract ( days => 1 );
        next if is_public_holiday($dt) or is_weekend($dt);
        $days--;
    }
    return $dt;
}

sub overdue {
    my ( $self, $problem ) = @_;

    my $w = $problem->created;
    return 0 unless $w;

    # call with previous state
    if ( $problem->state eq 'submitted' ) {
        # One working day
        $w = add_days( $w, 1 );
        return $w < DateTime->now() ? 1 : 0;
    } elsif ( $problem->state eq 'confirmed' || $problem->state eq 'in progress' || $problem->state eq 'feedback pending' ) {
        # States which affect the subdiv_overdue statistic.  TODO: this may no longer be required
        # Six working days from creation
        $w = add_days( $w, 6 );
        return $w < DateTime->now() ? 1 : 0;

    # call with new state
    } else {
        # States which affect the closed_overdue statistic
        # Five working days from moderation (so 6 from creation)

        $w = add_days( $w, 6 );
        return $w < DateTime->now() ? 1 : 0;
    }
}

sub get_or_check_overdue {
    my ($self, $problem) = @_;

    # use the cached version is it exists (e.g. when called from template)
    my $overdue = $problem->get_extra_metadata('closed_overdue');
    return $overdue if defined $overdue;

    return $self->overdue($problem);
}

sub report_page_data {
    my $self = shift;
    my $c = $self->{c};

    $c->stash->{page} = 'reports';
    $c->forward( 'stash_report_filter_status' );
    $c->forward( 'load_and_group_problems' );
    $c->stash->{body} = { id => 0 }; # So template can fetch the list

    if ($c->get_param('ajax')) {
        $c->detach('ajax', [ 'reports/_problem-list.html' ]);
    }

    my $pins = $c->stash->{pins};
    FixMyStreet::Map::display_map(
        $c,
        latitude  => @$pins ? $pins->[0]{latitude} : 0,
        longitude => @$pins ? $pins->[0]{longitude} : 0,
        area      => 274456,
        pins      => $pins,
        any_zoom  => 1,
    );
    return 1;
}

=head1 C<set_problem_state>

If the state has changed, sets the state and calls C::Admin's C<log_edit> action.
If the state hasn't changed, defers to update_admin_log (to update time_spent if any).

Returns either undef or the AdminLog entry created.

=cut

sub set_problem_state {
    my ($self, $c, $problem, $new_state) = @_;
    return $self->update_admin_log($c, $problem) if $new_state eq $problem->state;
    $problem->state( $new_state );
    $c->forward( 'log_edit', [ $problem->id, 'problem', "state change to $new_state" ] );
}

=head1 C<update_admin_log>

Calls C::Admin's C<log_edit> if either a) text is provided, or b) there has
been time_spent on the task.  As set_problem_state will already call log_edit
if required, don't call this as well.

Returns either undef or the AdminLog entry created.

=cut

sub update_admin_log {
    my ($self, $c, $problem, $text) = @_;

    my $time_spent = ( ($c->get_param('time_spent') // 0) + 0 );
    $c->set_param('time_spent' => 0); # explicitly zero this to avoid duplicates

    if (!$text) {
        return unless $time_spent;
        $text = "Logging time_spent";
    }

    $c->forward( 'log_edit', [ $problem->id, 'problem', $text, $time_spent ] );
}

# Any user with from_body set can view admin
sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->from_body;
}

# Specific administrative displays

sub admin_pages {
    my $self = shift;
    my $c = $self->{c};

    my $type = $c->stash->{admin_type};

    my $pages = {
        'summary' => [_('Summary'), 0],
        'reports' => [_('Reports'), 2],
        'report_edit' => [undef, undef],
        'update_edit' => [undef, undef],
        'stats' => [_('Stats'), 4],
    };
    return $pages if $type eq 'sdm';

    $pages = { %$pages,
        'bodies' => [_('Bodies'), 1],
        'body' => [undef, undef],
        'templates' => [_('Templates'), 2],
    };
    return $pages if $type eq 'dm';

    $pages = { %$pages,
        'users' => [_('Users'), 3],
        'user_edit' => [undef, undef],
    };

    # There are some pages that only super users can see
    if ($self->{c}->user->is_superuser) {
        $pages->{states} = [ _('States'), 8 ];
        $pages->{config} = [ _('Configuration'), 9];
    };

    return $pages if $type eq 'super';
}

sub admin_type {
    my $self = shift;
    my $c = $self->{c};
    my $body = $c->user->from_body;
    $c->stash->{body} = $body;

    my $type;
    my $parent = $body->parent;
    if (!$parent) {
        $type = 'super';
    } else {
        my $grandparent = $parent->parent;
        $type = $grandparent ? 'sdm' : 'dm';
    }

    $c->stash->{admin_type} = $type;
    return $type;
}

sub admin {
    my $self = shift;
    my $c = $self->{c};
    my $type = $c->stash->{admin_type};

    if ($type eq 'dm') {
        $c->stash->{template} = 'admin/index-dm.html';

        my $body = $c->stash->{body};
        my @children = map { $_->id } $body->bodies->all;
        my @all = (@children, $body->id);

        my $order = $c->get_param('o') || 'created';
        my $dir = defined $c->get_param('d') ? $c->get_param('d') : 1;
        $c->stash->{order} = $order;
        $c->stash->{dir} = $dir;
        $order .= ' desc' if $dir;

        # XXX No multiples or missing bodies
        $c->stash->{submitted} = $c->cobrand->problems->search({
            state => [ 'submitted', 'confirmed' ],
            bodies_str => $c->stash->{body}->id,
        }, {
            order_by => $order,
        });
        $c->stash->{approval} = $c->cobrand->problems->search({
            state => 'feedback pending',
            bodies_str => $c->stash->{body}->id,
        }, {
            order_by => $order,
        });

        my $page = $c->get_param('p') || 1;
        $c->stash->{other} = $c->cobrand->problems->search({
            state => { -not_in => [ 'submitted', 'confirmed', 'feedback pending' ] },
            bodies_str => \@all,
        }, {
            order_by => $order,
        })->page( $page );
        $c->stash->{pager} = $c->stash->{other}->pager;

    } elsif ($type eq 'sdm') {
        $c->stash->{template} = 'admin/index-sdm.html';

        my $body = $c->stash->{body};

        my $order = $c->get_param('o') || 'created';
        my $dir = defined $c->get_param('d') ? $c->get_param('d') : 1;
        $c->stash->{order} = $order;
        $c->stash->{dir} = $dir;
        $order .= ' desc' if $dir;

        # XXX No multiples or missing bodies
        $c->stash->{reports_new} = $c->cobrand->problems->search( {
            state => 'in progress',
            bodies_str => $body->id,
        }, {
            order_by => $order
        } );
        $c->stash->{reports_unpublished} = $c->cobrand->problems->search( {
            state => 'feedback pending',
            bodies_str => $body->parent->id,
        }, {
            order_by => $order
        } );

        my $page = $c->get_param('p') || 1;
        $c->stash->{reports_published} = $c->cobrand->problems->search( {
            state => 'fixed - council',
            bodies_str => $body->parent->id,
        }, {
            order_by => $order
        } )->page( $page );
        $c->stash->{pager} = $c->stash->{reports_published}->pager;
    }
}

sub category_options {
    my ($self, $c) = @_;
    my @categories = $c->model('DB::Contact')->not_deleted->all;
    $c->stash->{category_options} = [ map { {
        category => $_->category, category_display => $_->category,
        abbreviation => $_->get_extra_metadata('abbreviation'),
    } } @categories ];
}

sub admin_report_edit {
    my $self = shift;
    my $c = $self->{c};
    my $type = $c->stash->{admin_type};

    my $problem = $c->stash->{problem};
    my $body = $c->stash->{body};

    if ($type ne 'super') {
        my %allowed_bodies = map { $_->id => 1 } ( $body->bodies->all, $body );
        # SDMs can see parent reports but not edit them
        $allowed_bodies{$body->parent->id} = 1 if $type eq 'sdm';
        $c->detach( '/page_error_404_not_found' )
          unless $allowed_bodies{$problem->bodies_str};
    }

    if ($type eq 'super') {

        my @bodies = $c->model('DB::Body')->all();
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;

        # Can change category to any other
        $self->category_options($c);

    } elsif ($type eq 'dm') {

        # Can assign to:
        my @bodies = $c->model('DB::Body')->search( [
            { 'me.parent' => $body->parent->id }, # Other DMs on the same level
            { 'me.parent' => $body->id }, # Their subdivisions
            { 'me.parent' => undef, 'bodies.id' => undef }, # External bodies
        ], { join => 'bodies', distinct => 1 } );
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;

        # Can change category to any other
        $self->category_options($c);

    }

    # If super or dm check that the token is correct before proceeding
    if ( ($type eq 'super' || $type eq 'dm') && $c->get_param('submit') ) {
        $c->forward('/auth/check_csrf_token');
    }

    # All types of users can add internal notes
    if ( ($type eq 'super' || $type eq 'dm' || $type eq 'sdm') && $c->get_param('submit') ) {
        # If there is a new note add it as a comment to the problem (with is_internal_note set true in extra).
        if ( my $new_internal_note = $c->get_param('new_internal_note') ) {
            $problem->add_to_comments( {
                text => $new_internal_note,
                user => $c->user->obj,
                state => 'hidden', # seems best fit, should not be shown publicly
                mark_fixed => 0,
                anonymous => 1,
                extra => { is_internal_note => 1 },
            } );
        }
    }


    # Problem updates upon submission
    if ( ($type eq 'super' || $type eq 'dm') && $c->get_param('submit') ) {

        my @keys = grep { /^publish_photo/ } keys %{ $c->req->params };
        my %publish_photo;
        foreach my $key (@keys) {
            my ($index) = $key =~ /(\d+)$/;
            $publish_photo{$index} = 1 if $c->get_param($key);
        }

        if (%publish_photo) {
            $problem->set_extra_metadata('publish_photo' => \%publish_photo);
        } else {
            $problem->unset_extra_metadata('publish_photo');
        }
        $problem->set_extra_metadata('third_personal' => $c->get_param('third_personal') || 0 );

        # Make sure we have a copy of the original detail field
        if (my $new_detail = $c->get_param('detail')) {
            my $old_detail = $problem->detail;
            if (! $problem->get_extra_metadata('original_detail')
                && ($old_detail ne $new_detail))
            {
                $problem->set_extra_metadata( original_detail => $old_detail );
            }
        }

        # Some changes will be accompanied by an internal note, which if needed
        # should be stored in this variable.
        my $internal_note_text = "";

        # Workflow things
        #
        #   Note that 2 types of email may be sent
        #    1) _admin_send_email()  sends an email to the *user*, if their email is confirmed
        #
        #    2) setting $problem->whensent(undef) may make it eligible for generating an email
        #   to the body (internal or external).  See DBRS::Problem->send_reports for Zurich-
        #   specific categories which are eligible for this.

        my $redirect = 0;
        my $new_cat = $c->get_param('category') || '';
        my $state = $c->get_param('state') || '';
        my $oldstate = $problem->state;

        my $closure_states = { map { $_ => 1 } FixMyStreet::DB::Result::Problem->closed_states(), FixMyStreet::DB::Result::Problem->hidden_states() };

        my $old_closure_state = $problem->get_extra_metadata('closure_status') || '';

        # update the public update from DM
        if (my $update = $c->get_param('status_update')) {
            $problem->set_extra_metadata(public_response => $update);
        }

        if (
            ($state eq 'confirmed') 
            && $new_cat
            && $new_cat ne $problem->category
        ) {
            my $cat = $c->model('DB::Contact')->not_deleted->search({ category => $c->get_param('category') } )->first;
            my $old_cat = $problem->category;
            $problem->category( $new_cat );
            $problem->external_body( undef );
            $problem->bodies_str( $cat->body_id );
            $problem->whensent( undef );
            $problem->set_extra_metadata(changed_category => 1);
            $internal_note_text = "Weitergeleitet von $old_cat an $new_cat";
            $self->update_admin_log($c, $problem, "Changed category from $old_cat to $new_cat");
            $redirect = 1 if $cat->body_id ne $body->id;
        } elsif ( $oldstate ne $state and $closure_states->{$state} and
                  $oldstate ne 'feedback pending' || $old_closure_state ne $state)
        {
            # for these states
            #  - external
            #  - wish
            #  - hidden
            #  - not contactable
            #  - jurisdiction unknown
            # we divert to feedback pending (Rueckmeldung ausstehend) and set closure_status to the requested state
            # From here, the DM can reply to the user, triggering the setting of problem to correct state
            $problem->set_extra_metadata( closure_status => $state );
            $self->set_problem_state($c, $problem, 'feedback pending');
            $state = 'feedback pending';
            $problem->set_extra_metadata_if_undefined( moderated_overdue => $self->overdue( $problem ) );

        } elsif ( my $subdiv = $c->get_param('body_subdivision') ) {
            $problem->set_extra_metadata_if_undefined( moderated_overdue => $self->overdue( $problem ) );
            $self->set_problem_state($c, $problem, 'in progress');
            $problem->external_body( undef );
            $problem->bodies_str( $subdiv );
            $problem->whensent( undef );
            $redirect = 1;
        } else {
            if ($state) {

                if ($oldstate eq 'submitted' and $state ne 'submitted') {
                    # only set this for the first state change
                    $problem->set_extra_metadata_if_undefined( moderated_overdue => $self->overdue( $problem ) );
                }

                $self->set_problem_state($c, $problem, $state)
                    unless $closure_states->{$state};
                    # we'll defer to 'feedback pending' clause below to change the state
            }
        }

        if ($problem->state eq 'feedback pending') {
            # Rueckmeldung ausstehend
            # override $state from the metadata set above
            $state = $problem->get_extra_metadata('closure_status') || '';
            my ($moderated, $closed) = (0, 0);

            if ($state eq 'hidden' && $c->get_param('publish_response') ) {
                _admin_send_email( $c, 'problem-rejected.txt', $problem );

                $self->set_problem_state($c, $problem, $state);
                $moderated++;
                $closed++;
            }
            elsif ($state =~/^(external|wish)$/) {
                $moderated++;
                # Nested if instead of `and` because in these cases, we *don't*
                # want to close unless we have body_external (so we don't want
                # the final elsif clause below to kick in on publish_response)
                if (my $external = $c->get_param('body_external')) {
                    my $external_body = $c->model('DB::Body')->find($external)
                        or die "Body $external not found";
                    $problem->external_body( $external );
                }
                if ($problem->external_body && $c->get_param('publish_response')) {
                    $problem->whensent( undef );
                    $self->set_problem_state($c, $problem, $state);
                    my $template = ($state eq 'wish') ? 'problem-wish.txt' : 'problem-external.txt';
                    _admin_send_email( $c, $template, $problem );
                    $redirect = 0;
                    $closed++;
                }
                # set the external_message in extra, so that it can be edited again
                if ( my $external_message = $c->get_param('external_message') ) {
                    $problem->set_extra_metadata( external_message => $external_message );
                }
                # else should really return a message here
            }
            elsif ($c->get_param('publish_response')) {
                # otherwise we only set the state if publish_response is set
                #

                # if $state wasn't set, then we are simply closing the message as fixed
                $state ||= 'fixed - council';
                _admin_send_email( $c, 'problem-closed.txt', $problem );
                $redirect = 0;
                $moderated++;
                $closed++;
            }

            if ($moderated) {
                $problem->set_extra_metadata_if_undefined( moderated_overdue => $self->overdue( $problem ) );
            }

            if ($closed) {
                # set to either the closure_status from metadata or 'fixed - council' as above
                $self->set_problem_state($c, $problem, $state);
                $problem->set_extra_metadata_if_undefined( closed_overdue => $self->overdue( $problem ) );
                $problem->unset_extra_metadata('closure_status');
            }
        }
        else {
            $problem->unset_extra_metadata('closure_status');
        }

        $problem->title( $c->get_param('title') ) if $c->get_param('title');
        $problem->detail( $c->get_param('detail') ) if $c->get_param('detail');
        $problem->latitude( $c->get_param('latitude') );
        $problem->longitude( $c->get_param('longitude') );

        # send external_message if provided and state is *now* Wish|Extern
        # e.g. was already, or was set in the Rueckmeldung ausstehend clause above.
        if ( my $external_message = $c->get_param('external_message')
             and $problem->state =~ /^(external|wish)$/)
        {
            my $external = $problem->external_body;
            my $external_body = $c->model('DB::Body')->find($external)
                or die "Body $external not found";

            $problem->set_extra_metadata_if_undefined( moderated_overdue => $self->overdue( $problem ) );
            # Create a Comment on this Problem with the content of the external message.
            # NB this isn't directly shown anywhere, but is for logging purposes.
            $problem->add_to_comments( {
                text => (
                    sprintf '(%s %s) %s',
                    $state eq 'external' ?
                        _('Forwarded to external body') :
                        _('Forwarded wish to external body'),
                    $external_body->name,
                    $external_message,
                ),
                user => $c->user->obj,
                state => 'hidden', # seems best fit, should not be shown publicly
                mark_fixed => 0,
                anonymous => 1,
                extra => { is_internal_note => 1, is_external_message => 1 },
            } );
            # set the external_message in extra, so that it will be picked up
            # later by send-reports
            $problem->set_extra_metadata( external_message => $external_message );
        }

        $problem->lastupdate( \'current_timestamp' );
        $problem->update;

        $c->stash->{status_message} = '<p class="message-updated">' . _('Updated!') . '</p>';

        # do this here otherwise lastupdate and confirmed times
        # do not display correctly (reloads problem from database, including
        # fields modified by the database when saving)
        $problem->discard_changes;

        # Create an internal note if required
        if ($internal_note_text) {
            $problem->add_to_comments( {
                text => $internal_note_text,
                user => $c->user->obj,
                state => 'hidden', # seems best fit, should not be shown publicly
                mark_fixed => 0,
                anonymous => 1,
                extra => { is_internal_note => 1 },
            } );
        }

        # Just update if time_spent still hasn't been logged
        # (this will only happen if no other update_admin_log has already been called)
        $self->update_admin_log($c, $problem);

        if ( $redirect and $type eq 'dm' ) {
            # only redirect for DM
            $c->stash->{status_message} ||= '<p class="message-updated">' . _('Updated!') . '</p>';
            $c->go('index');
        }

        $c->stash->{updates} = [ $c->model('DB::Comment')
          ->search( { problem_id => $problem->id }, { order_by => 'created' } )
          ->all ];

        $self->stash_states($problem);
        return 1;
    }

    if ($type eq 'sdm') {

        my $editable = $type eq 'sdm' && $body->id eq $problem->bodies_str;
        $c->stash->{sdm_disabled} = $editable ? '' : 'disabled';

        # Has cut-down edit template for adding update and sending back up only
        $c->stash->{template} = 'admin/report_edit-sdm.html';

        if ($editable && $c->get_param('send_back') or $c->get_param('not_contactable')) {
            # SDM can send back a report either to be assigned to a different
            # subdivision, or because the customer was not contactable.
            # We handle these in the same way but with different statuses.

            $c->forward('/auth/check_csrf_token');

            my $not_contactable = $c->get_param('not_contactable');

            $problem->bodies_str( $body->parent->id );
            if ($not_contactable) {
                # we can't directly set state, but mark the closure_status for DM to confirm.
                $self->set_problem_state($c, $problem, 'feedback pending');
                $problem->set_extra_metadata( closure_status => 'not contactable');
            }
            else {
                $self->set_problem_state($c, $problem, 'confirmed');
            }
            $problem->update;
            $c->forward( 'log_edit', [ $problem->id, 'problem', 
                $not_contactable ?
                    _('Customer not contactable')
                    : _('Sent report back') ] );
            # Make sure the problem's time_spent is updated
            $self->update_admin_log($c, $problem);
            $c->res->redirect( '/admin/summary' );
        } elsif ($editable && $c->get_param('submit')) {
            $c->forward('/auth/check_csrf_token');

            my $db_update = 0;
            if ( $c->get_param('latitude') != $problem->latitude || $c->get_param('longitude') != $problem->longitude ) {
                $problem->latitude( $c->get_param('latitude') );
                $problem->longitude( $c->get_param('longitude') );
                $db_update = 1;
            }

            $problem->update if $db_update;

            # Add new update from status_update
            if (my $update = $c->get_param('status_update')) {
                $c->model('DB::Comment')->create( {
                    text => $update,
                    user => $c->user->obj,
                    state => 'unconfirmed',
                    problem => $problem,
                    mark_fixed => 0,
                    problem_state => 'fixed - council',
                    anonymous => 1,
                } );
            }
            # Make sure the problem's time_spent is updated
            $self->update_admin_log($c, $problem);

            $c->stash->{status_message} = '<p class="message-updated">' . _('Updated!') . '</p>';

            # If they clicked the no more updates button, we're done.
            if ($c->get_param('no_more_updates')) {
                $problem->set_extra_metadata( subdiv_overdue => $self->overdue( $problem ) );
                $problem->bodies_str( $body->parent->id );
                $problem->whensent( undef );
                $self->set_problem_state($c, $problem, 'feedback pending');
                $problem->update;
                $c->res->redirect( '/admin/summary' );
            }
        }

        $c->stash->{updates} = [ $c->model('DB::Comment')
            ->search( { problem_id => $problem->id }, { order_by => 'created' } )
            ->all ];

        $self->stash_states($problem);
        return 1;

    }

    $self->stash_states($problem);
    return 0;

}

sub stash_states {
    my ($self, $problem) = @_;
    my $c = $self->{c};

    # current problem state affects which states are visible in dropdowns
    my @states = (
        {
            # Erfasst
            state => 'submitted',
            submitted => 1,
            hidden => 1,
        },
        {
            # Aufgenommen
            state => 'confirmed',
            submitted => 1,
        },
        {
            # Unsichtbar (hidden)
            state => 'hidden',
            submitted => 1,
            hidden => 1,
        },
        {
            # Extern
            state => 'external',
        },
        {
            # Zustaendigkeit unbekannt
            state => 'jurisdiction unknown',
        },
        {
            # Wunsch
            state => 'wish',
        },
        {
            # Nicht kontaktierbar (hidden)
            state => 'not contactable',
        },
    );

    my $state = $problem->state;

    # Rueckmeldung ausstehend may also indicate the status it's working towards.
    push @states, do {
        if ($state eq 'feedback pending' and my $closure_status = $problem->get_extra_metadata('closure_status')) {
            {
                state => $closure_status,
                trans => sprintf 'Rückmeldung ausstehend (%s)', FixMyStreet::DB->resultset("State")->display($closure_status),
            };
        }
        else {
            {
                state => 'feedback pending',
            };
        }
    };

    if ($state eq 'in progress') {
        push @states, {
            state => 'in progress',
        };
    }
    elsif ($state eq 'fixed - council') {
        push @states, {
            state => 'fixed - council',
        };
    }
    elsif ($state =~/^(hidden|submitted)$/) {
        @states = grep { $_->{$state} } @states;
    }
    $c->stash->{states} = \@states;

    # stash details about the public response
    $c->stash->{default_public_response} = "\nFreundliche Grüsse\n\nIhre Stadt Zürich\n";
    $c->stash->{show_publish_response} = 
        ($problem->state eq 'feedback pending');
}

=head2 _admin_send_email

Send an email to the B<user> who logged the problem, if their email address is confirmed.

=cut

sub _admin_send_email {
    my ( $c, $template, $problem ) = @_;

    return unless $problem->get_extra_metadata('email_confirmed');

    my $to = $problem->name
        ? [ $problem->user->email, $problem->name ]
        : $problem->user->email;

    my $sender = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    my $sender_name = $c->cobrand->contact_name;

    $c->send_email( $template, {
        to => [ $to ],
        url => $c->uri_for_email( $problem->url ),
        from => [ $sender, $sender_name ],
        problem => $problem,
    } );
}

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    if ($row->state =~ /^(external|wish)$/) {
        # we attach images to reports sent to external bodies
        my $photoset = $row->get_photoset();
        my $num = $photoset->num_images
            or return;
        my $id = $row->id;
        my @attachments = map {
            if ($self->allow_photo_display($row, $_)) {
                my $image = $photoset->get_raw_image($_);
                {
                    body => $image->{data},
                    attributes => {
                        filename => "$id.$_." . $image->{extension},
                        content_type => $image->{content_type},
                        encoding => 'base64',
                            # quoted-printable ends up with newlines corrupting binary data
                        name => "$id.$_." . $image->{extension},
                    },
                };
            } else {
                ();
            }
        } (0..$num-1);
        $params->{_attachments_} = \@attachments;
    }
}

sub admin_fetch_all_bodies {
    my ( $self ) = @_;

    sub tree_sort {
        my ( $level, $id, $sorted, $out ) = @_;

        my @sorted;
        my $array = $sorted->{$id};
        if ( $level == 0 ) {
            @sorted = sort {
                # Want Zurich itself at the top.
                return -1 if $sorted->{$a->{id}};
                return 1 if $sorted->{$b->{id}};
                # Otherwise, by name
                strcoll($a->{name}, $b->{name})
            } @$array;
        } else {
            @sorted = sort { strcoll($a->{name}, $b->{name}) } @$array;
        }
        foreach ( @sorted ) {
            $_->{indent_level} = $level;
            push @$out, $_;
            if ($sorted->{$_->{id}}) {
                tree_sort( $level+1, $_->{id}, $sorted, $out );
            }
        }
    }

    my @bodies = FixMyStreet::DB->resultset('Body')->search(undef, {
        columns => [ "id", "name", "deleted", "parent", "endpoint" ],
    })->translated->with_children_count->all_sorted;

    my %sorted;
    foreach (@bodies) {
        my $p = $_->{parent} ? $_->{parent}{id} : 0;
        push @{$sorted{$p}}, $_;
    }

    my @out;
    tree_sort( 0, 0, \%sorted, \@out );
    return @out;
}

sub admin_stats {
    my $self = shift;
    my $c = $self->{c};

    my %optional_params;
    my $ym = $c->get_param('ym');
    my ($m, $y) = $ym ? ($ym =~ /^(\d+)\.(\d+)$/) : ();
    $c->stash->{ym} = $ym;
    if ($y && $m) {
        $c->stash->{start_date} = DateTime->new( year => $y, month => $m, day => 1 );
        $c->stash->{end_date} = $c->stash->{start_date} + DateTime::Duration->new( months => 1 );
        $optional_params{created} = {
            '>=', DateTime::Format::Pg->format_datetime($c->stash->{start_date}), 
            '<',  DateTime::Format::Pg->format_datetime($c->stash->{end_date}),
        };
    }

    my $cat = $c->stash->{category} = $c->get_param('category');
    $optional_params{category} = $cat if $cat;

    my %params = (
        %optional_params,
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
    );

    if ( $c->get_param('export') ) {
        return $self->export_as_csv($c, \%optional_params);
    }

    # Can change category to any other
    $self->category_options($c);

    # Total reports (non-hidden)
    my $total = $c->model('DB::Problem')->search( \%params )->count;
    # Device for apps (iOS/Android)
    my $per_service = $c->model('DB::Problem')->search( \%params, {
        select   => [ 'service', { count => 'id' } ],
        as       => [ 'service', 'c' ],
        group_by => [ 'service' ],
    });
    # Reports solved
    my $solved = $c->model('DB::Problem')->search( { state => 'fixed - council', %optional_params } )->count;
    # Reports marked as spam
    my $hidden = $c->model('DB::Problem')->search( { state => 'hidden', %optional_params } )->count;
    # Reports assigned to third party
    my $external = $c->model('DB::Problem')->search( { state => 'external', %optional_params } )->count;
    # Reports moderated within 1 day
    my $moderated = $c->model('DB::Problem')->search( { extra => { like => '%moderated_overdue,I1:0%' }, %optional_params } )->count;
    # Reports solved within 5 days (sent back from subdiv)
    my $subdiv_dealtwith = $c->model('DB::Problem')->search( { extra => { like => '%subdiv_overdue,I1:0%' }, %params } )->count;
    # Reports solved within 5 days (marked as 'fixed - council', 'external', or 'hidden'
    my $fixed_in_time = $c->model('DB::Problem')->search( { extra => { like => '%closed_overdue,I1:0%' }, %optional_params } )->count;
    # Reports per category
    my $per_category = $c->model('DB::Problem')->search( \%params, {
        select   => [ 'category', { count => 'id' } ],
        as       => [ 'category', 'c' ],
        group_by => [ 'category' ],
    });
    # How many reports have had their category changed by a DM (wrong category chosen by user)
    my $changed = $c->model('DB::Problem')->search( { extra => { like => '%changed_category,I1:1%' }, %params } )->count;
    # pictures taken
    my $pictures_taken = $c->model('DB::Problem')->search( { photo => { '!=', undef }, %params } )->count;
    # pictures published
    my $pictures_published = $c->model('DB::Problem')->search( { extra => { like => '%publish_photo%' }, %params } )->count;
    # how many times was a telephone number provided
    # XXX => How many users have a telephone number stored
    # my $phone = $c->model('DB::User')->search( { phone => { '!=', undef } } )->count;
    # how many times was the email address confirmed
    my $email_confirmed = $c->model('DB::Problem')->search( { extra => { like => '%email_confirmed%' }, %params } )->count;
    # how many times was the name provided
    my $name = $c->model('DB::Problem')->search( { name => { '!=', '' }, %params } )->count;
    # how many times was the geolocation used vs. addresssearch
    # ?

    $c->stash(
        per_service => $per_service,
        per_category => $per_category,
        reports_total => $total,
        reports_solved => $solved,
        reports_spam => $hidden,
        reports_assigned => $external,
        reports_moderated => $moderated,
        reports_dealtwith => $fixed_in_time,
        reports_category_changed => $changed,
        pictures_taken => $pictures_taken,
        pictures_published => $pictures_published,
        #users_phone => $phone,
        email_confirmed => $email_confirmed,
        name_provided => $name,
        # GEO
    );

    return 1;
}

sub export_as_csv {
    my ($self, $c, $params) = @_;
    try {
        $c->model('DB')->schema->storage->sql_maker->quote_char('"');
        my $csv = $c->stash->{csv} = {
            objects => $c->model('DB::Problem')->search_rs(
                $params,
                {
                    join => ['admin_log_entries', 'user'],
                    distinct => 1,
                    columns => [
                        'id',       'created',
                        'latitude', 'longitude',
                        'cobrand',  'category',
                        'state',    'user_id',
                        'external_body',
                        'title', 'detail',
                        'photo',
                        'whensent', 'lastupdate',
                        'service',
                        'extra',
                        { sum_time_spent => { sum => 'admin_log_entries.time_spent' } },
                        'name', 'user.id', 'user.email', 'user.phone', 'user.name',
                    ]
                }
            ),
            headers => [
                'Report ID', 'Created', 'Sent to Agency', 'Last Updated',
                'E', 'N', 'Category', 'Status', 'Closure Status',
                'UserID', 'User email', 'User phone', 'User name',
                'External Body', 'Time Spent', 'Title', 'Detail',
                'Media URL', 'Interface Used', 'Council Response',
                'Strasse', 'Mast-Nr.', 'Haus-Nr.', 'Hydranten-Nr.',
            ],
            columns => [
                'id', 'created', 'whensent',' lastupdate', 'local_coords_x',
                'local_coords_y', 'category', 'state', 'closure_status',
                'user_id', 'user_email', 'user_phone', 'user_name',
                'body_name', 'sum_time_spent', 'title', 'detail',
                'media_url', 'service', 'public_response',
                'strasse', 'mast_nr',' haus_nr', 'hydranten_nr',
            ],
            extra_data => sub {
                my $report = shift;

                my $body_name = "";
                if ( my $external_body = $report->body($c) ) {
                    $body_name = $external_body->name || '[Unknown body]';
                }

                my $detail = $report->detail;
                my $public_response = $report->get_extra_metadata('public_response') || '';
                my $metas = $report->get_extra_fields();
                my %extras;
                foreach my $field (@$metas) {
                    $extras{$field->{name}} = $field->{value};
                }

                # replace newlines with HTML <br/> element
                $detail =~ s{\r?\n}{ <br/> }g;
                $public_response =~ s{\r?\n}{ <br/> }g if $public_response;

                # Assemble photo URL, if report has a photo
                my $photo_to_display = $c->cobrand->allow_photo_display($report);
                my $media_url = (@{$report->photos} && $photo_to_display)
                    ? $c->cobrand->base_url . $report->photos->[$photo_to_display-1]->{url}
                    : '';

                return {
                    whensent => $report->whensent,
                    lastupdate => $report->lastupdate,
                    user_id => $report->user_id,
                    user_email => $report->user->email || '',
                    user_phone => $report->user->phone || '',
                    user_name => $report->name,
                    closure_status => $report->get_extra_metadata('closure_status') || '',
                    body_name => $body_name,
                    sum_time_spent => $report->get_column('sum_time_spent') || 0,
                    detail => $detail,
                    media_url => $media_url,
                    service => $report->service || 'Web interface',
                    public_response => $public_response,
                    strasse => $extras{'strasse'} || '',
                    mast_nr => $extras{'mast_nr'} || '',
                    haus_nr => $extras{'haus_nr'} || '',
                    hydranten_nr => $extras{'hydranten_nr'} || ''
                };
            },
            filename => 'stats',
        };
        $c->forward('/dashboard/generate_csv');
    } catch {
        die $_;
    } finally {
        $c->model('DB')->schema->storage->sql_maker->quote_char('');
    };
}

sub problem_confirm_email_extras {
    my ($self, $report) = @_;
    my $confirmed_reports = $report->user->problems->search({
        extra => { like => '%email_confirmed%' },
    })->count;

    $self->{c}->stash->{email_confirmed} = $confirmed_reports;
}

sub reports_per_page { return 20; }

sub singleton_bodies_str { 1 }

sub contact_extra_fields { [ 'abbreviation' ] };

sub default_problem_state { 'submitted' }

sub db_state_migration {
    my $rs = FixMyStreet::DB->resultset('State');

    # Create new states needed
    $rs->create({ label => 'submitted', type => 'open', name => 'Erfasst' });
    $rs->create({ label => 'feedback pending', type => 'open', name => 'Rückmeldung ausstehend' });
    $rs->create({ label => 'wish', type => 'closed', name => 'Wunsch' });
    $rs->create({ label => 'external', type => 'closed', name => 'Extern' });
    $rs->create({ label => 'jurisdiction unknown', type => 'closed', name => 'Zuständigkeit unbekannt' });
    $rs->create({ label => 'not contactable', type => 'closed', name => 'Nicht kontaktierbar' });

    # And update used current ones to have correct name
    $rs->find({ label => 'in progress' })->update({ name => 'In Bearbeitung' });
    $rs->find({ label => 'fixed' })->update({ name => 'Beantwortet' });

    # Move reports to correct new state
    my %state_move = (
        unconfirmed => 'submitted',
        closed => 'external',
        investigating => 'wish',
        'unable to fix' => 'jurisdiction unknown',
        planned => 'feedback pending',
        partial => 'not contactable',
    );
    foreach (keys %state_move) {
        FixMyStreet::DB->resultset('Problem')->search({ state => $_ })->update({ state => $state_move{$_} });
    }

    # Delete unused standard states from the database
    for ('action scheduled', 'duplicate', 'not responsible', 'internal referral', 'planned', 'investigating', 'unable to fix') {
        $rs->find({ label => $_ })->delete;
    }
}

1;
