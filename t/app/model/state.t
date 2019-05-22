use FixMyStreet::Test;
use FixMyStreet::Cobrand;

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
$trans_rs->create({ tbl => 'state', col => 'name', object_id => -1, lang => 'en-gb', msgstr => "Open Eng trans" });

$rs->clear;

my $states = $rs->states;
my %states = map { $_->label => $_ } @$states;

subtest 'Open/closed database data is as expected' => sub {
    my $open = $rs->open;
    is @$open, 5;
    my $closed = $rs->closed;
    is @$closed, 5;
};

# No language set at this point

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
    FixMyStreet::DB->schema->lang('en-gb');
    is $states{confirmed}->name, 'Open';
    is $states{confirmed}->msgstr, 'Open Eng trans';
    FixMyStreet::DB->schema->lang('de');
    is $states{'in progress'}->name, 'In progress';
    is $states{'in progress'}->msgstr, 'de in progress';
    is $states{'investigating'}->name, 'Investigating';
    is $states{'investigating'}->msgstr, 'Investigating';
    is $states{'unable to fix'}->name, 'No further action';
    is $states{'unable to fix'}->msgstr, 'No further action';
};

is_deeply [ sort FixMyStreet::DB::Result::Problem->open_states ],
    ['action scheduled', 'confirmed', 'in progress', 'investigating', 'planned'], 'open states okay';
is_deeply [ sort FixMyStreet::DB::Result::Problem->closed_states ],
    ['closed', 'duplicate', 'internal referral', 'not responsible', 'unable to fix'], 'closed states okay';
is_deeply [ sort FixMyStreet::DB::Result::Problem->fixed_states ],
    ['fixed', 'fixed - council', 'fixed - user'], 'fixed states okay';

FixMyStreet::override_config {
    LANGUAGES => [ 'en-gb,English,en_GB', 'sv,Swedish,sv_SE' ],
}, sub {
    subtest 'translation of open works both ways (file/db)' => sub {
        # Note at this point the states have been cached
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('default')->new;
        my $lang = $cobrand->set_lang_and_domain('sv', 1, FixMyStreet->path_to('locale')->stringify);
        is $lang, 'sv';
        is $rs->display('confirmed'), "Öppen";
        $lang = $cobrand->set_lang_and_domain('en-gb', 1, FixMyStreet->path_to('locale')->stringify);
        is $lang, 'en-gb';
        is $rs->display('confirmed'), "Open Eng trans";
    };
};

done_testing();
