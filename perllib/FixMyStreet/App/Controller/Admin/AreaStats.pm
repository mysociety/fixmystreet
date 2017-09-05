package FixMyStreet::App::Controller::Admin::AreaStats;
use Moose;
use namespace::autoclean;
use List::Util qw(sum);

BEGIN { extends 'Catalyst::Controller'; }

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->forward('/admin/begin');
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->forward('/admin/fetch_all_bodies');
    } elsif ( $user->from_body ) {
        $c->forward('load_user_body', [ $user->from_body->id ]);
        $c->res->redirect( $c->uri_for( '/admin/areastats/body', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub body : Path('body') : Args(1) {
    my ($self, $c, $body_id) = @_;
    $c->stash->{areas} = mySociety::MaPit::call('area/children', [ $body_id ] );
}

sub area : Path : Args(1) {
    my ($self, $c, $area_id) = @_;

    my $date = DateTime->now->subtract(days => 30);
    my $area = mySociety::MaPit::call('area', $area_id );
    my $user = $c->user;

    $c->forward('load_user_body', [ $user->from_body->id ]);
    $c->forward('/admin/fetch_contacts');

    if ($area->{name}) {
        $c->stash->{area} = $area;

        my $dtf = $c->model('DB')->storage->datetime_parser;
        my $time = $dtf->format_datetime($date);

        my $params = {
            'problem.areas' => { like => "%,$area_id,%" },
            'me.confirmed' => { '>=', $time },
        };

        my $comments = $c->model('DB::Comment')->search(
            $params,
            {
                group_by => [ 'problem_state' ],
                select   => [ 'problem_state', { count => 'me.id' } ],
                as       => [ qw/state state_count/ ],
                join     => 'problem'
            }
        );

        $params = {
            areas => { like => "%,$area_id,%" },
        };

        my $problems = $c->model('DB::Problem')->search(
            $params,
            {
                group_by => [ 'category', 'state' ],
                select   => [ 'category', 'state', { count => 'me.id' } ],
                as       => [ qw/category state state_count/ ],
            }
        );

        my %by_category = map { $_->category => {} } $c->stash->{live_contacts}->all;

        my $state_map = {};

        $state_map->{$_} = 'open' foreach FixMyStreet::DB::Result::Problem->open_states;
        $state_map->{$_} = 'closed' foreach FixMyStreet::DB::Result::Problem->closed_states;
        $state_map->{$_} = 'fixed' foreach FixMyStreet::DB::Result::Problem->fixed_states;
        $state_map->{$_} = 'scheduled' foreach ('planned', 'action scheduled');

        for my $p ($problems->all) {
            my $meta_state = $state_map->{$p->state};
            $by_category{$p->category}->{$meta_state} += $p->get_column('state_count');
        }

        $c->stash->{$_} = 0 for values %$state_map;

        $c->stash->{open} = $c->model('DB::Problem')->search(
            {
                areas => { like => "%,$area_id,%" },
                confirmed => { '>=' => DateTime::Format::W3CDTF->format_datetime($date) },
            }
        )->count;

        for my $comment ($comments->all) {
            my $meta_state = $state_map->{$comment->get_column('state')};
            $c->stash->{$meta_state} += $comment->get_column('state_count');
        }

        $comments = $c->model('DB::Comment')->search(
            { %$params,
                'me.id' => \"= (select min(id) from comment where me.problem_id=comment.problem_id)",
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

        $c->stash->{by_category} = \%by_category;
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub load_user_body : Private {
    my ($self, $c, $body_id) = @_;

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found' );
}

1;
