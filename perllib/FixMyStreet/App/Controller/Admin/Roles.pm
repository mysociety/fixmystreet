package FixMyStreet::App::Controller::Admin::Roles;
use Moose;
use Data::Dumper;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; }

sub index : Path {
    my ($self, $c) = @_;

    $c->stash->{roles} = $c->model("DB::Role");
}

sub create : Path('new') : Args(0) : FormConfig('/Users/davea/Code/fixmystreet/fixmystreet/forms/admin/roles/form.yml') {
    my ($self, $c) = @_;

    $c->stash->{role} = $c->model('DB::Role')->new_result({});
    $c->stash->{title} = _("Create Role");
    $c->forward('process_form');
}

sub edit : Path : Args(1) : FormConfig('/Users/davea/Code/fixmystreet/fixmystreet/forms/admin/roles/form.yml') {
    my ($self, $c, $role_id) = @_;

    $c->stash->{role} = $c->model('DB::Role')->find($role_id)
        or $c->detach( '/page_error_404_not_found' );
    $c->stash->{title} = _("Edit Role");
    $c->forward('process_form');
}

sub process_form : Private {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/roles/form.html';
    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {
        $form->model->update($c->stash->{role});
        $c->response->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    } else {
        $form->model->default_values($c->stash->{role});
        my @body_objs = $c->model("DB::Body")->search({ deleted => 0 });
        my @bodies;
        foreach (sort {$a->name cmp $b->name} @body_objs) {
            push(@bodies, [$_->id, $_->name]);
        }
        my $select = $form->get_element({name => 'body_id'});
        $select->options(\@bodies);
        my $checkboxes = $form->get_element({name => 'permissions'});

        # my @all_permissions = map { keys %$_ } values %{ $c->cobrand->available_permissions };
        # $checkboxes->values(\@all_permissions);

        my $perms = $c->cobrand->available_permissions;
        my $options = { map { %$_ } values %$perms };
        my @options = map { [ $_, $options->{$_} ] } keys %$options;
        $checkboxes->options(\@options);

    }
}

sub string_array {
    my ($value, $input) = @_;
    print STDERR Dumper(\@_);
    my $perms = $input->{permissions};
    $perms = [ $perms ] unless ref($perms) eq 'ARRAY';
    return $perms;
}

__PACKAGE__->meta->make_immutable;

1;