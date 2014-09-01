package Dataset::UK::Stats19::Schema::Result::JunctionControl;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('junction_control');

__PACKAGE__->subclass;

1;
