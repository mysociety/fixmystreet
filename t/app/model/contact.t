use FixMyStreet::Test;

subtest 'add_note() updates note, editor and whenedited', sub {
    my $contact = FixMyStreet::DB->resultset('Contact')->new({ category => 'Pothole' });

    is $contact->note, undef, 'note starts as empty';
    is $contact->editor, undef, 'editor starts as empty';
    is $contact->whenedited, undef, 'whenedited starts as empty';

    $contact->add_note('Test note', 'Mr Tester');

    is $contact->note, 'Test note', 'note is correct';
    is $contact->editor, 'Mr Tester', 'editor is correct';
    isnt $contact->whenedited, undef, 'whenedited is set';
};

done_testing();
