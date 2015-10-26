package FixMyStreet::App::Controller::Static;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Static - Catalyst Controller

=head1 DESCRIPTION

Old static pages Catalyst Controller.

=head1 METHODS

=cut

sub about_redirect : Private {
    my ( $self, $c ) = @_;
    $c->res->redirect( $c->uri_for_action('/about/page', [ $c->action->name ] ));
}

sub faq : Global : Args(0) { $_[1]->forward('/about/page', ['faq']) }
sub privacy : Global : Args(0) { $_[1]->detach('about_redirect') }
sub fun : Global : Args(0) { $_[1]->detach('about_redirect') }
sub posters : Global : Args(0) { $_[1]->detach('about_redirect') }
sub iphone : Global : Args(0) { $_[1]->detach('about_redirect') }
sub council : Global : Args(0) { $_[1]->detach('about_redirect') }

sub unresponsive : Global : Args(0) {
    my ( $self, $c ) = @_;
    my $body = $c->stash->{body} = $c->model('DB::Body')->find({ id => $c->get_param('body') })
        or $c->detach( '/page_error_404_not_found' );

    $c->stash->{category} = $c->get_param('category');

    # If the whole body isn't set to refused, we need to check the contacts
    if (!$body->send_method || $body->send_method ne 'Refused') {
        my @contacts = $c->model('DB::Contact')->not_deleted->search( { body_id => $body->id } )->all;
        my $any_unresponsive = 0;
        foreach my $contact (@contacts) {
            $any_unresponsive = 1 if $contact->email =~ /^REFUSED$/i;
        }

        $c->detach( '/page_error_404_not_found' ) unless $any_unresponsive;
    }
}

__PACKAGE__->meta->make_immutable;

1;

