use FixMyStreet::TestMech;
use FixMyStreet::Cobrand::Boituva;

use Test::More;

my $cobrand = bless {}, 'FixMyStreet::Cobrand::Boituva';
is($cobrand->country, 'BR', 'uses the Brazilian country code');
is($cobrand->language_override, 'pt-br', 'uses Brazilian Portuguese');
is(
    $cobrand->enter_postcode_text,
    'Digite o endereço completo, número do protocolo ou ponto de referência',
    'prompts for an address or report reference in Portuguese',
);

my $ref_regex = $cobrand->lookup_by_ref_regex;
like('12345', $ref_regex, 'recognizes a numeric protocol');
like('ref: 12345', $ref_regex, 'recognizes a prefixed protocol');
unlike('Rua das Flores', $ref_regex, 'does not treat an address as a protocol');

done_testing();
