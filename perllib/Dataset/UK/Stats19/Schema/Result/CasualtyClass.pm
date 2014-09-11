package Dataset::UK::Stats19::Schema::Result::CasualtyClass;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('casualty_class');

__PACKAGE__->subclass;

1;
