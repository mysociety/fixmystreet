package FixMyStreet::App::Controller::Admin::Triage;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Admin::Triage - Catalyst Controller

=head1 DESCRIPTION

Admin pages for triaging reports.

This allows reports to be triaged before being sent to the council. It works
by having a set of categories with a send_method of Triage which sets the report
state to 'for_triage'. Any reports with the state are then show on '/admin/triage'
which is available to users with the 'triage' permission.

Clicking on reports on this list will then allow a user to change the category of
the report to one that has an alternative send method, which will trigger the report
to be resent.

In order for this to work additional work needs to be done to the cobrand to only
display triageable categories to the user.

=head1 METHODS

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    unless ( $c->user->has_body_permission_to('triage') ) {
        $c->detach('/page_error_403_access_denied', []);
    }
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    # default sort to oldest
    unless ( $c->get_param('sort') ) {
        $c->set_param('sort', 'created-asc');
    }
    $c->stash->{body} = $c->forward('/reports/body_find', [ $c->cobrand->council_area ]);
    $c->forward( 'stash_report_filter_status' );
    $c->forward('/reports/stash_report_sort', [ $c->cobrand->reports_ordering ]);
    $c->forward( '/reports/load_and_group_problems' );
    $c->stash->{page} = 'reports'; # So the map knows to make clickable pins

    if ($c->get_param('ajax')) {
        my $ajax_template = $c->stash->{ajax_template} || 'reports/_problem-list.html';
        $c->detach('/reports/ajax', [ $ajax_template ]);
    }

    my @categories = $c->stash->{body}->contacts->not_deleted->search( undef, {
        columns => [ 'id', 'category', 'extra' ],
        distinct => 1,
    } )->all_sorted;
    $c->stash->{filter_categories} = \@categories;
    $c->stash->{filter_category} = { map { $_ => 1 } $c->get_param_list('filter_category', 1) };
    my $pins = $c->stash->{pins} || [];

    my %map_params = (
        latitude  => @$pins ? $pins->[0]{latitude} : 0,
        longitude => @$pins ? $pins->[0]{longitude} : 0,
        area      => [ $c->stash->{wards} ? map { $_->{id} } @{$c->stash->{wards}} : keys %{$c->stash->{body}->areas} ],
        any_zoom  => 1,
    );
    FixMyStreet::Map::display_map(
        $c, %map_params, pins => $pins,
    );
}

sub stash_report_filter_status : Private {
    my ( $self, $c ) = @_;
    $c->stash->{filter_problem_states} = { 'for triage' => 1 };
    return 1;
}

sub setup_categories : Private {
    my ( $self, $c ) = @_;

    if ( $c->stash->{problem}->state eq 'for triage' ) {
        $c->stash->{holding_options} = [ grep { $_->send_method && $_->send_method eq 'Triage' } @{$c->stash->{category_options}} ];
        $c->stash->{holding_categories} = { map { $_->category => 1 } @{$c->stash->{holding_options}} };
        $c->stash->{end_options} = [ grep { !$_->send_method || $_->send_method ne 'Triage' } @{$c->stash->{category_options}} ];
        $c->stash->{end_categories} = { map { $_->category => 1 } @{$c->stash->{end_options}} };
        delete $c->stash->{categories_hash};
        my %category_groups = ();
        for my $category (@{$c->stash->{end_options}}) {
            my $group = $category->{group} // $category->get_extra_metadata('group') // [''];
            # this could be an array ref or a string
            my @groups = ref $group eq 'ARRAY' ? @$group : ($group);
            push( @{$category_groups{$_}}, $category ) for @groups;
        }
        my @category_groups = ();
        for my $group ( grep { $_ ne _('Other') } sort keys %category_groups ) {
            push @category_groups, { name => $group, categories => $category_groups{$group} };
        }
        $c->stash->{end_groups} = \@category_groups;
    }

    return 1;
}

sub update : Private {
    my ($self, $c) = @_;

    my $problem = $c->stash->{problem};

    my $current_category = $problem->category;
    my $new_category = $c->get_param('category');

    my $changed = $c->forward('/admin/reports/edit_category', [ $problem, 1 ] );

    if ( $changed ) {
        $c->stash->{problem}->update( { state => 'confirmed' } );
        $c->forward( '/admin/log_edit', [ $problem->id, 'problem', 'triage' ] );

        my $name = $c->user->moderating_user_name;
        my $extra = { is_superuser => 1 };
        if ($c->user->from_body) {
            delete $extra->{is_superuser};
            $extra->{is_body_user} = $c->user->from_body->id;
        }

        $extra->{triage_report} = 1;
        $extra->{holding_category} = $current_category;
        $extra->{new_category} = $new_category;

        my $timestamp = \'current_timestamp';
        my $comment = $problem->add_to_comments( {
            text => "Report triaged from $current_category to $new_category",
            created => $timestamp,
            confirmed => $timestamp,
            user_id => $c->user->id,
            name => $name,
            mark_fixed => 0,
            anonymous => 0,
            state => 'confirmed',
            problem_state => $problem->state,
            extra => $extra,
            whensent => \'current_timestamp',
        } );

        my @alerts = FixMyStreet::DB->resultset('Alert')->search( {
            alert_type => 'new_updates',
            parameter  => $problem->id,
            confirmed  => 1,
        } );

        for my $alert (@alerts) {
            my $alerts_sent = FixMyStreet::DB->resultset('AlertSent')->find_or_create( {
                alert_id  => $alert->id,
                parameter => $comment->id,
            } );
        }
    }
}

1;
