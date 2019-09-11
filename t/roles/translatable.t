use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $body = FixMyStreet::DB->resultset("Body")->create({ name => 'Dunkirk' });
my $contact = $mech->create_contact_ok(
    body => $body,
    email => 'potholes@dunkirk',
    category => 'Potholes'
);

FixMyStreet::DB->resultset("Translation")->create({
    lang => "fr",
    tbl => "body",
    object_id => $body->id,
    col => "name",
    msgstr => "Dunkerque",
});

FixMyStreet::DB->resultset("Translation")->create({
    lang => "de",
    tbl => "contact",
    object_id => $contact->id,
    col => "category",
    msgstr => "Schlaglöcher",
});

FixMyStreet::DB->resultset("Translation")->create({
    lang => "nb",
    tbl => "contact",
    object_id => $contact->id,
    col => "category",
    msgstr => "Hull i veien",
});

my ($problem) = $mech->create_problems_for_body(1, $body->id, "Title", {
    whensent => \'current_timestamp',
    category => 'Potholes',
});

is $body->name, "Dunkirk";
is $contact->category_display, "Potholes";
is $problem->category_display, "Potholes";

# Multiple LANGUAGES so translation code is called
FixMyStreet::override_config {
    LANGUAGES => [ 'en-gb,English,en_GB', 'de,German,de_DE' ]
}, sub {
    FixMyStreet::DB->schema->lang("fr");
    is $body->name, "Dunkerque";
    is $contact->category_display, "Potholes";
    is $problem->category_display, "Potholes";

    FixMyStreet::DB->schema->lang("de");
    is $body->name, "Dunkirk";
    is $contact->category_display, "Schlaglöcher";
    is $problem->category_display, "Schlaglöcher";

    is $contact->translation_for('category', 'de')->msgstr, "Schlaglöcher";
    is $body->translation_for('name', 'fr')->msgstr, "Dunkerque";

    ok $body->add_translation_for('name', 'es', 'Dunkerque');

    FixMyStreet::DB->schema->lang("es");
    is $body->name, "Dunkerque";

    is $body->translation_for('name')->count, 2;
};

FixMyStreet::override_config {
    LANGUAGES => [ 'en-gb,English,en_GB', 'nb,Norwegian,nb_NO' ],
    ALLOWED_COBRANDS => [ 'fiksgatami' ],
}, sub {
    $mech->get_ok($problem->url);
    $mech->content_contains('Hull i veien');
};

subtest 'Check display_name override' => sub {
    $contact->set_extra_metadata( display_name => 'Override name' );
    $contact->update;
    is $contact->category_display, "Override name";
    is $problem->category_display, "Override name";
};

done_testing;
