use v5.12.1;
use strict;
use warnings;
use utf8;

use Data::Dumper;
use Test::More tests => 10;

BEGIN { use_ok('Text::Deva') };

my $d = Text::Deva->new();

# Random Sanskrit words with a few invalid characters
my @lines = split /\n/, <<'EOF';
sabhā saṃnikṛṣṭau kumārāḥ tu Ca rājñas kṛṣṇena Paśyema te ubhau |
sarve Rūpeṇa dīrghavairī etaz avṛttir adhaḥ śūro jñātibhedam kḷptaḥ |
tṛṇāni bhūmir dṛṣṭvā na brāhmaṇaṃ manyante satāṃ tasyāvṛttibhayaṃ mā
raudreṇa tathā duṣputraiḥ brūyā uvāca Ṛṣīṇām dharmam gṛhṇīte |
Iva bālyāt sarvataḥ Dāne apradhṛṣyaṃ qaf siṃhagrīvo tadā yāhi
EOF

for my $line (@lines) { my $tokens = $d->l_to_tokens($line) }
ok(1, "tokenize " . @lines . " lines in non-strict mode");

{
    # Catch and count carp warnings emitted in strict mode
    my $warnings = 0;
    local $SIG{__WARN__} = sub { $warnings++ };

    my $e = Text::Deva->new('strict' => 1, 'allow' => ['|']);
    for my $line (@lines) { my $tokens = $e->l_to_tokens($line) }
    ok($warnings == 3, "tokenize " . @lines . " lines in strict mode, warnings caught");
}

# Tests with a larger dataset

my @large;
push @large, @lines for (1..2000);

sub secs {
    my ($start, $end) = @_;
    return sprintf("(%.2f seconds)", $end-$start);
}

my $start = times();
for my $line (@large) { my $tokens = $d->l_to_tokens($line) }
my $end = times();
ok(1, "tokenize " . @large . " lines " . secs($start, $end));

$start = times();
for my $line (@large) { my $aksaras = $d->l_to_aksara($line) }
$end = times();
ok(1, "aksarize " . @large . " lines " . secs($start, $end));

my @aks;
$start = times();
for my $line (@large) { push @aks, @{ $d->l_to_aksara($line) } }
$end = times();
ok(1, "create array of " . @aks . " aksaras " . secs($start, $end)); 

$start = times();
my @akstype = grep { ref($_) eq 'Text::Deva::Aksara' } @aks;
$end = times();
my $percent = int (@akstype / @aks * 100);
ok(1, "grep " . @akstype . " (" . $percent . "%) actual aksaras in array " . secs($start, $end));

$start = times();
for my $a (@akstype) { $a->is_valid() };
$end = times();
ok(1, "check validity of " . @akstype . " aksaras " . secs($start, $end));

$start = times();
my @onsets = map { defined $_->onset() ? scalar @{ $_->onset() } : 0 } @akstype;
my %onsets;
for my $o (@onsets) { $onsets{$o}++ };
$end = times();
ok(1, "calculate onset length frequencies " . secs($start, $end));

$start = times();
my %rhymes;
for my $r (grep { defined $_->get_rhyme() } @akstype) {
    $rhymes{ join '', @{$r->get_rhyme()} }++;
}
$end = times();
ok(1, "calculate rhyme frequencies " . secs($start, $end));
