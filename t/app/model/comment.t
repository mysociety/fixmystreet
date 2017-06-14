use FixMyStreet::Test;

my $comment_rs = FixMyStreet::DB->resultset('Comment');

my $comment = $comment_rs->new(
    {
        user_id      => 1,
        problem_id   => 1,
        text         => '',
        state        => 'confirmed',
        anonymous    => 0,
        mark_fixed   => 0,
        cobrand      => 'default',
        cobrand_data => '',
    }
);

is $comment->confirmed,  undef, 'inflating null confirmed ok';
is $comment->created,  undef, 'inflating null confirmed ok';
done_testing();
