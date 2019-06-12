package FixMyStreet::App::Form::Widget::Field::CheckboxGroup;

use Moose::Role;
with 'HTML::FormHandler::Widget::Field::CheckboxGroup';
use namespace::autoclean;

has ul_class => ( is => 'ro' );

sub render_element {
    my ( $self, $result ) = @_;
    $result ||= $self->result;

    my $output = '<ul class="' . ($self->ul_class || '') . '">';
    foreach my $option ( @{ $self->{options} } ) {
        if ( my $label = $option->{group} ) {
            $label = $self->_localize( $label ) if $self->localize_labels;
            $output .= qq{\n<li>$label\n<ul class="no-margin no-bullets">};
            $output .= qq{\n<li>(<a href="#" data-select-all>} . _('all') . '</a> / ';
            $output .= '<a href="#" data-select-none>' . _('none') . '</a>)</li>';
            foreach my $group_opt ( @{ $option->{options} } ) {
                $output .= '<li>';
                $output .= $self->render_option( $group_opt, $result );
                $output .= "</li>\n";
            }
            $output .= qq{</ul>\n</li>};
        }
        else {
            $output .= '<li>' . $self->render_option( $option, $result ) . '</li>';
        }
    }
    $output .= '</ul>';
    $self->reset_options_index;
    return $output;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

FixMyStreet::App::Form::Widget::Field::CheckboxGroup - checkbox group field role

=head1 SYNOPSIS

Subclass of HTML::FormHandler::Widget::Field::CheckboxGroup, but printed
as a nested <ul>.

=head1 AUTHOR

FormHandler Contributors - see HTML::FormHandler

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Gerda Shank.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
