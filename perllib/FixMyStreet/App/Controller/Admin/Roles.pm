package FixMyStreet::App::Controller::Admin::Roles;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::App::Form::Role;

sub auto :Private {
    my ($self, $c) = @_;

    my $user = $c->user;
    if ($user->is_superuser) {
        $c->stash(rs => $c->model('DB::Role')->search_rs({}, {
            prefetch => 'body',
            order_by => ['body.name', 'me.name']
        }));
    } elsif ($user->from_body) {
        $c->stash(rs => $user->from_body->roles->search_rs({}, { order_by => 'name' }));
    }
}

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    my $p = $c->cobrand->available_permissions;
    my %labels;
    foreach my $group (sort keys %$p) {
        my $group_vals = $p->{$group};
        foreach (sort keys %$group_vals) {
            $labels{$_} = $group_vals->{$_};
        }
    }

    $c->stash(
        roles => [ $c->stash->{rs}->all ],
        labels => \%labels,
    );
}

sub create :Local :Args(0) {
    my ($self, $c) = @_;

    my $role = $c->stash->{rs}->new_result({});
    return $self->form($c, $role);
}

sub item :PathPart('admin/roles') :Chained :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $obj = $c->stash->{rs}->find($id)
        or $c->detach('/page_error_404_not_found', []);
    $c->stash(obj => $obj);
}

sub edit :PathPart('') :Chained('item') :Args(0) {
    my ($self, $c) = @_;

    my $role = $c->stash->{obj};

    $c->stash->{body} = $role->body;
    $c->forward('/admin/fetch_contacts');
    $c->forward('/admin/stash_contacts_for_template', [
        \@{$role->get_extra_metadata('categories') || []},
    ]);
    $c->forward('/report/stash_category_groups', [ $c->stash->{contacts}, { combine_multiple => 1 } ]);

    return $self->form($c, $role);
}

sub form {
    my ($self, $c, $role) = @_;

    if ($c->get_param('delete_role')) {
        $role->delete;
        $c->forward('/admin/log_edit', [ $role->id, 'role', 'delete' ]);
        $c->response->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }

    my $perms = [];
    my $p = $c->cobrand->available_permissions;
    foreach my $group (sort keys %$p) {
        my $group_vals = $p->{$group};
        my @foo;
        foreach (sort keys %$group_vals) {
            push @foo, { value => $_, label => $group_vals->{$_} };
        }
        push @$perms, { group => $group, options => \@foo };
    }
    my $opts = {
        field_list => [
            '+permissions' => { options => $perms },
        ],
    };

    if (!$c->user->is_superuser && $c->user->from_body) {
        push @{$opts->{field_list}}, '+body', { inactive => 1 };
        $opts->{body_id} = $c->user->from_body->id;
    }

    my $action = $role->in_storage ? 'edit' : 'add';
    my $form = FixMyStreet::App::Form::Role->new(%$opts);
    $c->stash(template => 'admin/roles/form.html', form => $form);

    my %form_params;
    if ($action eq 'edit') {
        # Check which contacts should be used for this role's category restrictions.
        my @live_contacts = $c->stash->{live_contacts}->all;
        my @live_contact_ids = map { $_->id } @live_contacts;
        my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @live_contact_ids;

        $form_params{categories} = \@new_contact_ids;
    }

    $form->process(item => $role, params => $c->req->params, %form_params);
    return unless $form->validated;

    $c->forward('/admin/log_edit', [ $role->id, 'role', $action ]);
    $c->response->redirect($c->uri_for($self->action_for('index')));
}

1;
