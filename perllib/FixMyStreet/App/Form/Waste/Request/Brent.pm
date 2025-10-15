package FixMyStreet::App::Form::Waste::Request::Brent;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';
use Readonly;

Readonly::Scalar my $CONTAINER_GREY_BIN => 16;
Readonly::Scalar my $CONTAINER_BLUE_BIN => 6;
Readonly::Scalar my $CONTAINER_CLEAR_SACK => 8;
Readonly::Scalar my $CONTAINER_FOOD_CADDY => 11;
Readonly::Scalar my $CONTAINER_GREEN_BIN => 13;
Readonly::Scalar my $CONTAINER_BLUE_SACK => 46;

my %new_build_ordered_months = (
    $CONTAINER_FOOD_CADDY => 2,
    $CONTAINER_BLUE_BIN => 6,
    $CONTAINER_BLUE_SACK => 2,
);
my %ordered_months = (
    $CONTAINER_GREEN_BIN => 6,
    $CONTAINER_FOOD_CADDY => 3,
    $CONTAINER_BLUE_BIN => 6,
    $CONTAINER_BLUE_SACK => 3,
);
my %refusal_contamination_months = (
    $CONTAINER_FOOD_CADDY => 3,
    $CONTAINER_BLUE_BIN => 3,
    $CONTAINER_BLUE_SACK => 3,
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    # Look up any cost here, once we have all the data from previous steps
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->{c};

        my $choice = $data->{"container-choice"};
        my $how_long = $data->{how_long_lived} || '';
        my $ordered = $data->{ordered_previously};

        # We only ask for immediate payment if it's not a referral
        if (!FixMyStreet::Cobrand::Brent::request_referral($choice, $data)) {
            my ($cost) = $c->cobrand->request_cost($choice);
            $data->{payment} = $cost if $cost;
        }
        return {};
    },
    next => 'summary',
);

has_page refuse_request_intro => (
    intro => 'refuse_call_us.html',
    fields => ['continue_request_container'],
    next => 'request_refuse_container',
);

has_page request_extra_refusal => (
    fields => [],
    template => 'waste/refuse_extra_container.html',
);

has_page replacement => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        my $reason = $data->{request_reason};

        return 'about_you' if $choice == $CONTAINER_CLEAR_SACK;
        return 'how_long_lived' if $reason eq 'new_build';
        return 'request_extra_refusal' if $reason eq 'extra' && $data->{ordered_previously};
        # return 'request_extra_refusal' if $reason eq 'extra' && $data->{contamination_reports} >= 3;
        return 'about_you';
    },
);

has_field request_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    build_label_method => sub {
        my $self = shift;
        my $choice = $self->parent->saved_data->{'container-choice'};
        return 'Why do you need more sacks?' if $choice == $CONTAINER_CLEAR_SACK;
        return 'Why do you need a replacement container?';
    },
    validate_method => sub {
        my $self = shift;
        my $c = $self->form->c;
        return if $self->has_errors;
        my $value = $self->value;
        my $saved_data = $self->form->saved_data;

        my $echo = $c->cobrand->feature('echo');
        $echo = Integrations::Echo->new(%$echo);

        my $choice = $saved_data->{'container-choice'};
        my $months = $value eq 'new_build' ?  $new_build_ordered_months{$choice} : $ordered_months{$choice};
        return unless $months;

        my $events = $echo->GetEventsForObject(PointAddress => $c->stash->{property}{id}, 2936, $months);
        $events = $c->cobrand->_parse_events($events, { include_closed_requests => 1 });
        $saved_data->{ordered_previously} = $events->filter({ containers => [$choice] }) ? 1 : 0;

        if ($value eq 'extra' || $value eq 'missing') {
            my $services = $c->stash->{service_data};
            my @tasks;
            foreach (@$services) {
                my $container = $_->{request_containers}->[0];
                push @tasks, $_->{service_task_id} if $container == $choice;
            }

            # The below is not currently in use, FD-3672
            # my $months = $refusal_contamination_months{$choice};
            # my $end = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->truncate( to => 'day' );
            # my $start = $end->clone->add(months => -$months);

            # my $result = $echo->GetServiceTaskInstances($start, $end, @tasks);

            # my $num = 0;
            # foreach (@$result) {
            #     my $task_id = $_->{ServiceTaskRef}{Value}{anyType};
            #     my $tasks = Integrations::Echo::force_arrayref($_->{Instances}, 'ScheduledTaskInfo');
            #     foreach (@$tasks) {
            #         $num++ if ($_->{Resolution}||0) == 1148;
            #     }
            # }
            # $saved_data->{contamination_reports} = $num;
        }
    },
);

sub options_request_reason {
    my $form = shift;
    my $data = $form->saved_data;
    my $choice = $data->{'container-choice'} || 0;
    my @options;
    if ($choice == $CONTAINER_CLEAR_SACK) {
        push @options, { value => 'new_build', label => 'I am a new resident without any' };
        push @options, { value => 'extra', label => 'I have used all the sacks provided' };
    } elsif ($choice == $CONTAINER_GREEN_BIN) {
        push @options, { value => 'damaged', label => 'My container is damaged' };
        push @options, { value => 'missing', label => 'My container is missing' };
    } else {
        push @options, { value => 'new_build', label => 'I am a new resident without a container' };
        push @options, { value => 'damaged', label => 'My container is damaged' };
        push @options, { value => 'missing', label => 'My container is missing' };
        push @options, { value => 'extra', label => 'I would like an extra container' };
    }
    return @options;
}

has_page how_long_lived => (
    fields => ['how_long_lived', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field how_long_lived => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How long have you lived at this address?',
    options => [
        { value => 'less3', label => 'Less than 3 months' },
        { value => '3more', label => '3 months or more' },
    ],
);

has_page request_refuse_container => (
    title => 'Household details',
    fields => ['request_property_type', 'request_property_people', 'request_property_nappies', 'request_reason_refuse', 'request_reason_refuse_number', 'request_reason_refuse_size', 'continue'],
    next => 'about_you',
);

has_field request_property_type =>(
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    build_label_method => sub {
        my $self = shift;
        return $self->parent->create_label($self->name);
    },
    options_method => sub {
        my $self = shift;
        return $self->parent->create_options($self->name);
    }
);

has_field request_property_people =>(
    required => 1,
    type => 'Select',
    build_label_method => sub {
        my $self = shift;
        return $self->parent->create_label($self->name);
    },
    options_method => sub {
        my $self = shift;
        return $self->parent->create_options($self->name);
    }
);

has_field request_property_nappies =>(
    required => 1,
    type => 'Select',
    build_label_method => sub {
        my $self = shift;
        return $self->parent->create_label($self->name);
    },
        options_method => sub {
        my $self = shift;
        return $self->parent->create_options($self->name);
    }
);

has_field request_reason_refuse =>(
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    build_label_method => sub {
        my $self = shift;
        return $self->parent->create_label($self->name);
    },
        options_method => sub {
        my $self = shift;
        return $self->parent->create_options($self->name);
    }
);

has_field request_reason_refuse_number =>(
    required => 1,
    type => 'Select',
    build_label_method => sub {
        my $self = shift;
        return $self->parent->create_label($self->name);
    },
        options_method => sub {
        my $self = shift;
        return $self->parent->create_options($self->name);
    }
);

has_field request_reason_refuse_size =>(
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    build_label_method => sub {
        my $self = shift;
        return $self->parent->create_label($self->name);
    },
        options_method => sub {
        my $self = shift;
        return $self->parent->create_options($self->name);
    }
);

has_field continue_request_container => (
    type => 'Submit',
    value => 'Apply for a new/replacement refuse bin',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field submit => (
    type => 'Submit',
    value => 'Request container',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my ($form) = @_;

    if ($form->current_page->title eq 'Household details') {
        my $container_count;
        my $container_size;
        for my $field_name ( @{ $form->current_page->fields } ) {
            my $field = $form->field($field_name);
            if ($field_name eq 'request_reason_refuse_number') {
                $container_count = $field->value;
            } elsif ($field_name eq 'request_reason_refuse_size') {
                $container_size = $field->value;
            };
        };
        if ($container_count > 0 && $container_size !~ /1|2/) {
            $form->field('request_reason_refuse_size')->add_error('Please select container size when there are bins at the property');
        } elsif ($container_count == 0 && $container_size =~ /1|2/) {
            $form->field('request_reason_refuse_number')->add_error('Please add number of waste bins when bin size is selected');
        }
    };

};

sub create_label {
    my ($self, $field_name) = @_;
    return $self->{c}->cobrand->waste_request_fields($field_name, 'label');
};

sub create_options {
    my ($self, $field_name) = @_;
    my $options = $self->{c}->cobrand->waste_request_fields($field_name, 'values');
    my @options_array;
    for my $key (sort keys %$options) {
        push @options_array, { value => $key, label => $options->{$key} };
    };
    return \@options_array;
};

1;
