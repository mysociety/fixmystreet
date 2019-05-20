use strict;
use warnings;
use v5.14;
use utf8;

use FixMyStreet::DB;

package FixMyStreet::DB::Factories;

use Path::Tiny;
my $db;
my $opt;

END {
    if ($db) {
        $opt->commit ? $db->txn_commit : $db->txn_rollback;
    }
}
sub setup {
    my $cls = shift;

    $opt = shift;
    $db = FixMyStreet::DB->schema->storage;
    $db->txn_begin;
    if (!$opt->commit) {
        say "NOT COMMITTING TO DATABASE";
    }

    if ($opt->empty) {
        path(FixMyStreet->path_to('web/photo'))->remove_tree({ keep_root => 1 });
        $db->dbh->do(q{
DO
$func$
BEGIN
    EXECUTE
    (SELECT 'TRUNCATE TABLE ' || string_agg(quote_ident(tablename), ', ') || ' RESTART IDENTITY CASCADE '
        FROM pg_tables WHERE schemaname='public');
END
$func$;
}) or die $!;
        $db->dbh->do( scalar FixMyStreet->path_to('db/fixture.sql')->slurp ) or die $!;
        $db->dbh->do( scalar FixMyStreet->path_to('db/generate_secret.sql')->slurp ) or die $!;
        say "Emptied database";
    }
}

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
use Path::Tiny;
use DateTime::Format::Pg;
use FixMyStreet;
use FixMyStreet::App::Model::PhotoSet;

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

sub data {
    my $self = shift;

    my %titles = (
        'Abandoned vehicles' => ['Car on pavement, has been there for months', 'Silver car outside house, never used'],
        'Bus stops' => ['Bus stop sign wonky', 'Information board broken'],
        'Dog fouling' => ['Bad dog fouling in alley way', 'Inconsiderate dog owner' ],
        'Flyposting' => ['Fence by road covered in posters', 'Under the bridge is a poster haven'],
        'Flytipping' => ['Flytipping on country lane', 'Ten bags of rubbish'],
        'Footpath/bridleway away from road' => ['Vehicle blocking footpath'],
        'Graffiti' => ['Graffiti', 'Graffiti', 'Offensive graffiti', 'Graffiti on the bridge', 'Remove graffiti'],
        'Parks/landscapes' => ['Full litter bins', 'Allotment gate needs repair'],
        'Pavements' => ['Hedge encroaching pavement', 'Many cracked slabs on street corner'],
        'Potholes' => ['Deep pothole', 'Small pothole', 'Pothole in cycle lane', 'Pothole on busy pavement', 'Large pothole', 'Sinking manhole'],
        'Public toilets' => ['Door will not open'],
        'Roads/highways' => ['Restricted sight line by zig-zag lines', 'Missing lane markings'],
        'Road traffic signs' => ['Bent sign', 'Zebra crossing', 'Bollard missing'],
        'Rubbish (refuse and recycling)' => ['Missing bin', 'Bags left uncollected'],
        'Street cleaning' => ['Two abandoned trollies', 'Yet more litter'],
        'Street lighting' => ['Faulty light', 'Street light not working', 'Lights out in tunnel', 'Light not coming on', 'Light not going off'],
        'Street nameplates' => ['Broken nameplate', 'Missing nameplate'],
        'Traffic lights' => ['Out of sync lights', 'Always on green', 'Broken light'],
        'Trees' => ['Young tree damaged', 'Tree looks dangerous in wind'],
        'Other' => ['Loose drain cover', 'Flytipping on country lane', 'Vehicle blocking footpath', 'Hedge encroaching pavement', 'Full litter bins'],
    );
    my %photos = (
        'Potholes' => [ '33717571655_46dfc6f65f_z.jpg', '37855543925_9dbbbecf41_z.jpg', '19119222668_a3c866d7c8_z.jpg', '12049724866_404b066875_z.jpg', '3705226606_eac71cf195_z.jpg', '6304445383_bd216ca892_z.jpg' ],
        'Street lighting' => ['38110448864_fd71227247_z.jpg', '27050321819_ac123400eb_z.jpg', '35732107202_b790c61f63_z.jpg', '31889115854_01cdf38b0d_z.jpg', undef ],
        'Graffiti' => ['12205918375_f37f0b27a9_z.jpg', '8895442578_376a9b0be0_z.jpg', '22998854352_17555b7536_z.jpg', '22593395257_3d48f23bfa_z.jpg', '20515339175_f4ed9fc1d9_z.jpg' ],
        'Other' => ['14347396807_20737504f7_z.jpg', '14792525771_167bc20e3d_z.jpg', undef, '36296226976_a83a118ff8_z.jpg', '23222004240_273977b2b2_z.jpg'],
    );
    my %descriptions = (
        'Potholes' => [
            '6” deep pothole in the very centre of the Bristol road; cars are swerving to avoid it. Please treat this as a matter of urgency.',
            'It’s small but it’s a trip hazard. Right where people cross over to get into the school or church. About 3” across but will become larger if not attended to.',
            'Just went over my handlebars as I didn’t see this pothole on Banbury road, just before the traffic lights. Dread to think what might have happened if the traffic had been busier.',
            'I work in the cafe at 34 Clarington Avenue and we’ve had four people come in having tripped over in the last seven days. The pothole’s right outside the key-cutting shop, just near the alleyway.',
            'This has been here, next to the side of the road, for a month',
            'A manhole on the junction of Etherington Road is sinking into the road surface. Not only is it an accident waiting to happen but it’s making a terrible noise every time a car passes over it.',
        ],
        'Street lighting' => [
            'I saw a workman attempting to fix this streetlight over a week ago, and ever since then it’s come on in the daytime and gone off as soon as it gets dark. Come and sort it out please!',
            'Every Tuesday night I have to walk across the carpark outside the station at around 9pm. Not a problem in summer but now the nights are drawing in I feel very unsafe. Please get the streetlight by the exit fixed as I’m sure I can’t be the only woman feeling vulnerable.',
            'My toddler is too scared to go in now, as soon as you’re more than a few paces in it’s absolutely pitch black with no hope of seeing any puddles or worse on the floor. I think this needs seeing to as a priority. Thank you.',
            'I think the lights in the multi storey carpark are motion sensitive but I’ve actually never seen them come on. Maybe the bulb needs replacing??',
            'This streetlight is right outside my bedroom window. It is on 24 hours a day, even in blazing sunlight. Apart from the fact that it’s a waste of electricity, it makes my bedroom feel like an interrogation chamber. Please come and fix it.',
        ],
        'Graffiti' => [
            'Someone has scrawled a really offensive piece of graffiti (are they called ‘tags’??) on the side of the town hall. You might want to see about getting it cleaned off. Wouldn’t want my own children to see that, I’m sure others feel the same.',
            'Can’t see the timetable at the bus shelter cos some idiot’s covered it all in red spray paint. Honestly. Kids of today.',
            'Not gonna write down what it depicts cos I suspect that’d get caught in your profanity filter lol. But please do come and paint over this monstrosity before it causes an accident.',
            'That same guy that’s graffitied all over town has gone and done the same on the passenger bridge over the tracks, you can see it as you come into the station. Ugly bit of garbage graffiti. Bit of a poor first impression for the town eh.',
            'What’s the procedure for requesting a bit of graffiti be removed? There’s been a huge scrawl on the wall outside the club for months. Nice sentiment maybe but really brings the tone of the area down.',
        ],
        'Other' => [
            'Surprised me so much when I crossed the road I nearly took a tumble! Glad I didn’t fall in, this really needs securing now.',
            'Some unmentionable has driven down Larker’s Lane and left a huge heap of old rubbish on the verge. Talk about ruining the view! Such a beautiful spot and these lowlifes come and dump their junk. Probably trying to avoid paying the tip.',
            'Well someone on foot can just about squeeze through but good luck if you’ve got a pushchair or god forbid a wheelchair. Think someone’s abandoned this car; it hasn’t moved in weeks.',
            'Awful trying to walk past after a rain shower, well any time really.',
            'I think these need seeing to more frequently, they’re always full to overflowing by midday.',
        ],
    );

    return {
        titles => \%titles,
        descriptions => \%descriptions,
        photos => \%photos,
    };
}

sub create_problem {
    my $self = shift;
    my $params = shift;

    my $data = $self->data;
    my $category = $params->{category};
    my $inaccurate_km = 0.01;

    my $titles = $data->{titles}{$category};
    my $descs = $data->{descriptions}{$category};
    my $rand = int(rand(@$titles));

    my $photo;
    if (my $file = $data->{photos}{$category}->[$rand]) {
        my $files = [ $file ];
        if ($category eq 'Graffiti') {
            push @$files, $data->{photos}{$category}->[int(rand(@$titles))];
        }
        $files = [ map { path(FixMyStreet->path_to("t/images/$_"))->slurp_raw } @$files ];
        my $photoset = FixMyStreet::App::Model::PhotoSet->new({
            data_items => $files,
        });
        $photo = $photoset->data;
    }

    $params->{latitude} += rand(2 * $inaccurate_km) - $inaccurate_km;
    $params->{longitude} += rand(3 * $inaccurate_km) - 1.5 * $inaccurate_km,
    $params->{title} ||= $titles->[$rand];
    $params->{detail} ||= $descs->[$rand] || 'Please deal with this issue, thank you.';
    $params->{photo_id} = $photo;
    $params->{confirmed} = DateTime::Format::Pg->format_datetime($params->{confirmed});
    return $self->create($params);
}

#######################

package FixMyStreet::DB::Factory::Body;

use parent -norequire, "FixMyStreet::DB::Factory::Base";
use FixMyStreet::MapIt;

__PACKAGE__->resultset(FixMyStreet::DB->resultset("Body"));

__PACKAGE__->exclude(['area_id', 'categories']);

__PACKAGE__->fields({
    name => __PACKAGE__->callback(sub {
        my $area_id = shift->get('area_id');
        my $area = FixMyStreet::MapIt::call('area', $area_id);
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

use parent -norequire, "FixMyStreet::DB::Factory::Base";

__PACKAGE__->resultset(FixMyStreet::DB->resultset("Contact"));

__PACKAGE__->fields({
    body_id => __PACKAGE__->callback(sub {
        my $fields = shift;
        return $fields->get('body')->id if $fields->get('body');
    }),
    category => 'Other',
    email => __PACKAGE__->callback(sub {
        my $category = shift->get('category');
        (my $email = lc $category) =~ s/ /-/g;
        $email . '@example.org';
    }),
    state => 'confirmed',
    editor => 'Factory',
    whenedited => \'current_timestamp',
    note => 'Created by factory',
});

sub key_field { 'id' }

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
