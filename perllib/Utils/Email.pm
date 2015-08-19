package Utils::Email;

use Email::Address;
use Net::DNS::Resolver;

# DMARC stabbity stab
sub test_dmarc {
    my $email = shift;

    my $addr = (Email::Address::parse($email))[0];
    return unless $addr;

    my $domain = $addr->host;
    my @answers = Net::DNS::Resolver->new->send("_dmarc.$domain", 'TXT')->answer;
    @answers = map { $_->txtdata } @answers;
    my $dmarc = join(' ', @answers);
    return unless $dmarc =~ /p *= *reject/;

    return 1;
}

1;
