package Dataset::UK::Stats19::Schema::Result::PointOfImpact1;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('point_of_impact_1');

__PACKAGE__->subclass;

1;
