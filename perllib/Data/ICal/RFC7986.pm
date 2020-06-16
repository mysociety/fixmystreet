package Data::ICal::RFC7986;

use parent 'Data::ICal';

sub optional_unique_properties {
    qw( calscale method
		uid last-modified url refresh-interval source color
	);
}

# name/description are only repeatable to provide
# translations with language param
sub optional_repeatable_properties {
	qw( name description categories image );
}

1;
