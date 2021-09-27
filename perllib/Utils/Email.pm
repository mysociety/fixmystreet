package Utils::Email;

use Email::Address;
use IO::Socket::SSL::PublicSuffix;
use Net::DNS::Resolver;

my $ps = IO::Socket::SSL::PublicSuffix->default;

# DMARC stabbity stab
sub test_dmarc {
    my $email = shift;

    my $addr = (Email::Address->parse($email))[0];
    return unless $addr;

    my $domain = $addr->host;
    my $org_domain = $ps->public_suffix($domain, 1);

    my @answers = _send(Net::DNS::Resolver->new, "_dmarc.$domain", 'TXT');
    @answers = map { $_->txtdata } @answers;
    my $dmarc = join(' ', @answers);

    return 1 if $dmarc =~ /; *p *= *(reject|quarantine)/;
    return if $dmarc;

    return unless $domain ne $org_domain;

    @answers = _send(Net::DNS::Resolver->new, "_dmarc.$org_domain", 'TXT');
    @answers = map { $_->txtdata } @answers;
    $dmarc = join(' ', @answers);

    return 1 if $dmarc =~ /; *sp *= *(reject|quarantine)/;
    return if $dmarc =~ /; *sp *= *none/;
    return 1 if $dmarc =~ /; *p *= *(reject|quarantine)/;
    return;
}

# Same as send->answer, but follows one CNAME and returns only matching results
sub _send {
    my ($resolver, $domain, $type) = @_;
    my $packet = $resolver->send($domain, $type);
    my @answers;
    foreach my $rr ($packet->answer) {
        if ($rr->type eq 'CNAME') {
            push @answers, $resolver->send($rr->cname, $type)->answer;
        } else {
            push @answers, $rr;
        }
    }
    return grep { $_->type eq $type } @answers;
}

sub same_domain {
    my ($email, $list) = @_;
    my $addr = (Email::Address->parse($email->[0]))[0];
    return unless $addr;
    my $domain = $addr->host;
    foreach (@$list) {
        my $addr = (Email::Address->parse($_->[0]))[0];
        next unless $addr;
        return 1 if $domain eq $addr->host;
    }
}

1;
