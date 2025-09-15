package FixMyStreet::App::Form::Waste::Garden::AboutYou::Bexley;

use HTML::FormHandler::Moose::Role;

with 'FixMyStreet::App::Form::Waste::AboutYou';

# Create a dedicated page for entering personal details
sub about_you {
    my %args = @_;

    return (
        fields => [ 'name', 'phone', 'email', $args{continue_field} ],
        title => 'About you',
        next => $args{next_page},
    );
}

# Remove name, phone, email from a given page setup
sub remove_about_you_fields {
    my %defaults = @_;
    my @fields = grep { $_ !~ /^(name|phone|email)$/ } @{ $defaults{fields} };
    $defaults{fields} = \@fields;
    return %defaults;
}

1;
