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
    } elsif ($test eq 'camden-report-ours') {
        my $body = FixMyStreet::DB->resultset("Body")->find({ name => 'Camden Borough Council' });
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        if ($problem->bodies_str != $body->id) {
            $problem->set_extra_metadata(original => {
                map { $_ => $problem->$_ } qw(bodies_str latitude longitude) });
            $problem->update({
                bodies_str => $body->id,
                latitude => 51.529432,
                longitude => -0.124514,
            });
        }
        $c->response->body("OK");
    } elsif ( $test eq 'regression-duplicate-stopper') {
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        $problem->update({ category => 'Flytipping' });
        my $category = FixMyStreet::DB->resultset('Contact')->search({
            category => 'Flytipping',
        })->first;
        $category->push_extra_fields({
            code => 'hazardous',
            datatype => 'singlevaluelist',
            description => 'Hazardous material',
            order => 0,
            variable => 'true',
            values => [
                { key => 'yes', name => 'Yes', disable => 1, disable_message => 'Please phone' },
                { key => 'no', name => 'No' },
            ],
        });
        $category->update;
        $c->response->body("OK");
    } elsif ($test eq 'simple-service-check') {
        my $problem = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        $c->response->body($problem->service);
    } elsif ($test eq 'oxfordshire-defect') {
        my $body = FixMyStreet::DB->resultset("Body")->find({ name => 'Oxfordshire County Council' });
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        # This setup appears to be called twice - https://github.com/cypress-io/cypress/issues/2777
        if ($problem->bodies_str != $body->id) {
            my $user = FixMyStreet::DB->resultset("User")->find({ email => 'inspector-instructor@example.org' });
            $user->update({ from_body => $body->id });
            $user->user_body_permissions->update({ body_id => $body->id });
            $problem->set_extra_metadata(original_body_id => $problem->bodies_str);
            $problem->update({ bodies_str => $body->id });
        }
        $c->response->body("OK");
    }
}

sub teardown : Path('/_test/teardown') : Args(1) {
    my ( $self, $c, $test ) = @_;
    if ($test eq 'regression-duplicate-hide') {
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        $problem->update({ category => 'Potholes' });
        $c->response->body("OK");
    } elsif ( $test eq 'regression-duplicate-stopper') {
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        $problem->update({ category => 'Potholes' });
        my $category = FixMyStreet::DB->resultset('Contact')->search({
            category => 'Flytipping',
        })->first;
        $category->remove_extra_field('hazardous');
        $category->update;
        $c->response->body("OK");
    } elsif ($test eq 'camden-report-ours') {
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        my $original = $problem->get_extra_metadata('original');
        foreach (keys %$original) {
            $problem->$_($original->{$_});
        }
        $problem->unset_extra_metadata('original');
        $problem->update;
        $c->response->body("OK");
    } elsif ($test eq 'oxfordshire-defect') {
        my $problem = FixMyStreet::DB->resultset("Problem")->find(1);
        my $user = FixMyStreet::DB->resultset("User")->find({ email => 'inspector-instructor@example.org' });
        my $body_id = $problem->get_extra_metadata('original_body_id');
        $user->update({ from_body => $body_id });
        $user->user_body_permissions->update({ body_id => $body_id });
        $problem->unset_extra_metadata('original_body_id');
        $problem->update({ bodies_str => $body_id });
        $c->response->body("OK");
    }
}

__PACKAGE__->meta->make_immutable;

1;

