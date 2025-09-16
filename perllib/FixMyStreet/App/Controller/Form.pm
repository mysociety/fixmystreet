=head1 NAME

FixMyStreet::App::Controller::Form

=head1 SYNOPSIS

The main controller for wizard multi-page forms. To use (see e.g. Claims or
Waste), you extend this controller, give it a feature attribute, and then
forward to C<form> once you've done any set up necessary in your own
controller.

=cut

package FixMyStreet::App::Controller::Form;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use mySociety::AuthToken;

=head2 auto

By default, this checks that the controller's feature is turned on in the
cobrand features, and sets up a unique ID for the form. A subclass will need to
call its C<SUPER::auto> as that will not happen automatically (unlike when a
controller is a subpath of another controller).

=cut

sub auto : Private {
    my ( $self, $c ) = @_;
    my $cobrand_check = $c->cobrand->feature( $self->feature );
    $c->detach( '/page_error_404_not_found' ) if !$cobrand_check;
    $c->session->{form_unique_id} ||= mySociety::AuthToken::random_token();
    return 1;
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');
    $c->forward('form');
}

=head2 load_form

This loads a page of the form (either in order to proess it, or to load the
next page if just processed). You can provide various options in the stash:

=over 4

=item * form_class - the form class to use (defaults to the controller's form_class if not set);

=item * page_list - any additional dynamic pages you want to include in the form;

=item * field_list - any additional dynamic fields you want to include in the form;

=back

=cut

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
        unique_id_session => $c->session->{form_unique_id},
        unique_id_form => $c->get_param('unique_id'),
    );

    if (!$form->has_current_page) {
        $c->stash->{internal_error} = "Form doesn't have current page";
        $c->detach('/page_error_400_bad_request', [ 'Bad request' ]);
    }

    $c->forward('requires_sign_in', [ $form ]);

    return $form;
}

sub requires_sign_in : Private {
    my ($self, $form) = @_;

    return 1;
}

=head2 form

The main controller. This will load a form, process the form for validation,
load the next page if it passes, and put the form on the stash.

Your subclass controller can set pre_form to do anything in advance. It can
set override_no_process in the stash to avoid processing (eg in claims, if
they've just clicked the map), override_no_next_form to not go to the next page
(eg in bulky, if they've clicked Add item).

It picks a template to use as the first of the stash's override_template, the
form's template, or the controller's index_template (unless we've just sent a
confirmation email).

=cut

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
        if (!$c->stash->{override_no_next_form}) {
            if ($form->validated) {
                $form = $self->load_form($c, $form);
            }
        }
    }

    $form->process unless $form->processed;

    # If the form has the already_submitted_error flag set, show the already_submitted template
    if ($form->already_submitted_error) {
        $c->stash->{template} = 'waste/already_submitted.html';
    } else {
        # If we have sent a confirmation email, that function will have
        # set a template that we need to show
        $c->stash->{template} = $c->stash->{override_template} || $form->template || $self->index_template
            unless $c->stash->{sent_confirmation_message};
    }
    $c->stash->{form} = $form;
}

=head2 label_for_field

This is used in order to reconstruct nice labels from the given option, in e.g. summary page.

=cut

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

=head2 get_page

The page to fetch when a form is submitted. We use a goto parameter if we want
to go to a particular page (and not process it) - for e.g. Change answer
buttons on a summary page, and a process parameter if we want to process a
particular page (this field is generally automatically shown/handled by the
form). By default, the first page used is the C<first_page> stash, or C<intro>.

=cut

sub get_page : Private {
    my ($self, $c) = @_;

    my $goto = $c->get_param('goto') || '';
    my $process = $c->get_param('process') || '';
    $goto = $self->first_page($c) unless $goto || $process;
    if ($goto && $process) {
        $c->stash->{internal_error} = "Both goto and process parameters set";
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
