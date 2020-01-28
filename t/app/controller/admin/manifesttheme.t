use FixMyStreet::TestMech;
use FixMyStreet::DB;

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

$mech->log_in_ok( $superuser->email );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'lincolnshire', 'fixmystreet' ],
}, sub {

ok $mech->host('lincolnshire.fixmystreet.com');

subtest "theme link on cobrand admin goes to create form if no theme exists" => sub {
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "no themes yet" );

    $mech->get_ok("/admin");
    $mech->follow_link_ok({ text => "Manifest Theme" });

    is $mech->res->previous->code, 302, "got 302 for redirect";
    is $mech->res->previous->base->path, "/admin/manifesttheme", "redirected from index";
    is $mech->uri->path, '/admin/manifesttheme/create', "redirected to create page";
};

subtest "name and short_name are required fields" => sub {
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "no themes yet" );

    $mech->get_ok("/admin/manifesttheme/create");
    $mech->content_lacks("Delete theme");

    $mech->submit_form_ok({});
    is $mech->uri->path, '/admin/manifesttheme/create', "stayed on create page";
    $mech->content_contains("field is required");
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "theme not created" );

    $mech->get_ok("/admin/manifesttheme/create");
    $mech->submit_form_ok({ with_fields => { short_name => "Lincs FMS" } });
    is $mech->uri->path, '/admin/manifesttheme/create', "stayed on create page";
    $mech->content_contains("field is required", "name is required");
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "theme not created" );

    $mech->get_ok("/admin/manifesttheme/create");
    $mech->submit_form_ok({ with_fields => { name => "Lincolnshire FixMyStreet" } });
    is $mech->uri->path, '/admin/manifesttheme/create', "stayed on create page";
    $mech->content_contains("field is required", "short_name is required");
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "theme not created" );
};

subtest "cobrand admin lets you create a new theme" => sub {
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "no themes yet" );

    $mech->get_ok("/admin/manifesttheme/create");
    $mech->content_lacks("Delete theme");

    my $fields = {
        name => "Lincolnshire FixMyStreet",
        short_name => "Lincs FMS",
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/manifesttheme/lincolnshire', "redirected to edit page";
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 1, "theme was created" );

    my $theme = FixMyStreet::DB->resultset('ManifestTheme')->find({ cobrand => 'lincolnshire' });
    is $theme->name, "Lincolnshire FixMyStreet";
    is $theme->short_name, "Lincs FMS";
    is $theme->background_colour, undef;

    my $log = $superuser->admin_logs->search({}, { order_by => { -desc => 'id' } })->first;
    is $log->object_id, $theme->id;
    is $log->action, "add";
    is $log->object_summary, "lincolnshire";
    is $log->link, "/admin/manifesttheme/lincolnshire";

    $fields = {
        background_colour => "#663399",
        theme_colour => "rgb(102, 51, 153)",
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    $theme->discard_changes;
    is $theme->background_colour, "#663399";
    is $theme->theme_colour, "rgb(102, 51, 153)";

    $log = $superuser->admin_logs->search({}, { order_by => { -desc => 'id' } })->first;
    is $log->object_id, $theme->id;
    is $log->action, "edit";
};

subtest "theme link on cobrand admin goes to edit form when theme exists" => sub {
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 1, "theme exists" );

    $mech->get_ok("/admin");
    $mech->follow_link_ok({ text => "Manifest Theme" });

    is $mech->res->previous->code, 302, "got 302 for redirect";
    is $mech->res->previous->base->path, "/admin/manifesttheme", "redirected from index";
    is $mech->uri->path, '/admin/manifesttheme/lincolnshire', "redirected to edit page";
};

subtest "create page on cobrand admin redirects to edit form when theme exists" => sub {
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 1, "theme exists" );

    $mech->get_ok("/admin/manifesttheme/create");

    is $mech->res->previous->code, 302, "got 302 for redirect";
    is $mech->uri->path, '/admin/manifesttheme/lincolnshire', "redirected to edit page";
};

subtest "can delete theme" => sub {
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 1, "theme exists" );

    $mech->get_ok("/admin/manifesttheme/lincolnshire");
    my $theme_id = FixMyStreet::DB->resultset('ManifestTheme')->find({ cobrand => 'lincolnshire' })->id;

    $mech->submit_form_ok({ button => 'delete_theme' });
    is $mech->uri->path, '/admin/manifesttheme/create', "redirected to create page";

    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "theme deleted" );

    my $log = $superuser->admin_logs->search({}, { order_by => { -desc => 'id' } })->first;
    is $log->object_id, $theme_id;
    is $log->action, "delete";
};

subtest "can't edit another cobrand's theme" => sub {
    FixMyStreet::DB->resultset('ManifestTheme')->create({
        cobrand => "tfl",
        name => "Transport for London Street Care",
        short_name => "TfL Street Care",
    });

    $mech->get("/admin/manifesttheme/tfl");
    ok !$mech->res->is_success(), "want a bad response";
    is $mech->res->code, 404, "got 404";
};

ok $mech->host('www.fixmystreet.com');

subtest "fms cobrand lets you view all manifest themes" => sub {
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 1, "theme already exists" );

    $mech->get_ok("/admin");
    $mech->follow_link_ok({ text => "Manifest Theme" });

    is $mech->uri->path, '/admin/manifesttheme', "taken to list page";

    $mech->content_contains("Transport for London Street Care");
    $mech->content_contains("TfL Street Care");

};

subtest "fms cobrand lets you edit a cobrand's manifest theme" => sub {
    $mech->get_ok("/admin/manifesttheme");
    $mech->follow_link_ok({ url => "manifesttheme/tfl" }) or diag $mech->content;

    my $fields = {
        name => "Transport for London Report It",
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/manifesttheme', "redirected back to list page";

    my $theme = FixMyStreet::DB->resultset('ManifestTheme')->find({ cobrand => 'tfl' });
    is $theme->name, "Transport for London Report It";

};

subtest "fms cobrand lets you create a new manifest theme" => sub {
    $mech->get_ok("/admin/manifesttheme");
    $mech->follow_link_ok({ text => "Create" });

    my $fields = {
        name => "FixMyStreet Pro",
        short_name => "FMS Pro",
        cobrand => "fixmystreet",
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/manifesttheme', "redirected to list page";

    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 2, "theme added" );
    my $theme = FixMyStreet::DB->resultset('ManifestTheme')->find({ cobrand => 'fixmystreet' });
    is $theme->name, "FixMyStreet Pro";
};

subtest "fms cobrand prevents you creating a duplicate theme" => sub {
    $mech->get_ok("/admin/manifesttheme");
    $mech->follow_link_ok({ text => "Create" });

    my $fields = {
        name => "FixMyStreet Pro",
        short_name => "FMS Pro",
        cobrand => "fixmystreet",
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/manifesttheme/create', "stayed on create form";

    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 2, "theme not added" );
};

subtest "fms cobrand prevents creating a duplicate by editing" => sub {
    $mech->get_ok("/admin/manifesttheme");
    $mech->follow_link_ok({ url => "manifesttheme/tfl" });

    my $fields = {
        cobrand => "fixmystreet",
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/manifesttheme/tfl', "stayed on edit page";
};

};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixamingata' ],
}, sub {

ok $mech->host("www.fixamingata.se"), "change host to FixaMinGata";

subtest "single cobrand behaves correctly" => sub {
    FixMyStreet::DB->resultset('ManifestTheme')->delete_all;
    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "themes all deleted" );

    $mech->get_ok("/admin/manifesttheme");
    is $mech->uri->path, '/admin/manifesttheme/create', "redirected to create page";

    my $fields = {
        name => "FixaMinGata Theme Test",
        short_name => "FixaMinGata Short Name",
        cobrand => "fixamingata",
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/manifesttheme/fixamingata', "redirected to edit form page";
    $mech->content_contains("FixaMinGata Theme Test");
    $mech->content_contains("FixaMinGata Short Name");

    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 1, "theme added" );
    my $theme = FixMyStreet::DB->resultset('ManifestTheme')->find({ cobrand => 'fixamingata' });
    is $theme->name, "FixaMinGata Theme Test";
};


};

done_testing();
