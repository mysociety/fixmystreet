package FixMyStreet::App::Controller::Test;
use Moose;
use namespace::autoclean;

use File::Basename;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Test - Catalyst Controller

=head1 DESCRIPTION

Test-helping Catalyst Controller.

=head1 METHODS

=over 4

=item auto

Makes sure this controller is only available when run in test.

=cut

sub auto : Private {
    my ($self, $c) = @_;
    $c->detach( '/page_error_404_not_found' ) unless FixMyStreet->test_mode;
    return 1;
}

=item setup

Sets up a particular browser test.

=cut

sub setup : Path('/_test/setup') : Args(1) {
    my ( $self, $c, $test ) = @_;
    if ($test eq 'regression-duplicate-hide') {
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        $problem->update({ category => 'Skips' });
        $c->response->body("OK");
    }
}

sub teardown : Path('/_test/teardown') : Args(1) {
    my ( $self, $c, $test ) = @_;
    if ($test eq 'regression-duplicate-hide') {
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        $problem->update({ category => 'Potholes' });
        $c->response->body("OK");
    }
}

__PACKAGE__->meta->make_immutable;

1;

