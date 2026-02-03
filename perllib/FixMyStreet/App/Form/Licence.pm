package FixMyStreet::App::Form::Licence;

use strict;
use warnings;

# Discover and load all form classes in FixMyStreet::App::Form::Licence::*
use Module::Pluggable
    sub_name    => '_forms',
    search_path => 'FixMyStreet::App::Form::Licence',
    except => qr/Base/,
    require     => 1;

my @ALL_FORM_CLASSES = __PACKAGE__->_forms;

# Build licence types from discovered form classes
sub licence_types {
    my $self = shift;
    my %types;
    for my $class (@ALL_FORM_CLASSES) {
        next unless $class->can('type') && $class->can('name');
        my $type = $class->type;
        $types{$type} = {
            class => $class,
            name  => $class->name,
        };
    }
    return \%types;
}

1;
