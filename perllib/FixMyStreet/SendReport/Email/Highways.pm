package FixMyStreet::SendReport::Email::Highways;

use Moo;
extends 'FixMyStreet::SendReport::Email::SingleBodyOnly';

has contact => (
    is => 'ro',
    default => 'Pothole'
);

1;
