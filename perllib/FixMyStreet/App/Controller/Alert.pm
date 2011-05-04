package FixMyStreet::App::Controller::Alert;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Alert - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 alert

Show the alerts page

=cut

sub index :Path('') :Args(0) {
    my ( $self, $c ) = @_;

#    my $q = shift;
#    my $cobrand = Page::get_cobrand($q);
#    my $error = shift;
#    my $errors = '';
#    $errors = '<ul class="error"><li>' . $error . '</li></ul>' if $error;
#
#    my $form_action = Cobrand::url(Page::get_cobrand($q), '/alert', $q);
#    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'alerts', $q);
#    my $cobrand_extra_data = Cobrand::extra_data($cobrand, $q);
#
#    $out .= $errors . qq(<form method="get" action="$form_action">);
#    $out .= $q->p($pc_label, '<input type="text" name="pc" value="' . $input_h{pc} . '">
#<input type="submit" value="' . $submit_text . '">');
#    $out .= $cobrand_form_elements;
#
#    my %vars = (error => $error, 
#                header => $header, 
#                intro => $intro, 
#                pc_label => $pc_label, 
#                form_action => $form_action, 
#                input_h => \%input_h, 
#                submit_text => $submit_text, 
#                cobrand_form_elements => $cobrand_form_elements, 
#                cobrand_extra_data => $cobrand_extra_data, 
#                url_home => Cobrand::url($cobrand, '/', $q));
#
#    my $cobrand_page = Page::template_include('alert-front-page', $q, Page::template_root($q), %vars);
#    $out = $cobrand_page if ($cobrand_page);
#
#    return $out if $q->referer() && $q->referer() =~ /fixmystreet\.com/;
#    my $recent_photos = Cobrand::recent_photos($cobrand, 10);
#    $out .= '<div id="alert_recent">' . $q->h2(_('Some photos of recent reports')) . $recent_photos . '</div>' if $recent_photos;
#
#    return $out;
}


=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
