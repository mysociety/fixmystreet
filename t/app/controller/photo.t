use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Tiny;
use File::Temp 'tempdir';

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");
ok $sample_file->exists, "sample file $sample_file exists";

my $body = $mech->create_body_ok(2527, 'Liverpool City Council');

subtest "Check multiple upload worked" => sub {
    $mech->get_ok('/around');

    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );

    # submit initial pc form
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
        PHOTO_STORAGE_BACKEND => 'FileSystem',
        PHOTO_STORAGE_OPTIONS => {
            UPLOAD_DIR => $UPLOAD_DIR,
        },
    }, sub {

        $mech->log_in_ok('test@example.com');


        # submit the main form
        # can't post_ok as we lose the Content_Type header
        # (TODO rewrite with HTTP::Request::Common and request_ok)
        $mech->get_ok('/report/new?lat=53.4031156&lon=-2.9840579');
        my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;

        $mech->post( '/report/new',
            Content_Type => 'form-data',
            Content =>
            {
            submit_problem => 1,
            token => $csrf,
            title         => 'Test',
            lat => 53.4031156, lon => -2.9840579, # in Liverpool
            pc            => 'L1 4LN',
            detail        => 'Detail',
            photo1         => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            photo2         => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            photo3         => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            name          => 'Bob Jones',
            may_show_name => '1',
            email         => 'test@example.com',
            phone         => '',
            category      => 'Street lighting',
            }
        );
        ok $mech->success, 'Made request with multiple photo upload';
        $mech->base_is('http://localhost/report/new');
        $mech->content_like(
            qr[(<img align="right" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg" alt="">\s*){3}],
            'Three uploaded pictures are all shown, safe');
        $mech->content_contains(
            'name="upload_fileid" value="74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg"',
            'Returned upload_fileid contains expected hash, 3 times');
        my $image_file = path($UPLOAD_DIR, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg');
        ok $image_file->exists, 'File uploaded to temp';

        $mech->submit_form_ok({ with_fields => { name => 'Bob Jones' } });
        ok $mech->success, 'Made request with multiple photo upload';
    };
};

subtest "Check photo uploading URL and endpoints work" => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );

    # submit initial pc form
    FixMyStreet::override_config {
        PHOTO_STORAGE_BACKEND => 'FileSystem',
        PHOTO_STORAGE_OPTIONS => {
            UPLOAD_DIR => $UPLOAD_DIR,
        },
    }, sub {
        $mech->post( '/photo/upload',
            Content_Type => 'form-data',
            Content => {
                photo1 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            },
        );
        ok $mech->success, 'Made request with multiple photo upload';
        is $mech->content, '{"id":"74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg"}';
        my $image_file = path($UPLOAD_DIR, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg');
        ok $image_file->exists, 'File uploaded to temp';

        my $p = FixMyStreet::DB->resultset("Problem")->first;

        foreach my $i (
          '/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
          '/photo/fulltemp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
          '/photo/' . $p->id . '.jpeg',
          '/photo/' . $p->id . '.full.jpeg') {
            $mech->get_ok($i);
            $image_file = FixMyStreet->path_to("web$i");
            ok -e $image_file, 'File uploaded to temp';
        }
        my $res = $mech->get('/photo/0.jpeg');
        is $res->code, 404, "got 404";
    };
};

subtest "Check no access to update photos on hidden reports" => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );

    my ($report) = $mech->create_problems_for_body(1, $body->id, 'Title');
    my $update = $mech->create_comment_for_problem($report, $report->user, $report->name, 'Text', $report->anonymous, 'confirmed', 'confirmed', { photo => $report->photo });

    FixMyStreet::override_config {
        PHOTO_STORAGE_BACKEND => 'FileSystem',
        PHOTO_STORAGE_OPTIONS => {
            UPLOAD_DIR => $UPLOAD_DIR,
        },
    }, sub {
        my $image_path = path('t/app/controller/sample.jpg');
        $image_path->copy( path($UPLOAD_DIR, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg') );

        $mech->get_ok('/photo/c/' . $update->id . '.0.jpeg');

        $report->update({ state => 'hidden' });
        $report->get_photoset->delete_cached(plus_updates => 1);

        my $res = $mech->get('/photo/c/' . $update->id . '.0.jpeg');
        is $res->code, 404, 'got 404';
    };
};

subtest 'non_public photos only viewable by correct people' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    path(FixMyStreet->path_to('web/photo'))->remove_tree({ keep_root => 1 });

    my ($report) = $mech->create_problems_for_body(1, $body->id, 'Title', {
        non_public => 1,
    });

    FixMyStreet::override_config {
        PHOTO_STORAGE_BACKEND => 'FileSystem',
        PHOTO_STORAGE_OPTIONS => {
            UPLOAD_DIR => $UPLOAD_DIR,
        },
    }, sub {
        my $image_path = path('t/app/controller/sample.jpg');
        $image_path->copy( path($UPLOAD_DIR, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg') );

        $mech->log_out_ok;
        my $i = '/photo/' . $report->id . '.0.jpeg';
        my $res = $mech->get($i);
        is $res->code, 404, 'got 404';

        $mech->log_in_ok('test@example.com');
        $i = '/photo/' . $report->id . '.0.jpeg';
        $mech->get_ok($i);
        my $image_file = FixMyStreet->path_to("web$i");
        ok !-e $image_file, 'File not cached out';

        my $user = $mech->log_in_ok('someoneelse@example.com');
        $i = '/photo/' . $report->id . '.0.jpeg';
        $res = $mech->get($i);
        is $res->code, 404, 'got 404';

        $user->update({ from_body => $body });
        $user->user_body_permissions->create({ body => $body, permission_type => 'report_inspect' });
        $i = '/photo/' . $report->id . '.0.jpeg';
        $mech->get_ok($i);

        $user->update({ from_body => undef, is_superuser => 1 });
        $i = '/photo/' . $report->id . '.0.jpeg';
        $mech->get_ok($i);
    };
};

done_testing();
