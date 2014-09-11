package Dataset::UK::Stats19::Schema::Result::CasualtySeverity;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('casualty_severity');

__PACKAGE__->subclass;

1;
