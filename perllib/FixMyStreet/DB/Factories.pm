use FixMyStreet::DB;

package FixMyStreet::DB::Factory::Base;

use parent "DBIx::Class::Factory";

sub find_or_create {
    my ($class, $fields) = @_;
    my $key_field = $class->key_field;
    my $id = $class->get_fields($fields)->{$key_field};
    my $rs = $class->_class_data->{resultset};
    my $obj = $rs->find({ $key_field => $id });
    return $obj if $obj;
    return $class->create($fields);
}

#######################

package FixMyStreet::DB::Factory::Problem;

use parent "DBIx::Class::Factory";

__PACKAGE__->resultset(FixMyStreet::DB->resultset("Problem"));

__PACKAGE__->exclude(['body', 'photo_id']);

__PACKAGE__->fields({
    postcode => '',
    title => __PACKAGE__->seq(sub { 'Title #' . (shift()+1) }),
    detail => __PACKAGE__->seq(sub { 'Detail #' . (shift()+1) }),
    name => __PACKAGE__->callback(sub { shift->get('user')->name }),
    bodies_str => __PACKAGE__->callback(sub { shift->get('body')->id }),
    photo => __PACKAGE__->callback(sub { shift->get('photo_id') }),
    confirmed => \'current_timestamp',
    whensent => \'current_timestamp',
    state => 'confirmed',
    cobrand => 'default',
    latitude => 0,
    longitude => 0,
    areas => '',
    used_map => 't',
    anonymous => 'f',
    category => 'Other',
});

#######################

package FixMyStreet::DB::Factory::Body;

use parent -norequire, "FixMyStreet::DB::Factory::Base";
use mySociety::MaPit;

__PACKAGE__->resultset(FixMyStreet::DB->resultset("Body"));

__PACKAGE__->exclude(['area_id', 'categories']);

__PACKAGE__->fields({
    name => __PACKAGE__->callback(sub {
        my $area_id = shift->get('area_id');
        my $area = mySociety::MaPit::call('area', $area_id);
        $area->{name};
    }),
    body_areas => __PACKAGE__->callback(sub {
        my $area_id = shift->get('area_id');
        [ { area_id => $area_id } ]
    }),
    contacts => __PACKAGE__->callback(sub {
        my $categories = shift->get('categories');
        push @$categories, 'Other' unless @$categories;
        [ map { FixMyStreet::DB::Factory::Contact->get_fields({ category => $_ }) } @$categories ];
    }),
});

sub key_field { 'id' }

#######################

package FixMyStreet::DB::Factory::Contact;

use parent "DBIx::Class::Factory";

__PACKAGE__->resultset(FixMyStreet::DB->resultset("Contact"));

__PACKAGE__->fields({
    body_id => __PACKAGE__->callback(sub {
        my $fields = shift;
        return $fields->get('body')->id if $fields->get('body');
    }),
    category => 'Other',
    email => __PACKAGE__->callback(sub {
        my $category = shift->get('category');
        (my $email = lc $_) =~ s/ /-/g;
        lc $category . '@example.org';
    }),
    state => 'confirmed',
    editor => 'Factory',
    whenedited => \'current_timestamp',
    note => 'Created by factory',
});

#######################

package FixMyStreet::DB::Factory::ResponseTemplate;

use parent -norequire, "FixMyStreet::DB::Factory::Base";

__PACKAGE__->resultset(FixMyStreet::DB->resultset("ResponseTemplate"));

__PACKAGE__->fields({
    text => __PACKAGE__->seq(sub { 'Template text #' . (shift()+1) }),
});

#######################

package FixMyStreet::DB::Factory::ResponsePriority;

use parent "DBIx::Class::Factory";

__PACKAGE__->resultset(FixMyStreet::DB->resultset("ResponsePriority"));

__PACKAGE__->fields({
    name => __PACKAGE__->seq(sub { 'Priority ' . (shift()+1) }),
    description => __PACKAGE__->seq(sub { 'Description #' . (shift()+1) }),
});

#######################

package FixMyStreet::DB::Factory::Comment;

use parent "DBIx::Class::Factory";

__PACKAGE__->resultset(FixMyStreet::DB->resultset("Comment"));

__PACKAGE__->fields({
    anonymous => 'f',
    name => __PACKAGE__->callback(sub { shift->get('user')->name }),
    text => __PACKAGE__->seq(sub { 'Comment #' . (shift()+1) }),
    confirmed => \'current_timestamp',
    state => 'confirmed',
    cobrand => 'default',
    mark_fixed => 0,
});

#######################

package FixMyStreet::DB::Factory::User;

use parent -norequire, "FixMyStreet::DB::Factory::Base";

__PACKAGE__->resultset(FixMyStreet::DB->resultset("User"));

__PACKAGE__->exclude(['body', 'permissions']);

__PACKAGE__->fields({
    name => 'User',
    email => 'user@example.org',
    password => 'password',
    from_body => __PACKAGE__->callback(sub {
        my $fields = shift;
        if (my $body = $fields->get('body')) {
            return $body->id;
        }
    }),
    user_body_permissions => __PACKAGE__->callback(sub {
        my $fields = shift;
        my $body = $fields->get('body');
        my $permissions = $fields->get('permissions');
        [ map { { body_id => $body->id, permission_type => $_ } } @$permissions ];
    }),
});

sub key_field { 'email' }

1;
