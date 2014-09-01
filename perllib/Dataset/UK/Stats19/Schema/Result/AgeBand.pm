package Dataset::UK::Stats19::Schema::Result::AgeBand;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('age_band');

__PACKAGE__->subclass;

1;
