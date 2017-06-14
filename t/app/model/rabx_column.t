use FixMyStreet::Test;

use_ok "FixMyStreet::DB::RABXColumn";

# Test that the class names are correctly normalised
my @tests = (
    ["FixMyStreet::DB::Result::Token",     "Token"],
    ["FixMyStreet::App::Model::DB::Token", "Token"],
);

foreach my $test (@tests) {
    my ($input, $expected) = @$test;
    is(
        FixMyStreet::DB::RABXColumn::_get_class_identifier($input),
        $expected,
        "$input -> $expected"
    );
}

done_testing();
