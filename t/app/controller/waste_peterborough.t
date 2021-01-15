use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2566, 'Peterborough Council');
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => [$group]);
    $contact->set_extra_metadata( waste_only => 1 );
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Recycling (green)', email => 'Bartec-254' }, 'Missed Collection');
create_contact({ category => 'All bins', email => 'Bartec-425' }, 'Request new container');
create_contact({ category => 'Lid', email => 'Bartec-236' }, 'Bin repairs');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => { bartec => { peterborough => {
        url => 'http://example.org/',
        auth_url => 'http://auth.example.org/',
        sample_data => 1 } },
        waste => { peterborough => 1 }
    },
}, sub {
    my $b = Test::MockModule->new('Integrations::Bartec');
    $b->mock('Authenticate', sub {
        { Token => { TokenString => "TOKEN" } }
    });
    $b->mock('Jobs_FeatureScheduleDates_Get', sub { [
        { JobID => 123, JobDescription => 'Empty Bin 240L Black', PreviousDate => '2021-08-01T11:11:11Z', NextDate => '2021-08-08T11:11:11Z', JobName => 'Black' },
        { JobID => 456, JobDescription => 'Empty Bin Recycling 240l', PreviousDate => '2021-08-05T10:10:10Z', NextDate => '2021-08-19T10:10:10Z', JobName => 'Recycling' },
    ] });
    $b->mock('Features_Schedules_Get', sub { [
        { JobName => 'Black', Feature => { FeatureType => { ID => 6533 } }, Frequency => 'Every two weeks' },
        { JobName => 'Recycling', Feature => { FeatureType => { ID => 6534 } } },
    ] });
    subtest 'Missing address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->content_contains('can’t find your address');
    };
    subtest 'Address lookup' => sub {
        set_fixed_time('2021-08-06T10:00:00Z');
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->content_contains('1 Pope Way, Peterborough, PE1 3NA');
        $mech->submit_form_ok({ with_fields => { address => 'PE1 3NA:100090215480' } });
        $mech->content_contains('1 Pope Way, Peterborough');
        $mech->content_contains('Every two weeks');
    };
};

done_testing;
