package FixMyStreet::App::Form::Field::JSON;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Hidden';

use JSON::MaybeXS;
use MIME::Base64;

has '+inflate_method' => ( default => sub { \&inflate_json } );
has '+deflate_method' => ( default => sub { \&deflate_json } );
has '+fif_from_value' => ( default => 1 );

sub inflate_json {
    my ($self, $value) = @_;
    return $value unless $value;
    $value = decode_json(decode_base64($value));
    return $value;
}

sub deflate_json {
    my ($self, $value) = @_;
    return $value unless $value;
    $value = encode_base64(encode_json($value), "");
    return $value;
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

FixMyStreet::App::Form::Field::JSON - used to store some data in a hidden field

=cut
