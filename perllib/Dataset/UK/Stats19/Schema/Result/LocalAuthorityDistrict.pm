package Dataset::UK::Stats19::Schema::Result::LocalAuthorityDistrict;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('local_authority_district');

__PACKAGE__->subclass;

1;
