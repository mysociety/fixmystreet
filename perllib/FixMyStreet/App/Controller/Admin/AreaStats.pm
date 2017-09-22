package FixMyStreet::App::Controller::Admin::AreaStats;
use Moose;
use namespace::autoclean;
use List::Util qw(sum);

BEGIN { extends 'Catalyst::Controller'; }

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->forward('/admin/fetch_all_bodies');
    } elsif ( $user->from_body ) {
        $c->forward('load_user_body', [ $user->from_body->id ]);
        $c->stash->{body_id} = $user->from_body->id;
        if ($user->area_id) {
            $c->stash->{area_id} = $user->area_id;
            $c->forward('setup_area');
            $c->visit( 'stats' );
        } else {
            # visit body_stats so we load the list of child areas
            $c->visit( 'body_stats', [ $user->from_body->id], [] );
        }
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub check_user : Private {
    my ( $self, $c, $body_id, $area_id ) = @_;

    my $user = $c->user;

    return if $user->is_superuser;

    if ($body_id and $user->from_body->id eq $body_id) {
        if (not $user->area_id) {
            return;
        } elsif ($area_id and $user->area_id eq $area_id) {
            return;
        }
    }

    $c->detach( '/page_error_404_not_found' );
}

sub setup_area : Private {
    my ($self, $c) = @_;

    my $area = mySociety::MaPit::call('area', $c->stash->{area_id} );
    $c->detach( '/page_error_404_not_found' ) if $area->{error};
    $c->stash->{area} = $area;
}

sub body_base : Chained('/') : PathPart('admin/areastats') : CaptureArgs(1) {
    my ($self, $c, $body_id) = @_;

    $c->forward('/admin/lookup_body', $body_id);
    $c->stash->{areas} = mySociety::MaPit::call('area/children', [ $c->stash->{body_id} ] );
}

sub body_stats : Chained('body_base') : PathPart('') : Args(0) {
    my ($self, $c) = @_;

    if ($c->get_param('area')) {
        $c->forward('check_user', [$c->stash->{body_id}, $c->get_param('area')]);
        $c->stash->{area_id} = $c->get_param('area');
        $c->forward('setup_area');
    } else {
        $c->forward('check_user', [$c->stash->{body_id}]);
    }
    $c->forward('stats');
}

sub stats : Private {
    my ($self, $c) = @_;

    my $date = DateTime->now->subtract(days => 30);
    # set it to midnight so we get consistent result through the day
    $date->truncate( to => 'day' );

    $c->forward('/admin/fetch_contacts');

    $c->stash->{template} = 'admin/areastats/area.html';

    my $dtf = $c->model('DB')->storage->datetime_parser;
    my $time = $dtf->format_datetime($date);

    my $params = {
        'me.confirmed' => { '>=', $time },
    };

    my %area_param = ();
    if ($c->stash->{area}) {
        my $area_id = $c->stash->{area_id};
        $c->stash->{area_name} = $c->stash->{area}->{name};
        $params->{'problem.areas'} = { like => "%,$area_id,%" };
        %area_param = (
            areas => { like => "%,$area_id,%" },
        );
    } else {
        $c->stash->{area_name} = $c->stash->{body}->name;
    }

    my %by_category = map { $_->category => {} } $c->stash->{contacts}->all;
    my %recent_by_category = map { $_->category => 0 } $c->stash->{contacts}->all;

    my $state_map = {};

    $state_map->{$_} = 'open' foreach FixMyStreet::DB::Result::Problem->open_states;
    $state_map->{$_} = 'closed' foreach FixMyStreet::DB::Result::Problem->closed_states;
    $state_map->{$_} = 'fixed' foreach FixMyStreet::DB::Result::Problem->fixed_states;
    $state_map->{$_} = 'scheduled' foreach ('planned', 'action scheduled');

    # current problems by category and state
    my $problems = $c->model('DB::Problem')->to_body(
        $c->stash->{body}
    )->search(
        \%area_param,
        {
            group_by => [ 'category', 'state' ],
            select   => [ 'category', 'state', { count => 'me.id' } ],
            as       => [ qw/category state state_count/ ],
        }
    );

    while (my $p = $problems->next) {
        my $meta_state = $state_map->{$p->state};
        $by_category{$p->category}->{$meta_state} += $p->get_column('state_count');
    }
    $c->stash->{by_category} = \%by_category;

    # problems this month by state
    $c->stash->{$_} = 0 for values %$state_map;

    $c->stash->{open} = $c->model('DB::Problem')->to_body(
        $c->stash->{body}
    )->search(
        {
            %area_param,
            confirmed => { '>=' => $time },
        }
    )->count;

    my $comments = $c->model('DB::Comment')->to_body(
        $c->stash->{body}
    )->search(
        {
            %$params,
            'me.id' => { 'in' => \"(select min(id) from comment where me.problem_id=comment.problem_id and problem_state not in ('', 'confirmed') group by problem_state)" },
        },
        {
            join     => 'problem',
            group_by => [ 'problem_state' ],
            select   => [ 'problem_state', { count => 'me.id' } ],
            as       => [ qw/problem_state state_count/ ],
        }
    );

    while (my $comment = $comments->next) {
        my $meta_state = $state_map->{$comment->problem_state};
        $c->stash->{$meta_state} += $comment->get_column('state_count');
    }

    $params = {
        %area_param,
        'me.confirmed' => { '>=', $time },
    };

    # problems this month by category
    my $recent_problems = $c->model('DB::Problem')->to_body(
        $c->stash->{body}
    )->search(
        $params,
        {
            group_by => [ 'category' ],
            select   => [ 'category', { count => 'me.id' } ],
            as       => [ qw/category category_count/ ],
        }
    );

    while (my $p = $recent_problems->next) {
        $recent_by_category{$p->category} += $p->get_column('category_count');
    }
    $c->stash->{recent_by_category} = \%recent_by_category;

    # average time to state change in last month
    $params = {
        %area_param,
        'problem.confirmed' => { '>=', $time },
    };

    $comments = $c->model('DB::Comment')->to_body(
        $c->stash->{body}
    )->search(
        { %$params,
            'me.id' => \"= (select min(id) from comment where me.problem_id=comment.problem_id)",
            'me.problem_state' => { '!=' => 'confirmed' },
        },
        {
            select   => [
                { avg => { extract => "epoch from me.confirmed-problem.confirmed" } },
            ],
            as       => [ qw/time/ ],
            join     => 'problem'
        }
    )->first;
    $c->stash->{average} = int( ($comments->get_column('time')||0)/ 60 / 60 / 24 + 0.5 );
}

sub load_user_body : Private {
    my ($self, $c, $body_id) = @_;

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found' );
}

1;
