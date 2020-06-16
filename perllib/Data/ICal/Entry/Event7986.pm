package Data::ICal::Entry::Event7986;

use parent 'Data::ICal::Entry::Event';

sub optional_unique_properties {
    return (
        shift->SUPER::optional_unique_properties,
        "color",
    );
}

sub optional_repeatable_properties {
    return (
        shift->SUPER::optional_repeatable_properties,
        "conference", "image",
    );
}

