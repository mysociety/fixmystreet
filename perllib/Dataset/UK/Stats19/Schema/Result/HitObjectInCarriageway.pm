package Dataset::UK::Stats19::Schema::Result::HitObjectInCarriageway;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('hit_object_in_carriageway');

__PACKAGE__->subclass;

1;
