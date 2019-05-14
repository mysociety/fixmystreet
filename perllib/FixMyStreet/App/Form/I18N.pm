package FixMyStreet::App::Form::I18N;

use Moo;

sub maketext {
    my ($self, $msg, @args) = @_;

    no if ($] >= 5.022), warnings => 'redundant';
    return sprintf(_($msg), @args);
}

1;

