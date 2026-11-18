use FixMyStreet::Test;

my $body = FixMyStreet::DB->resultset('Body')->create({ name => 'Test Body' });
my $user = FixMyStreet::DB->resultset('User')->new({ name => 'Test User' });
my $staff = FixMyStreet::DB->resultset('User')->new({ name => 'Test User', from_body => $body->id });
my $super = FixMyStreet::DB->resultset('User')->new({ name => 'Test User', is_superuser => 1 });

my $comment_rs = FixMyStreet::DB->resultset('Comment');
my $comment = $comment_rs->new(
    {
        user => $super,
        problem_id   => 1,
        text         => '',
    }
);

is $comment->created,  undef, 'inflating null created ok';
is $comment->mark_fixed, 0, 'mark fixed default set';
is $comment->state, 'confirmed', 'state default is confirmed';
is $comment->name, 'an administrator';

$comment = $comment_rs->new({
    user => $user,
    problem_id => 1,
    text => '',
});
is $comment->name, 'Test User';

foreach my $test (
    { desc => 'Empty update', fields => { text => '' }, errors => {
        name => 'Please enter your name',
        update => 'Please enter a message',
    } },
    { desc => 'Too long, user',
        fields => { text => 'x' x 1751, name => 'Name', },
        errors => {
            update => 'Updates are limited to 1750 characters in length. Please shorten your update',
        }
    },
    { desc => 'Too long, staff',
        fields => {
            text => 'x' x 1751,
            user => $staff,
        },
        errors => {}
},
) {
    subtest $test->{desc} => sub {
        my $update = $comment_rs->new($test->{fields});
        is_deeply $update->check_for_errors, $test->{errors};
    };
};

done_testing();
