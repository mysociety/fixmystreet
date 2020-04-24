package FixMyStreet::App::Controller::Admin::Stats;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    return $c->cobrand->admin_stats() if $c->cobrand->moniker eq 'zurich';
    $c->forward('gather');
}

sub gather : Private {
    my ($self, $c) = @_;

    $c->forward('state'); # Problem/update stats used on that page
    $c->forward('/admin/fetch_all_bodies'); # For body stat

    my $alerts = $c->model('DB::Alert')->summary_report_alerts( $c->cobrand->restriction );

    my %alert_counts =
      map { $_->confirmed => $_->get_column('confirmed_count') } $alerts->all;

    $alert_counts{0} ||= 0;
    $alert_counts{1} ||= 0;

    $c->stash->{alerts} = \%alert_counts;

    my $contacts = $c->model('DB::Contact')->summary_count();

    my %contact_counts =
      map { $_->state => $_->get_column('state_count') } $contacts->all;

    $contact_counts{confirmed} ||= 0;
    $contact_counts{unconfirmed} ||= 0;
    $contact_counts{total} = $contact_counts{confirmed} + $contact_counts{unconfirmed};

    $c->stash->{contacts} = \%contact_counts;

    my $questionnaires = $c->model('DB::Questionnaire')->summary_count( $c->cobrand->restriction );

    my %questionnaire_counts = map {
        $_->get_column('answered') => $_->get_column('questionnaire_count')
    } $questionnaires->all;
    $questionnaire_counts{1} ||= 0;
    $questionnaire_counts{0} ||= 0;

    $questionnaire_counts{total} =
      $questionnaire_counts{0} + $questionnaire_counts{1};
    $c->stash->{questionnaires_pc} =
      $questionnaire_counts{total}
      ? sprintf( '%.1f',
        $questionnaire_counts{1} / $questionnaire_counts{total} * 100 )
      : _('n/a');
    $c->stash->{questionnaires} = \%questionnaire_counts;
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

sub refused : Local : Args(0) {
    my ($self, $c) = @_;

    my $contacts = $c->model('DB::Contact')->not_deleted->search([
        { email => 'REFUSED' },
        { 'body.can_be_devolved' => 1, 'me.send_method' => 'Refused' },
    ], { prefetch => 'body' });
    my %bodies;
    while (my $contact = $contacts->next) {
        my $body = $contact->body;
        $bodies{$body->id}{body} = $body unless $bodies{$body->id}{body};
        push @{$bodies{$body->id}{contacts}}, $contact;
    }

    my $bodies = $c->model('DB::Body')->search({ send_method => 'Refused' });
    while (my $body = $bodies->next) {
        $bodies{$body->id}{body} = $body;
        $bodies{$body->id}{all} = 1;
    }

    my @bodies;
    foreach (sort { $bodies{$a}{body}->name cmp $bodies{$b}{body}->name } keys %bodies) {
        push @bodies, $bodies{$_};
    }
    $c->stash->{bodies} = \@bodies;
}

1;
