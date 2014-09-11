package Dataset::UK::Stats19::Schema::Result::Highways;
use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("Core");
__PACKAGE__->table('highways');

__PACKAGE__->add_columns(
    id => {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    email => { },
    name => { },
);
__PACKAGE__->set_primary_key("id");

1;
