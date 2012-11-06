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

    use Lingua::Deva::Maps::IAST;     # or
    use Lingua::Deva::Maps::HK;       # or
    use Lingua::Deva::Maps::ITRANS;   # or
    use Lingua::Deva::Maps::ISO15919;

    my $d = Lingua::Deva->new(map => 'HK');
    say $d->to_deva('gaNezaH'); # prints 'गणेशः'

=head1 DESCRIPTION

This module is intended for internal use in C<Lingua::Deva>.

It does, however, provide the namespace for the ready-made transliteration
schemes,

=over 4

=item Lingua::Deva::Maps::IAST International Alphabet of Sanskrit Transliteration

=item Lingua::Deva::Maps::HK Harvard-Kyoto

=item Lingua::Deva::Maps::ITRANS

=item Lingua::Deva::Maps::ISO15919 ISO 15919 (simplified)

=back

Every transliteration scheme provides four hashes, C<%Consonants>, C<%Vowels>,
C<%Diacritics>, and C<%Finals>.  The C<Lingua::Deva> module relies on this
subdivision for its parsing and aksarization process.

Inside these hashes the keys are Latin script "tokens" in canonically
decomposed form (NFD), and the values are the Unicode characters in Devanagari
script:

    "bh" => "\N{DEVANAGARI LETTER BHA}" # in %Consonants

The hash keys must be in canonically decomposed form.  For example a key "ç" (c
with cedilla) needs to be entered as "c\x{0327}", ie. a "c" with combining
cedilla. If the transliteration is case-insensitive, the keys must be
lowercase.

In addition to the required four hash maps, a package variable named C<$CASE>
may be present.  If it is, it specifies whether case distinctions have
significance (a != A) or not (A == a).

TODO [outdated] Document advanced customization with CVDF.
It is easy to customize these mappings.  This is done by copying and modifying a
map from C<Lingua::Deva::Maps> and passing it to the C<Lingua::Deva>
constructor.

    # Copy and modify the consonants map
    my %c = %Lingua::Deva::Maps::Consonants;
    $c{"c\x{0327}"} = delete $c{"s\x{0301}"};

    # Pass a reference to the modified map to the constructor
    my $d = Lingua::Deva->new( C => \%c );

    my $d = Lingua::Deva->new(
        casesensitive => 1,
        C => do { my %c = %Lingua::Deva::Maps::HK::Consonants; \%c },
        V => do { my %v = %Lingua::Deva::Maps::HK::Vowels;     \%v },
        D => do { my %d = %Lingua::Deva::Maps::HK::Diacritics; \%d },
        F => do { my %f = %Lingua::Deva::Maps::HK::Finals;     \%f },
    );
    say $d->to_deva('gaNezaH'); # prints 'गणेशः'

Finally, C<Lingua::Deva::Maps> also defines the global variables C<$Inherent>
(the inherent vowel I<a>), C<$Virama> ( ्), and C<$Avagraha> (ऽ) which are
unlikely to need configurability.

It is the user's responsibility to make reasonable customizations; eg. the
vowels (C<V>) and diacritics (C<D>) maps normally need to be customized in
unison.

complete customization

=cut

# Setup default maps
*Consonants   = \%Lingua::Deva::Maps::IAST::Consonants;
*Vowels       = \%Lingua::Deva::Maps::IAST::Vowels;
*Diacritics   = \%Lingua::Deva::Maps::IAST::Diacritics;
*Finals       = \%Lingua::Deva::Maps::IAST::Finals;

# Global variables
our $Inherent = "a";
our $Virama   = "\N{DEVANAGARI SIGN VIRAMA}";
our $Avagraha = "\N{DEVANAGARI SIGN AVAGRAHA}";

1;
