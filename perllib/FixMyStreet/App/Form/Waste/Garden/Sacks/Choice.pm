package FixMyStreet::App::Form::Waste::Garden::Sacks::Choice;

use utf8;
use HTML::FormHandler::Moose::Role;

# Used by Merton only, below, to default the container choice
use constant CONTAINER_GARDEN_BIN => 26;
use constant CONTAINER_GARDEN_BIN_140 => 27;
use constant CONTAINER_GARDEN_SACK => 28;

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

sub default_container_choice {
    my $self = shift;
    my $cobrand = $self->{c}->cobrand;
    if ($cobrand->moniker eq 'merton') {
        my $sub = $cobrand->garden_current_subscription;
        my $container = $sub->{garden_container} || 0;
        if ($container == CONTAINER_GARDEN_SACK) {
            return 'sack';
        } elsif ($container == CONTAINER_GARDEN_BIN_140) {
            return 'bin140';
        } elsif ($container == CONTAINER_GARDEN_BIN) {
            return 'bin240';
        }
    }
}

sub options_container_choice {
    my $cobrand = $_[0]->{c}->cobrand->moniker;
    my $num = $sack_num{$cobrand};
    my @containers;
    if ($cobrand eq 'merton') {
        push @containers,
            { value => 'bin140', label => '140L bin', hint => 'Smaller than a standard wheelie bin' },
            { value => 'bin240', label => '240L bin', hint => 'About the same size as a standard wheelie bin' };
    } else {
        push @containers,
            { value => 'bin', label => 'Bins', hint => '240L capacity' };
    }
    push @containers,
        { value => 'sack', label => 'Sacks', hint => "Buy a roll of $num sacks and use them anytime within your subscription year" };
    return \@containers;
}

# Things using this will always need customised bins_wanted

has_field bins_wanted => (
    type => 'Integer',
    build_label_method => sub {
        my $self = shift;
        my $choice = $self->form->saved_data->{container_choice} || '';
        my $max = $self->parent->{c}->stash->{garden_form_data}->{max_bins};
        if ($choice eq 'sack') {
            if ($self->form->with_bins_wanted) {
                return "Number of sack subscriptions (maximum $max)",
            } else {
                return "Number of sack subscriptions",
            }
        } else {
            return $self->form->bins_wanted_label_method($max);
        }
    },
    tags => { number => 1 },
    required => 1,
    range_start => 1,
);

1;
