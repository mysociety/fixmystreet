package FixMyStreet::Parishes;

# This could be called when a) an admin approves a new parish; b) from command line script
# etc. https://github.com/mysociety/societyworks/issues/4835

sub set_up_parish {
    my ($name, $area_id, $categories, $user) = @_;
    # TODO
    # Create a body
    # Assign that body to the correct area
    # Add the corect categories
    # Add to 'extra_parishes'
    # Make the user a staff user
}

1;
