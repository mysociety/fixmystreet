use Path::Tiny;
use FixMyStreet::DB;
use FixMyStreet::TestMech;

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
};

subtest "cobrand admin lets you update an existing theme" => sub {
    $mech->get_ok("/admin/manifesttheme/lincolnshire");

    my $fields = {
        background_colour => "#663399",
        theme_colour => "rgb(102, 51, 153)",
    };
    $mech->submit_form_ok( { with_fields => $fields } );

    my $theme = FixMyStreet::DB->resultset('ManifestTheme')->find({ cobrand => 'lincolnshire' });
    is $theme->background_colour, "#663399";
    is $theme->theme_colour, "rgb(102, 51, 153)";

    my $log = $superuser->admin_logs->search({}, { order_by => { -desc => 'id' } })->first;
    is $log->object_id, $theme->id;
    is $log->action, "edit";
};

subtest "cobrand admin lets you add an icon to an existing theme" => sub {
    $mech->get_ok("/admin/manifesttheme/lincolnshire");

    my $sample_jpeg = path(__FILE__)->parent->parent->child("sample.jpg");
    ok $sample_jpeg->exists, "sample image $sample_jpeg exists";
    my $icon_filename = '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpg';

    $mech->post( '/admin/manifesttheme/lincolnshire',
        Content_Type => 'form-data',
        Content => {
            name => "Lincolnshire FixMyStreet",
            short_name => "Lincs FMS",
            background_colour => "#663399",
            theme_colour => "rgb(102, 51, 153)",
            icon => [ $sample_jpeg, undef, Content_Type => 'image/jpeg' ],
        },
    );
    ok $mech->success, 'Posted request successfully';

    is $mech->uri->path, '/admin/manifesttheme/lincolnshire', "redirected back to edit page";
    $mech->content_contains($icon_filename);
    $mech->content_contains("133x100");
    my $icon_dest = path(FixMyStreet->path_to('web/theme/lincolnshire/', $icon_filename));
    ok $icon_dest->exists, "Icon stored on disk";
};

subtest "cobrand admin lets you delete an icon from an existing theme" => sub {
    my $icon_filename = '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpg';
    my $icon_dest = path(FixMyStreet->path_to('web/theme/lincolnshire/', $icon_filename));
    ok $icon_dest->exists, "Icon exists on disk";

    $mech->get_ok("/admin/manifesttheme/lincolnshire");
    my $fields = {
        delete_icon => "/theme/lincolnshire/$icon_filename",
    };
    $mech->submit_form_ok( { with_fields => $fields } );

    is $mech->uri->path, '/admin/manifesttheme/lincolnshire', "redirected back to edit page";
    $mech->content_lacks($icon_filename);
    $mech->content_lacks("133x100");
    ok !$icon_dest->exists, "Icon removed from disk";
};

subtest "cobrand admin rejects non-images" => sub {
    $mech->get_ok("/admin/manifesttheme/lincolnshire");

    my $sample_pdf = path(__FILE__)->parent->parent->child("sample.pdf");
    ok $sample_pdf->exists, "sample image $sample_pdf exists";

    $mech->post( '/admin/manifesttheme/lincolnshire',
        Content_Type => 'form-data',
        Content => {
            name => "Lincolnshire FixMyStreet",
            short_name => "Lincs FMS",
            background_colour => "#663399",
            theme_colour => "rgb(102, 51, 153)",
            icon => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
        },
    );
    ok $mech->success, 'Posted request successfully';

    is $mech->uri->path, '/admin/manifesttheme/lincolnshire', "redirected back to edit page";
    $mech->content_lacks("90f7a64043fb458d58de1a0703a6355e2856b15e.pdf");
    $mech->content_contains("File type not recognised. Please upload an image.");
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

    my $theme_id = FixMyStreet::DB->resultset('ManifestTheme')->find({ cobrand => 'lincolnshire' })->id;

    # Add an icon so we can test it gets deleted when the theme is deleted
    my $sample_jpeg = path(__FILE__)->parent->parent->child("sample.jpg");
    ok $sample_jpeg->exists, "sample image $sample_jpeg exists";
    my $icon_filename = '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpg';

    $mech->post( '/admin/manifesttheme/lincolnshire',
        Content_Type => 'form-data',
        Content => {
            name => "Lincolnshire FixMyStreet",
            short_name => "Lincs FMS",
            background_colour => "#663399",
            theme_colour => "rgb(102, 51, 153)",
            icon => [ $sample_jpeg, undef, Content_Type => 'image/jpeg' ],
        },
    );
    ok $mech->success, 'Posted request successfully';

    is $mech->uri->path, '/admin/manifesttheme/lincolnshire', "redirected back to edit page";
    my $icon_dest = path(FixMyStreet->path_to('web/theme/lincolnshire/', $icon_filename));
    ok $icon_dest->exists, "Icon stored on disk";

    $mech->submit_form_ok({ button => 'delete_theme' });
    is $mech->uri->path, '/admin/manifesttheme/create', "redirected to create page";

    is( FixMyStreet::DB->resultset('ManifestTheme')->count, 0, "theme deleted" );
    ok !$icon_dest->exists, "Icon removed from disk";

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
