package Dataset::UK::Stats19::Schema::Result::TowingAndArticulation;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('towing_and_articulation');

__PACKAGE__->subclass;

1;
