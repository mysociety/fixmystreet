package Dataset::UK::Stats19::Schema::Result::SpecialConditionsAtSite;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('special_conditions_at_site');

__PACKAGE__->subclass;

1;
