package Dataset::UK::Stats19::Schema::Result::DayOfWeek;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('day_of_week');

__PACKAGE__->subclass;

1;
