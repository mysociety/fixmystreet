package FixMyStreet::App::Controller::Form;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub auto : Private {
    my ( $self, $c ) = @_;
    my $cobrand_check = $c->cobrand->feature( $self->feature );
    $c->detach( '/page_error_404_not_found' ) if !$cobrand_check;
    return 1;
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');
    $c->forward('form');
}

sub load_form {
    my ($self, $c, $previous_form) = @_;

    my $page;
    if ($previous_form) {
        $page = $previous_form->next;
    } else {
        $page = $c->forward('get_page');
    }

    my $form = $self->form_class->new(
        page_name => $page,
        csrf_token => $c->stash->{csrf_token},
        c => $c,
        previous_form => $previous_form,
        saved_data_encoded => $c->get_param('saved_data'),
        no_preload => 1,
    );

    if (!$form->has_current_page) {
        $c->detach('/page_error_400_bad_request', [ 'Bad request' ]);
    }

    $c->forward('requires_sign_in', [ $form ]);

    return $form;
}

sub requires_sign_in : Private {
    my ($self, $form) = @_;

    return 1;
}

sub form : Private {
    my ($self, $c) = @_;

    $c->forward('pre_form');

    my $form = $self->load_form($c);
    if ($c->get_param('process') && !$c->stash->{override_no_process}) {
        $c->forward('/auth/check_csrf_token');
        my @params = $form->get_params($c);
        $form->process(params => @params);
        if ($form->validated) {
            $form = $self->load_form($c, $form);
        }
    }

    $form->process unless $form->processed;

    $c->stash->{template} = $form->template || $self->index_template;
    $c->stash->{form} = $form;
}

sub pre_form : Private {
    return 1;
}

sub get_page : Private {
    my ($self, $c) = @_;

    my $goto = $c->get_param('goto') || '';
    my $process = $c->get_param('process') || '';
    $goto = 'intro' unless $goto || $process;
    if ($goto && $process) {
        $c->detach('/page_error_400_bad_request', [ 'Bad request' ]);
    }

    return $goto || $process;
}

__PACKAGE__->meta->make_immutable;

1;
