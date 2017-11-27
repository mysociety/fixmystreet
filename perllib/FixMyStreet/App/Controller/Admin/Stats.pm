package FixMyStreet::App::Controller::Admin::Stats;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $selected_body;
    if ( $c->user->is_superuser ) {
        $c->forward('/admin/fetch_all_bodies');
        $selected_body = $c->get_param('body');
    } else {
        $selected_body = $c->user->from_body->id;
    }

    if ( $c->cobrand->moniker eq 'zurich' ) {
        return $c->cobrand->admin_stats();
    }

    if ( $c->get_param('getcounts') ) {

        my ( $start_date, $end_date, @errors );
        my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' );

        $start_date = $parser-> parse_datetime ( $c->get_param('start_date') );

        push @errors, _('Invalid start date') unless defined $start_date;

        $end_date = $parser-> parse_datetime ( $c->get_param('end_date') ) ;

        push @errors, _('Invalid end date') unless defined $end_date;

        $c->stash->{errors} = \@errors;
        $c->stash->{start_date} = $start_date;
        $c->stash->{end_date} = $end_date;

        $c->stash->{unconfirmed} = $c->get_param('unconfirmed') eq 'on' ? 1 : 0;

        return 1 if @errors;

        my $bymonth = $c->get_param('bymonth');
        $c->stash->{bymonth} = $bymonth;

        $c->stash->{selected_body} = $selected_body;

        my $field = 'confirmed';

        $field = 'created' if $c->get_param('unconfirmed');

        my $one_day = DateTime::Duration->new( days => 1 );


        my %select = (
                select => [ 'state', { 'count' => 'me.id' } ],
                as => [qw/state count/],
                group_by => [ 'state' ],
                order_by => [ 'state' ],
        );

        if ( $c->get_param('bymonth') ) {
            %select = (
                select => [
                    { extract => \"year from $field", -as => 'c_year' },
                    { extract => \"month from $field", -as => 'c_month' },
                    { 'count' => 'me.id' }
                ],
                as     => [qw/c_year c_month count/],
                group_by => [qw/c_year c_month/],
                order_by => [qw/c_year c_month/],
            );
        }

        my $p = $c->cobrand->problems->to_body($selected_body)->search(
            {
                -AND => [
                    $field => { '>=', $start_date},
                    $field => { '<=', $end_date + $one_day },
                ],
            },
            \%select,
        );

        # in case the total_report count is 0
        $c->stash->{show_count} = 1;
        $c->stash->{states} = $p;
    }

    return 1;
}

sub state : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $problems = $c->cobrand->problems->summary_count;

    my %prob_counts =
      map { $_->state => $_->get_column('state_count') } $problems->all;

    %prob_counts =
      map { $_ => $prob_counts{$_} || 0 }
        ( FixMyStreet::DB::Result::Problem->all_states() );
    $c->stash->{problems} = \%prob_counts;
    $c->stash->{total_problems_live} += $prob_counts{$_} ? $prob_counts{$_} : 0
        for ( FixMyStreet::DB::Result::Problem->visible_states() );
    $c->stash->{total_problems_users} = $c->cobrand->problems->unique_users;

    my $comments = $c->cobrand->updates->summary_count;

    my %comment_counts =
      map { $_->state => $_->get_column('state_count') } $comments->all;

    $c->stash->{comments} = \%comment_counts;
}

sub fix_rate : Path('fix-rate') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{categories} = $c->cobrand->problems->categories_summary();
}

sub questionnaire : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $questionnaires = $c->model('DB::Questionnaire')->search(
        { whenanswered => { '!=', undef } },
        { group_by => [ 'ever_reported' ],
            select => [ 'ever_reported', { count => 'me.id' } ],
            as     => [ qw/reported questionnaire_count/ ] }
    );

    my %questionnaire_counts = map {
        ( defined $_->get_column( 'reported' ) ? $_->get_column( 'reported' ) : -1 )
            => $_->get_column( 'questionnaire_count' )
    } $questionnaires->all;
    $questionnaire_counts{1} ||= 0;
    $questionnaire_counts{0} ||= 0;
    $questionnaire_counts{total} = $questionnaire_counts{0} + $questionnaire_counts{1};
    $c->stash->{questionnaires} = \%questionnaire_counts;

    $c->stash->{state_changes_count} = $c->model('DB::Questionnaire')->search(
        { whenanswered => \'is not null' }
    )->count;
    $c->stash->{state_changes} = $c->model('DB::Questionnaire')->search(
        { whenanswered => \'is not null' },
        {
            group_by => [ 'old_state', 'new_state' ],
            columns => [ 'old_state', 'new_state', { c => { count => 'id' } } ],
        },
    );

    return 1;
}

1;
