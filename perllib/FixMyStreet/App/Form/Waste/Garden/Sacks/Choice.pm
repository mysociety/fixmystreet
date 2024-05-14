package FixMyStreet::App::Form::Waste::Garden::Sacks::Choice;

use utf8;
use HTML::FormHandler::Moose::Role;

has_field container_choice => (
    type => 'Select',
    label => 'Would you like to subscribe for bins or sacks?',
    required => 1,
    widget => 'RadioGroup',
);

my %sack_num = (
    sutton => 20,
    kingston => 10,
    merton => 25,
    brent => '',
);

sub options_container_choice {
    my $cobrand = $_[0]->{c}->cobrand->moniker;
    my $num = $sack_num{$cobrand};
    my @containers;
    if ($cobrand eq 'merton') {
        push @containers,
            { value => 'bin140', label => '140L bin', hint => 'About the same size as a small wheelie bin' },
            { value => 'bin240', label => '240L bin', hint => 'About the same size as a standard wheelie bin' };
    } else {
        push @containers,
            { value => 'bin', label => 'Bins', hint => '240L capacity, which is about the same size as a standard wheelie bin' };
    }
    push @containers,
        { value => 'sack', label => 'Sacks', hint => "Buy a roll of $num sacks and use them anytime within your subscription year" };
    return \@containers;
}

1;
