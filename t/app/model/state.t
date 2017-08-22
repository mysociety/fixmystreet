use FixMyStreet::Test;
use Test::More;

my $rs = FixMyStreet::DB->resultset('State');
my $trans_rs = FixMyStreet::DB->resultset('Translation');

for (
    { label => 'in progress', lang => 'de' },
    { label => 'investigating', lang => 'fr' },
    { label => 'duplicate', lang => 'de' },
) {
    my $lang = $_->{lang};
    my $obj = $rs->find({ label => $_->{label} });
    $trans_rs->create({ tbl => 'state', col => 'name', object_id => $obj->id,
        lang => $lang, msgstr => "$lang $_->{label}" });
}

my $states = $rs->states;
my %states = map { $_->label => $_ } @$states;

subtest 'Open/closed database data is as expected' => sub {
    my $open = $rs->open;
    is @$open, 5;
    my $closed = $rs->closed;
    is @$closed, 5;
};

is $rs->display('investigating'), 'Investigating';
is $rs->display('bad'), 'bad';
is $rs->display('confirmed'), 'Open';
is $rs->display('closed'), 'Closed';
is $rs->display('fixed - council'), 'Fixed - Council';
is $rs->display('fixed - user'), 'Fixed - User';
is $rs->display('fixed'), 'Fixed';

subtest 'default name is untranslated' => sub {
    is $states{'in progress'}->name, 'In progress';
    is $states{'in progress'}->msgstr, 'In progress';
    is $states{'action scheduled'}->name, 'Action scheduled';
    is $states{'action scheduled'}->msgstr, 'Action scheduled';
};

subtest 'msgstr gets translated if available when the language changes' => sub {
    FixMyStreet::DB->schema->lang('de');
    is $states{'in progress'}->name, 'In progress';
    is $states{'in progress'}->msgstr, 'de in progress';
    is $states{'investigating'}->name, 'Investigating';
    is $states{'investigating'}->msgstr, 'Investigating';
    is $states{'unable to fix'}->name, 'No further action';
    is $states{'unable to fix'}->msgstr, 'No further action';
};

$rs->clear;

is_deeply [ sort FixMyStreet::DB::Result::Problem->open_states ],
    ['action scheduled', 'confirmed', 'in progress', 'investigating', 'planned'], 'open states okay';
is_deeply [ sort FixMyStreet::DB::Result::Problem->closed_states ],
    ['closed', 'duplicate', 'internal referral', 'not responsible', 'unable to fix'], 'closed states okay';
is_deeply [ sort FixMyStreet::DB::Result::Problem->fixed_states ],
    ['fixed', 'fixed - council', 'fixed - user'], 'fixed states okay';

done_testing();
