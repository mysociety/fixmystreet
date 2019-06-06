package FixMyStreet::App::Controller::Admin::ResponsePriorities;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::App::Form::ResponsePriority;

sub auto :Private {
    my ($self, $c) = @_;

    my $user = $c->user;
    if ($user->is_superuser) {
        $c->stash(rs => $c->model('DB::ResponsePriority')->search_rs(undef, {
            prefetch => 'body',
            order_by => ['body.name', 'me.name']
        }));
    } elsif ($user->from_body) {
        $c->stash(rs => $user->from_body->response_priorities->search_rs(undef, {
            order_by => 'name'
        }));
    }
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if (my $body_id = $c->get_param('body_id')) {
        $c->res->redirect($c->uri_for($self->action_for('create'), [ $body_id ]));
        $c->detach;
    }
    if ($c->user->is_superuser) {
        $c->forward('/admin/fetch_all_bodies');
    }
    $c->stash(
        response_priorities => [ $c->stash->{rs}->all ],
    );
}

sub body :PathPart('admin/responsepriorities') :Chained :CaptureArgs(1) {
    my ($self, $c, $body_id) = @_;

    my $user = $c->user;
    if ($user->is_superuser) {
        $c->stash->{body} = $c->model('DB::Body')->find($body_id);
    } elsif ($user->from_body && $user->from_body->id == $body_id) {
        $c->stash->{body} = $user->from_body;
    }

    $c->detach( '/page_error_404_not_found' ) unless $c->stash->{body};
}

sub create :Chained('body') :Args(0) {
    my ($self, $c) = @_;

    my $priority = $c->stash->{rs}->new_result({ body => $c->stash->{body} });
    return $self->form($c, $priority);
}

sub item :PathPart('') :Chained('body') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $obj = $c->stash->{rs}->find($id)
        or $c->detach('/page_error_404_not_found', []);
    $c->stash(obj => $obj);
}

sub edit :PathPart('') :Chained('item') :Args(0) {
    my ($self, $c) = @_;
    return $self->form($c, $c->stash->{obj});
}

sub form {
    my ($self, $c, $priority) = @_;

    # Otherwise, the form includes contacts for *all* bodies
    $c->forward('/admin/fetch_contacts');
    my @all_contacts = map {
        { value => $_->id, label => $_->category }
    } $c->stash->{live_contacts}->all;

    my $opts = {
        field_list => [
            '+contacts' => { options => \@all_contacts },
        ],
        body_id => $c->stash->{body}->id,
    };

    my $form = FixMyStreet::App::Form::ResponsePriority->new(%$opts);
    $c->stash(template => 'admin/responsepriorities/edit.html', form => $form);
    $form->process(item => $priority, params => $c->req->params);
    return unless $form->validated;

    $c->response->redirect($c->uri_for($self->action_for('index')));
}

__PACKAGE__->meta->make_immutable;

1;
