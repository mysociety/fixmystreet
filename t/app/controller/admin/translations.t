use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

$mech->log_in_ok( $superuser->email );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
}, sub {

my $body = $mech->create_body_ok(2650, 'Aberdeen City Council');
$mech->create_contact_ok( body_id => $body->id, category => 'Traffic lights', email => 'lights@example.com' );

subtest 'check no translations if one language' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');

    $mech->content_lacks( 'Translations' );

};

};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    LANGUAGES => [
        'en-gb,English,en_GB',
        'de,German,de_DE'
    ]
}, sub {

my $body = $mech->create_body_ok(2650, 'Aberdeen City Council');
$mech->create_contact_ok( body_id => $body->id, category => 'Traffic lights', email => 'lights@example.com' );

my $body2 = $mech->create_body_ok(2643, 'Arun District Council');

FixMyStreet::DB->resultset("Translation")->create({
    lang => "de",
    tbl => "body",
    object_id => $body2->id,
    col => "name",
    msgstr => "DE Arun",
});

subtest 'check translations if multiple languages' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');

    $mech->content_contains( 'Translations' );
};

subtest 'check add category with translation' => sub {
    $mech->get_ok('/admin/body/' . $body2->id);

    $mech->content_contains('DE Arun');

    $mech->submit_form_ok( { with_fields => {
        category => 'Potholes',
        translation_de => 'DE potholes',
        email => 'potholes',
    } } );

    # check that error page includes translations
    $mech->content_lacks('DE Arun');
    $mech->content_contains('DE potholes');

    $mech->submit_form_ok( { with_fields => {
        category => 'Potholes',
        translation_de => 'DE potholes',
        email => 'potholes@example.org',
        note => 'adding category with translation',
    } } );

    $mech->content_contains('DE Arun');
    $mech->content_lacks('DE potholes');

    $mech->get_ok('/admin/body/' . $body2->id . '/Potholes');

    $mech->content_contains( 'DE potholes' );
};

subtest 'check add category translation' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');

    $mech->content_lacks( 'DE Traffic lights' );

    $mech->submit_form_ok( { with_fields => {
        translation_de => 'DE Traffic lights',
        note => 'updating translation',
    } } );

    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');

    $mech->content_contains( 'DE Traffic lights' );
};

subtest 'check replace category translation' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');

    $mech->content_contains( 'DE Traffic lights' );

    $mech->submit_form_ok( { with_fields => {
        translation_de => 'German Traffic lights',
        note => 'updating translation',
    } } );

    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');

    $mech->content_lacks( 'DE Traffic lights' );
    $mech->content_contains( 'German Traffic lights' );
};

subtest 'delete category translation' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');
    $mech->content_contains( 'German Traffic lights' );

    $mech->submit_form_ok( { with_fields => {
        translation_de => '',
        note => 'updating translation',
    } } );

    $mech->get_ok('/admin/body/' . $body->id . '/Traffic%20lights');

    $mech->content_lacks( 'DE German Traffic lights' );
};

subtest 'check add body translation' => sub {
    $mech->get_ok('/admin/body/' . $body->id);

    $mech->content_lacks( 'DE Aberdeen' );

    $mech->submit_form_ok( { with_fields => {
        send_method => 'email',
        translation_de => 'DE Aberdeen',
    } } );

    $mech->content_contains( 'DE Aberdeen' );
};

subtest 'check replace body translation' => sub {
    $mech->get_ok('/admin/body/' . $body->id);

    $mech->content_contains( 'DE Aberdeen' );

    $mech->submit_form_ok( { with_fields => {
        send_method => 'email',
        translation_de => 'German Aberdeen',
    } } );

    $mech->content_lacks( 'DE Aberdeen' );
    $mech->content_contains( 'German Aberdeen' );
};

subtest 'delete body translation' => sub {
    $mech->get_ok('/admin/body/' . $body->id);
    $mech->content_contains( 'German Aberdeen' );

    $mech->submit_form_ok( { with_fields => {
        send_method => 'email',
        translation_de => '',
    } } );

    $mech->content_lacks( 'DE German Aberdeen' );
};

subtest 'check add body with translation' => sub {
    $mech->get_ok('/admin/bodies/');
    $mech->submit_form_ok( { with_fields => {
        area_ids => 2643,
        send_method => 'email',
        translation_de => 'DE A Body',
    } } );

    # check that error page includes translations
    $mech->content_contains( 'DE A Body' );

    $mech->submit_form_ok( { with_fields => {
        name => 'A body',
        area_ids => 2643,
        send_method => 'email',
        translation_de => 'DE A Body',
    } } );

    $mech->follow_link_ok({ text => 'A body' });
    $mech->content_contains( 'DE A Body' );
}
};

done_testing();
