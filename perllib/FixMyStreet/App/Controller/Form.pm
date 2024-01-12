package FixMyStreet::App::Controller::Form;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use mySociety::AuthToken;

sub auto : Private {
    my ( $self, $c ) = @_;
    my $cobrand_check = $c->cobrand->feature( $self->feature );
    $c->detach( '/page_error_404_not_found' ) if !$cobrand_check;
    my $form_unique_id = $c->request->cookie('form_unique_id');
    if ($form_unique_id) {
        $c->stash->{form_unique_id} = $form_unique_id->value;
    } else {
        $c->stash->{form_unique_id} = mySociety::AuthToken::random_token();
        $c->response->cookies->{form_unique_id} = {
            value => $c->stash->{form_unique_id},
            expires => time() + 86400,
        };
    }
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

    my $form_class = $c->stash->{form_class} || $self->form_class;
    my $form = $form_class->new(
        page_list => $c->stash->{page_list} || [],
        $c->stash->{field_list} ? (field_list => $c->stash->{field_list}) : (),
        page_name => $page,
        csrf_token => $c->stash->{csrf_token},
        c => $c,
        previous_form => $previous_form,
        saved_data_encoded => $c->get_param('saved_data'),
        no_preload => 1,
        unique_id_session => $c->stash->{form_unique_id},
        unique_id_form => $c->get_param('unique_id'),
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

    $c->stash->{label_for_field} = \&label_for_field;
    $c->forward('pre_form');

    # XXX This double form load means double API calls in
    # Cobrand/Peterborough.pm, for example
    my $form = $self->load_form($c);
    if ($c->get_param('process') && !$c->stash->{override_no_process}) {
        # A claim form will quite possibly have people logging in part-way
        # through (to make a new report required for the claim), and this will
        # invalidate the token and cause the form to error. We already generate
        # another CSRF token with a random unique ID in the session, so there
        # is no need for this check as well.
        $c->forward('/auth/check_csrf_token')
            unless $self->feature eq "claims";
        my @params = $form->get_params($c);
        $form->process(params => @params);
        if ($form->validated) {
            $form = $self->load_form($c, $form);
        }
    }

    $form->process unless $form->processed;

    # If we have sent a confirmation email, that function will have
    # set a template that we need to show
    $c->stash->{template} = $c->stash->{override_template} || $form->template || $self->index_template
        unless $c->stash->{sent_confirmation_message};
    $c->stash->{form} = $form;
}

sub label_for_field {
    my ($form, $field, $key) = @_;
    my $fn = 'options_' . $field;
    my @options = $form->field($field)->options;
    @options = $form->$fn if !@options && $form->can($fn);
    foreach (@options) {
        return $_->{label} if $_->{value} eq $key;
    }
}

sub pre_form : Private {
    return 1;
}

sub get_page : Private {
    my ($self, $c) = @_;

    my $goto = $c->get_param('goto') || '';
    my $process = $c->get_param('process') || '';
    $goto = $self->first_page($c) unless $goto || $process;
    if ($goto && $process) {
        $c->detach('/page_error_400_bad_request', [ 'Bad request' ]);
    }

    return $goto || $process;
}

sub first_page {
    my ($self, $c) = @_;
    return $c->stash->{first_page} || 'intro';
}

__PACKAGE__->meta->make_immutable;

1;
