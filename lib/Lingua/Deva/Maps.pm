package Lingua::Deva::Maps;

use v5.12.1;
use strict;
use warnings;
use utf8;
use charnames ':full';

use Lingua::Deva::Maps::IAST;

=encoding UTF-8

=head1 NAME

Lingua::Deva::Maps - Default maps setup for Lingua::Deva

=cut

use Exporter;
use parent 'Exporter';
our @EXPORT_OK = qw( %Consonants %Vowels %Diacritics %Finals
                     $Inherent $Virama $Avagraha );

=head1 SYNOPSIS

    use Lingua::Deva::Maps::IAST;   # or
    use Lingua::Deva::Maps::HK;     # or
    use Lingua::Deva::Maps::ITRANS;

    my $d = Lingua::Deva->new(
        casesensitive => 1,
        C => do { my %c = %Lingua::Deva::Maps::HK::Consonants; \%c },
        V => do { my %v = %Lingua::Deva::Maps::HK::Vowels;     \%v },
        D => do { my %d = %Lingua::Deva::Maps::HK::Diacritics; \%d },
        F => do { my %f = %Lingua::Deva::Maps::HK::Finals;     \%f },
    );
    say $d->to_deva('gaNezaH'); # prints 'गणेशः'

=head1 DESCRIPTION

This module is intended for internal use in C<Lingua::Deva>.

However, it does provide the namespace for the ready-made maps,

=over 4

=item Lingua::Deva::Maps::IAST International Alphabet of Sanskrit Transliteration

=item Lingua::Deva::Maps::HK Harvard-Kyoto transliteration

=item Lingua::Deva::Maps::ITRANS

=back

These maps each provide four hashes, C<%Consonants>, C<%Vowels>, C<%Diacritics>, and
C<%Finals>. The C<Lingua::Deva> module relies on this subdivision for its parsing and
aksarization process.

Inside these hashes the keys are Latin script "tokens" in canonically
decomposed form (NFD), and the values are the Unicode characters in Devanagari
script:

    "bh" => "\N{DEVANAGARI LETTER BHA}" # in %Consonants

The hash keys must be in canonically decomposed form.  For example a key "ç" (c
with cedilla) needs to be entered as "c\x{0327}", ie. a "c" with combining
cedilla. If the transliteration is case-insensitive, the keys must be
lowercase.

Info on usage?
# The mappings must be accessed
# through the fully qualified name (eg. "%Lingua::Deva::Maps::IAST::Vowels")

Finally, C<Lingua::Deva::Maps> also defines the global variables C<$Inherent>
(the inherent vowel I<a>), C<$Virama> ( ्), and C<$Avagraha> (ऽ) which are
unlikely to need configurability.

=cut

# Setup default maps
*Consonants   = \%Lingua::Deva::Maps::IAST::Consonants;
*Vowels       = \%Lingua::Deva::Maps::IAST::Vowels;
*Diacritics   = \%Lingua::Deva::Maps::IAST::Diacritics;
*Finals       = \%Lingua::Deva::Maps::IAST::Finals;

# Global variables
our $Inherent = "a";
our $Virama   = "\N{DEVANAGARI SIGN VIRAMA}";
our $Avagraha = "\N{DEVANAGARI SIGN AVAGRAHA}"; # TODO Add avagraha support

1;
