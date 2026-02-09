package FixMyStreet::App::Form::Field::RmElement;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::RmElement';

around build_render_method => sub {
    my ($orig, $self) = (shift, shift);
    my $sub = $self->$orig(@_);
    return sub {
        my ($self, $result) = @_;
        my $output = $sub->($self, $result);
        $output =~ s/ btn//;
        return $output;
    };
};

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

FixMyStreet::App::Form::Field::RmElement - Subclass to not have 'btn' class

=cut
