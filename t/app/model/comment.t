use FixMyStreet::Test;

my $user = FixMyStreet::DB->resultset('User')->new({ name => 'Test User', is_superuser => 1 });

my $comment_rs = FixMyStreet::DB->resultset('Comment');
my $comment = $comment_rs->new(
    {
        user => $user,
        problem_id   => 1,
        text         => '',
    }
);

is $comment->created,  undef, 'inflating null created ok';
is $comment->mark_fixed, 0, 'mark fixed default set';
is $comment->state, 'confirmed', 'state default is confirmed';
is $comment->name, 'an administrator';

$user->is_superuser(0);
$comment = $comment_rs->new({
    user => $user,
    problem_id => 1,
    text => '',
});
is $comment->name, 'Test User';

done_testing();
