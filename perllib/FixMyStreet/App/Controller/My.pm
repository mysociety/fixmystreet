package FixMyStreet::App::Controller::My;
use Moose;
use namespace::autoclean;

use JSON::MaybeXS;
use List::MoreUtils qw(first_index);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::My - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub auto : Private {
    my ($self, $c) = @_;
    $c->detach( '/auth/redirect' ) unless $c->user;
    return 1;
}

=head2 index

=cut

sub my : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');

    $c->stash->{problems_rs} = $c->cobrand->problems->search(
        { user_id => $c->user->id });
    $c->forward('/reports/stash_report_sort', [ 'created-desc' ]);
    $c->forward('get_problems');
    if ($c->get_param('ajax')) {
        $c->detach('/reports/ajax', [ 'my/_problem-list.html' ]);
    }
    $c->forward('get_updates');
    $c->forward('setup_page_data');
}


=head2 inspector_redirect

A convenience redirect to the /reports/ page pre-filtered to the
inspector's body, areas & categories.

=cut

sub inspector_redirect : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $categories = $c->user->categories_string;
    my $area_ids = $c->user->area_ids || [];
    my $body = $c->user->from_body;

    $c->detach('/page_error_404_not_found') unless $body && ($categories || @$area_ids);

    if (@$area_ids) {
        my $ids_string = join ",", @$area_ids;
        my $areas = mySociety::MaPit::call('areas', [ $ids_string ]);
        $c->stash->{wards} = [ values %$areas ];
    }

    $c->stash->{body} = $body;
    $c->set_param('filter_category', $categories) if $categories;
    $c->detach('/reports/redirect_body');
}

sub planned : Local : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');

    $c->detach('/page_error_403_access_denied', [])
        unless $c->user->has_body_permission_to('planned_reports');

    $c->stash->{problems_rs} = $c->user->active_planned_reports->search(undef, { '+columns' => [ { 'upr_id' => 'me.id' } ] });
    $c->forward('planned_reorder');
    $c->forward('/reports/stash_report_sort', [ 'shortlist' ]);
    $c->forward('get_problems');
    if ($c->get_param('ajax')) {
        $c->stash->{shortlist} = $c->stash->{sort_key} eq 'shortlist';
        $c->detach('/reports/ajax', [ 'my/_problem-list.html' ]);
    }
    $c->forward('setup_page_data');
}

sub planned_reorder : Private {
    my ($self, $c) = @_;

    my @extra = grep { /^shortlist-(up|down|\d+)$/ } keys %{$c->req->params};
    return unless @extra;
    my ($reorder) = $extra[0] =~ /^shortlist-(up|down|\d+)$/;

    my @shortlist = sort by_shortlisted $c->stash->{problems_rs}->all;

    # Find where moving problem ID is
    my $id = $c->get_param('id') || return;
    my $curr_index = first_index { $_->id == $id } @shortlist;
    return unless $curr_index > -1;

    if ($reorder eq 'up' && $curr_index > 0) {
        @shortlist[$curr_index-1,$curr_index] = @shortlist[$curr_index,$curr_index-1];
    } elsif ($reorder eq 'down' && $curr_index < @shortlist-1) {
        @shortlist[$curr_index,$curr_index+1] = @shortlist[$curr_index+1,$curr_index];
    } elsif ($reorder >= 0 && $reorder <= @shortlist-1) { # Must be an index to move it
        @shortlist[$curr_index,$reorder] = @shortlist[$reorder,$curr_index];
    }

    # Store new ordering
    my $i = 1;
    foreach (@shortlist) {
        $_->set_extra_metadata('order', $i++);
        $_->update;
    }
}

sub get_problems : Private {
    my ($self, $c) = @_;

    $c->stash->{page} = 'my';

    my $p_page = $c->get_param('p') || 1;

    $c->forward( '/reports/stash_report_filter_status' );

    my $pins = [];
    my $problems = [];

    my $states = $c->stash->{filter_problem_states};
    my $table = $c->action eq 'my/planned' ? 'report' : 'me';
    my $params = {
        "$table.state" => [ keys %$states ],
    };

    # We do not want to show bulky goods cancellation reports
    $params->{"$table.category"}{'!='} = 'Bulky cancel';

    my $categories = [ $c->get_param_list('filter_category', 1) ];
    if ( @$categories ) {
        $params->{"$table.category"}{'='} = $categories;
        $c->stash->{filter_category} = { map { $_ => 1 } @$categories };
    }

    my $rows = 50;
    $rows = 200 if $c->stash->{sort_key} eq 'shortlist'; # Can show more per page

    my $rs = $c->stash->{problems_rs}->search( $params, {
        prefetch => 'contact',
        '+columns' => { 'contact.msgstr' => '' }, # To fill below
        order_by => $c->stash->{sort_order},
        rows => $rows,
    } )->include_comment_counts->page( $p_page );

    my @categories = $c->stash->{problems_rs}->search({
        "$table.state" => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        "$table.category" => { '!=', 'Bulky cancel' },
    }, {
        join => { 'contact' => 'translations' },
        columns => [ "$table.category", { 'msgstr' => \"COALESCE(translations.msgstr, $table.category)" } ],
        bind => [ 'category', $c->stash->{lang_code}, 'contact' ],
        distinct => 1,
    } )->all;
    my %cats = map { $_->category => $_->get_column('msgstr') } @categories;

    while ( my $problem = $rs->next ) {
        $problem->contact->set_column(msgstr => $cats{$problem->category});
        $c->stash->{has_content}++;
        push @$pins, $problem->pin_data('my', private => 1);
        push @$problems, $problem;
    }

    @$problems = sort by_shortlisted @$problems if $c->stash->{sort_key} eq 'shortlist';

    $c->stash->{problems_pager} = $rs->pager;
    $c->stash->{problems} = $problems;
    $c->stash->{pins} = $pins;
}

sub get_updates : Private {
    my ($self, $c) = @_;

    my $u_page = $c->get_param('u') || 1;
    my $rs = $c->user->comments->search(
        { state => 'confirmed' },
        {
            order_by => { -desc => 'confirmed' },
            rows => 50
        } )->page( $u_page );

    my @updates = $rs->all;
    $c->stash->{has_content} += scalar @updates;
    $c->stash->{updates} = \@updates;
    $c->stash->{updates_pager} = $rs->pager;
}

sub setup_page_data : Private {
    my ($self, $c) = @_;

    my $table = $c->action eq 'my/planned' ? 'report' : 'me';
    my @categories = $c->stash->{problems_rs}->search({
        "$table.state" => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        "$table.category" => { '!=', 'Bulky cancel' },
    }, {
        join => 'contact',
        columns => [ "$table.category", 'contact.extra', 'contact.category' ],
        distinct => 1,
        order_by => [ "$table.category" ],
    } )->all;
    # Ensure only uniquely named categories are shown
    my %seen;
    @categories = grep { !$seen{$_->category_display}++ } @categories;
    $c->stash->{filter_categories} = \@categories;

    my @contacts = map { {
        category => $_->category,
        category_display => $_->category_display,
        group => [''],
    } } @categories;
    $c->forward('/report/stash_category_groups', [ \@contacts ]);

    my $pins = $c->stash->{pins};
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $pins->[0]{latitude},
        longitude => $pins->[0]{longitude},
        pins      => $pins,
        any_zoom  => 1,
    )
        if @$pins;

    foreach (qw(flash_message)) {
        $c->stash->{$_} = $c->flash->{$_} if $c->flash->{$_};
    }
}

sub planned_change : Path('planned/change') {
    my ($self, $c) = @_;
    $c->forward('/auth/check_csrf_token');

    $c->go('planned') if grep { /^shortlist-(up|down|\d+)$/ } keys %{$c->req->params};

    my $id = $c->get_param('id');
    my $add = $c->get_param('shortlist-add');
    my $remove = $c->get_param('shortlist-remove');

    # we can't lookup the report for removing via load_problem_or_display_error
    # as then there is no way to remove a report that has been hidden or moved
    # to another body by a category change from the shortlist.
    if ($remove) {
        my $report = $c->model('DB::Problem')->find({ id => $id })
            or $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );
        $c->user->remove_from_planned_reports($report);
    } elsif ($add) {
        $c->forward( '/report/load_problem_or_display_error', [ $id ] );
        $c->user->add_to_planned_reports($c->stash->{problem});
    } else {
        $c->detach('/page_error_403_access_denied', []);
    }

    if ($c->get_param('ajax')) {
        $c->res->content_type('application/json; charset=utf-8');
        $c->res->body(encode_json({ outcome => $add ? 'add' : 'remove' }));
    } else {
        $c->res->redirect( $c->uri_for_action('report/display', [ $id ]) );
    }
}

sub shortlist_multiple : Path('planned/change_multiple') {
    my ($self, $c) = @_;
    $c->forward('/auth/check_csrf_token');

    my @ids = $c->get_param_list('ids[]');

    foreach my $id (@ids) {
      $c->forward( '/report/load_problem_or_display_error', [ $id ] );
      $c->user->add_to_planned_reports($c->stash->{problem});
    }

    $c->res->body(encode_json({ outcome => 'add' }));
}

sub bulk_assign : Path('planned/bulk_assign') {
    my ($self, $c) = @_;
    $c->forward('/auth/check_csrf_token');

    # check here
    $c->detach('/page_error_403_access_denied', [])
        unless  ($c->user->has_body_permission_to('assign_report_to_user'));

    my @bulk_reports = $c->get_param_list('bulk-assign-reports');
    my $assignee = $c->get_param('inspector');

    if (@bulk_reports) {
        if ($assignee eq 'unassigned') {
            # take off shortlist
            my @problems = $c->model('DB::Problem')->search({ id => { -in => [ @bulk_reports ]} });
            foreach my $problem (@problems) {
                my $current_assignee = $problem->shortlisted_user;
                $current_assignee->remove_from_planned_reports($problem)
                    if $current_assignee;
            }
        } else {
            # add to shortlist
            my $inspector = $c->model('DB::User')->find({ id => $assignee });
            # ... if actually an inspector:
            if ($inspector->has_body_permission_to('report_inspect')) {
                foreach my $report (@bulk_reports) {
                    $c->forward( '/report/load_problem_or_display_error', [ $report ] ); 
                    $inspector->add_to_planned_reports($c->stash->{problem});
                }
            }
        }
    }

    $c->stash->{body} = $c->user->from_body;
    $c->detach('/reports/redirect_body');
}

sub by_shortlisted {
    my $a_order = $a->get_extra_metadata('order') || 0;
    my $b_order = $b->get_extra_metadata('order') || 0;
    if ($a_order && $b_order) {
        $a_order <=> $b_order;
    } elsif ($a_order) {
        -1; # Want non-ordered to come last
    } elsif ($b_order) {
        1; # Want non-ordered to come last
    } else {
        # Default to order added to planned reports
        $a->get_column('upr_id') <=> $b->get_column('upr_id');
    }
}

sub anonymize : Path('anonymize') {
    my ($self, $c) = @_;
    $c->forward('/auth/get_csrf_token');

    my $object;
    if (my $id = $c->get_param('problem')) {
        $c->forward( '/report/load_problem_or_display_error', [ $id ] );
        $object = $c->stash->{problem};
    } elsif ($id = $c->get_param('update')) {
        $c->stash->{update} = $object = $c->model('DB::Comment')->find({ id => $id });
        unless ($object) {
            $c->stash->{internal_error} = "No update found for ID $id";
            $c->detach('/page_error_400_bad_request');
        }
    } else {
        $c->detach('/page_error_404_not_found');
    }
    unless ($c->user->id == $object->user_id) {
        $c->stash->{internal_error} = "User " . $c->user->id . " does not own this object with ID " . $object->id;
        $c->detach('/page_error_400_bad_request');
    }
    if ($object->anonymous) {
        $c->stash->{internal_error} = "Object " . $object->id . " is already anonymous";
        $c->detach('/page_error_400_bad_request');
    }

    if ($c->get_param('hide') || $c->get_param('hide_everywhere')) {
        unless ($c->req->method eq 'POST') {
            $c->stash->{internal_error} = "Not a POST request: " . $c->req->method;
            $c->detach('/page_error_400_bad_request');
        }
        $c->forward('/auth/check_csrf_token');
        if ($c->get_param('hide')) {
            $object->update({ anonymous => 1 });
            $c->flash->{anonymized} = _('Your name has been hidden.');
        } elsif ($c->get_param('hide_everywhere')) {
            $c->user->problems->update({anonymous => 1});
            $c->user->comments->update({anonymous => 1});
            $c->flash->{anonymized} = _('Your name has been hidden from all your reports and updates.');
        }
        $c->res->redirect($object->url);
    }
}

sub notify_preference : Local : Args(0) {
    my ( $self, $c ) = @_;

    unless ($c->req->method eq 'POST') {
        return $c->res->redirect('/my');
    }

    $c->forward('/auth/check_csrf_token');

    my $update_notify = $c->get_param('update_notify');
    my $alert_notify = $c->get_param('alert_notify');
    my $questionnaire_notify = $c->get_param('questionnaire_notify');

    $c->user->set_extra_metadata(
        update_notify => $update_notify,
        alert_notify => $alert_notify,
        questionnaire_notify => $questionnaire_notify,
    );
    $c->user->update;
    $c->res->redirect('/my');
}

__PACKAGE__->meta->make_immutable;

1;
