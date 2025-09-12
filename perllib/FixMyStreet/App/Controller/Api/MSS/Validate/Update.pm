package FixMyStreet::App::Controller::Api::MSS::Validate::Update;

use Moose;
use namespace::autoclean;
use Types::Standard ':all';
use FixMyStreet::DB::Result::Problem;

has description => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has status => (
    is => 'ro',
    isa => Enum[ FixMyStreet::DB::Result::Problem->all_states ],
    required => 1,
);

has update_id => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has external_status_code => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has fixmystreet_id => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has updated_datetime => (
    is =>  'ro',
    isa => 'Str',
    required => 1,
);

around BUILDARGS => sub {
    my ($orig, $class, $args) = @_;

    die unless $args->{updated_datetime} =~ /\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d/;
    die unless $args->{update_id};

    return $class->$orig($args);
};

1;
