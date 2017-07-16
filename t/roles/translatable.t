use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $body = FixMyStreet::DB->resultset("Body")->create({ name => 'Dunkirk' });

FixMyStreet::DB->resultset("Translation")->create({
    lang => "fr",
    tbl => "body",
    object_id => $body->id,
    col => "name",
    msgstr => "Dunkerque",
});

is $body->name, "Dunkirk";

FixMyStreet::DB->schema->lang("fr");
is $body->name, "Dunkerque";

FixMyStreet::DB->schema->lang("de");
is $body->name, "Dunkirk";

done_testing;
