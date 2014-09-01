package Dataset::UK::Stats19::Schema::LabelResult;

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("Core");
__PACKAGE__->table('Base'); # DUMMY
__PACKAGE__->add_columns(
    code => { },
    label => { },
);
__PACKAGE__->set_primary_key("code");

1;
