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
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste']);
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed@example.org' });
create_contact({ category => 'Request new container', email => 'request@example.org' },
    { code => 'Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 0, automated => 'hidden_field' },
    { code => 'Reason', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'General enquiry', email => 'general@example.org' },
    { code => 'Notes', description => 'Notes', required => 1, datatype => 'text' },
    { code => 'Source', required => 0, automated => 'hidden_field' },
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => { bartec => { peterborough => {
        url => 'http://example.org/',
        auth_url => 'http://auth.example.org/',
        sample_data => 1 } },
        waste => { peterborough => 1 }
    },
}, sub {
    $mech->host('peterborough.fixmystreet.com');
    subtest 'Missing address lookup' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->content_contains('can’t find your address');
    };
    subtest 'Address lookup' => sub {
        my $b = Test::MockModule->new('Integrations::Bartec');
        $b->mock('Authenticate', sub {
            { Token => { TokenString => "TOKEN" } }
        });
        $b->mock('Jobs_FeatureScheduleDates_Get', sub { [
            { JobID => 123, JobDescription => 'Empty Bin 240L Black', PreviousDate => '2021-08-01T11:11:11Z', NextDate => '2021-08-08T11:11:11Z', JobName => 'Black' },
            { JobID => 456, JobDescription => 'Empty Bin Recycling 240l', PreviousDate => '2021-08-05T10:10:10Z', NextDate => '2021-08-19T10:10:10Z', JobName => 'Recycling' },
        ] });
        $b->mock('Features_Schedules_Get', sub { [
            { JobName => 'Black', Feature => { FeatureType => { ID => 6533 } } },
            { JobName => 'Recycling', Feature => { FeatureType => { ID => 6843 } } },
        ] });
        $b->mock('ServiceRequests_Get', sub { [
            # No open requests at present
        ] });
        $b->mock('Premises_Events_Get', sub { [
            # No open events at present
        ] });
        $b->mock('Streets_Events_Get', sub { [
            # No open events at present
        ] });
        set_fixed_time('2021-08-06T10:00:00Z');
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->content_contains('1 Pope Way, Peterborough, PE1 3NA');
        $mech->submit_form_ok({ with_fields => { address => 'PE1 3NA:100090215480' } });
        $mech->content_contains('1 Pope Way, Peterborough');
        $mech->content_contains('Thursday, 5th August 2021');
        $mech->content_contains('Report a recycling collection as missed');
        set_fixed_time('2021-08-09T10:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_contains('Report a recycling collection as missed');
        set_fixed_time('2021-08-09T14:00:00Z');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('Report a recycling collection as missed');
    };
};

done_testing;
