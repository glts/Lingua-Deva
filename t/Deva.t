use v5.12.1;
use strict;
use warnings;
use utf8;

use Data::Dumper;
use Test::More tests => 7;

BEGIN { use_ok('Text::Deva') };

my $d = Text::Deva->new();

# Example string contains invalid characters
my $text = "aham ghexample strin\x{0307} asmi\n"
         . "aham examplāmitʰaṇḍrai strīm\x{0310} asmi";

my $tokens = $d->l_to_tokens($text);
ok( @$tokens, "basic string tokenization");

my $aksaras = $d->l_to_aksara($tokens);
ok( @$aksaras, "l_to_aksara an array of tokens");
is_deeply($aksaras, $d->l_to_aksara($text), "aksarize a string");

my $transl = $d->to_deva($aksaras);
ok($transl, "translate an array of aksaras");
is($d->to_deva($text),
    "अहम् घेxअम्प्ले स्त्रिङ् अस्मि\nअहम् एxअम्प्लामित्ʰअण्ड्रै स्त्रीँ अस्मि", "translate mixed string");

my %c = %Text::Deva::Maps::Consonants;
$c{"c\x{0327}"} = delete $c{"s\x{0301}"}; # custom map
my $e = Text::Deva->new('C' => \%c);
is($e->to_deva("paçyema"), "पश्येम", "translate with custom map");
