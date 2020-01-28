package FixMyStreet::App::Controller::Admin::ManifestTheme;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::App::Form::ManifestTheme;

sub auto :Private {
    my ($self, $c) = @_;

    if ( $c->cobrand->moniker eq 'fixmystreet' ) {
        $c->stash(rs => $c->model('DB::ManifestTheme')->search_rs({}), show_all => 1);
    } else {
        $c->stash(rs => $c->model('DB::ManifestTheme')->search_rs({ cobrand => $c->cobrand->moniker }));
    }
}

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    unless ( $c->stash->{show_all} ) {
        if ( $c->stash->{rs}->count ) {
            $c->res->redirect($c->uri_for($self->action_for('edit'), [ $c->stash->{rs}->first->cobrand ]));
        } else {
            $c->res->redirect($c->uri_for($self->action_for('create')));
        }
        $c->detach;
    }
}

sub item :PathPart('admin/manifesttheme') :Chained :CaptureArgs(1) {
    my ($self, $c, $cobrand) = @_;

    my $obj = $c->stash->{rs}->find({ cobrand =>  $cobrand })
        or $c->detach('/page_error_404_not_found', []);
    $c->stash(obj => $obj);
}

sub edit :PathPart('') :Chained('item') :Args(0) {
    my ($self, $c) = @_;
    return $self->form($c, $c->stash->{obj});
}


sub create :Local :Args(0) {
    my ($self, $c) = @_;

    unless ( $c->stash->{show_all} || $c->stash->{rs}->count == 0) {
        $c->res->redirect($c->uri_for($self->action_for('edit'), [ $c->stash->{rs}->first->cobrand ]));
        $c->detach;
    }

    my $theme = $c->stash->{rs}->new_result({});
    return $self->form($c, $theme);
}

sub form {
    my ($self, $c, $theme) = @_;

    if ($c->get_param('delete_theme')) {
        $theme->delete;
        $c->forward('/admin/log_edit', [ $theme->id, 'manifesttheme', 'delete' ]);
        $c->response->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }

    my $action = $theme->in_storage ? 'edit' : 'add';
    my $form = FixMyStreet::App::Form::ManifestTheme->new( cobrand => $c->cobrand->moniker );
    $c->stash(template => 'admin/manifesttheme/form.html', form => $form);
    $form->process(item => $theme, params => $c->req->params);
    return unless $form->validated;

    $c->forward('/admin/log_edit', [ $theme->id, 'manifesttheme', $action ]);
    $c->response->redirect($c->uri_for($self->action_for('index')));
}



1;
