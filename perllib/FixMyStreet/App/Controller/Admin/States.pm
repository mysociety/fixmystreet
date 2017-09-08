package FixMyStreet::App::Controller::Admin::States;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');
    $c->forward('/admin/fetch_languages');
    my $rs = $c->model('DB::State');

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/check_csrf_token');

        $c->forward('process_new')
        && $c->forward('delete')
        && $c->forward('update');

        $rs->clear;
    }

    $c->stash->{open_states} = $rs->open;
    $c->stash->{closed_states} = $rs->closed;
    $c->stash->{fixed_states} = $rs->fixed;
}

sub process_new : Private {
    my ($self, $c) = @_;
    if ($c->get_param('new_fixed')) {
        $c->model('DB::State')->create({
            label => 'fixed',
            type => 'fixed',
            name => _('Fixed'),
        });
        return 0;
    }
    return 1 unless $c->get_param('new');
    my %params = map { $_ => $c->get_param($_) } qw/label type name/;
    $c->model('DB::State')->create(\%params);
    return 0;
}

sub delete : Private {
    my ($self, $c) = @_;

    my @params = keys %{ $c->req->params };
    my ($to_delete) = map { /^delete:(.*)/ } grep { /^delete:/ } @params;
    if ($to_delete) {
        $c->model('DB::State')->search({ label => $to_delete })->delete;
        return 0;
    }
    return 1;
}

sub update : Private {
    my ($self, $c) = @_;

    my $rs = $c->model('DB::State');
    my %db_states = map { $_->label => $_ } @{$rs->states};
    my @params = keys %{ $c->req->params };
    my @states = map { /^type:(.*)/ } grep { /^type:/ } @params;

    foreach my $state (@states) {
        # If there is only one language, we still store confirmed/closed
        # as translations, as that seems a sensible place to store them.
        if ($state eq 'confirmed' or $state eq 'closed') {
            if (my $name = $c->get_param("name:$state")) {
                my ($lang) = keys %{$c->stash->{languages}};
                $db_states{$state}->add_translation_for('name', $lang, $name);
            }
        } else {
            $db_states{$state}->update({
                type => $c->get_param("type:$state"),
                name => $c->get_param("name:$state"),
            });
        }

        foreach my $lang (keys(%{$c->stash->{languages}})) {
            my $id = $c->get_param("translation_id:$state:$lang");
            my $text = $c->get_param("translation:$state:$lang");
            if ($text) {
                $db_states{$state}->add_translation_for('name', $lang, $text);
            } elsif ($id) {
                $c->model('DB::Translation')->find({ id => $id })->delete;
            }
        }
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
