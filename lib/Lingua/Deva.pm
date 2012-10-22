package Lingua::Deva;

use v5.12.1;
use strict;
use warnings;
use utf8;
use charnames          qw( :full );
use open               qw( :encoding(UTF-8) :std );
use Unicode::Normalize qw( NFD NFC );
use Carp               qw( croak carp );

use Lingua::Deva::Aksara;
use Lingua::Deva::Maps qw( %Vowels %Diacritics %Consonants %Finals
                         $Virama $Inherent );

=encoding UTF-8

=head1 NAME

Lingua::Deva - Convert between Latin and Devanagari Sanskrit text

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

    use v5.12.1;
    use strict;
    use utf8;
    use charnames ':full';
    use Lingua::Deva;

    # Basic usage
    my $d = Lingua::Deva->new();
    say $d->to_latin('आसीद्राजा'); # prints 'āsīdrājā'
    say $d->to_deva('Nalo nāma'); # prints 'नलो नाम'

    # With configuration: strict, allow Danda, 'w' for 'v'
    my %c = %Lingua::Deva::Maps::Consonants;
    $d = Lingua::Deva->new(
        strict => 1,
        allow  => [ "\N{DEVANAGARI DANDA}" ],
        C      => do { $c{'w'} = delete $c{'v'}; \%c },
    );
    say $d->to_deva('ziwāya'); # 'zइवाय', warning for 'z'
    say $d->to_latin('सर्वम्।'); # 'sarvam।', no warnings

=head1 DESCRIPTION

Facilities for converting Sanskrit in Latin transliteration to Devanagari and
vice-versa.  The principal interface is exposed through instances of the
C<Lingua::Deva> class.  "Deva" is the name for the Devanagari (I<Devanāgarī>)
script according to ISO 15924.

Using the module is as simple as creating a C<Lingua::Deva> instance and calling
C<to_deva()> or C<to_latin()> with appropriate string arguments.

    my $d = Lingua::Deva->new();
    say $d->to_latin('कामसूत्र');
    say $d->to_deva('Kāmasūtra');

The default translation maps adhere to the IAST transliteration scheme, but it
is easy to customize these mappings.  This is done by copying and modifying a
map from C<Lingua::Deva::Maps> and passing it to the C<Lingua::Deva> constructor.

    # Copy and modify the consonants map
    my %c = %Lingua::Deva::Maps::Consonants;
    $c{"c\x{0327}"} = delete $c{"s\x{0301}"};

    # Pass a reference to the modified map to the constructor
    my $d = Lingua::Deva->new( C => \%c );

Behind the scenes, all translation is done via an intermediate object
representation called "aksara" (Sanskrit I<akṣara>).  These objects are
instances of C<Lingua::Deva::Aksara>, which provides an interface to inspect and
manipulate individual aksaras.

    # Create an array of aksaras
    my $a = $d->l_to_aksara('Kāmasūtra');

    # Print vowel in the fourth Aksara
    say $a->[3]->vowel();

Having the intermediate C<Lingua::Deva::Aksara> representation comes with a
slight penalty in efficiency, but gives you the advantage of having aksara
structure available for precise analysis and validation.

=head2 Methods

=over 4

=item new()

Constructor.  Takes optional arguments which are described below.

=over 4

=item * C<< strict => 0 or 1 >>

In strict mode warnings for invalid input are output.  Invalid means either
not a Devanagari token (eg. "q") or structurally ill-formed (eg. a Devanagari
diacritic vowel following an independent vowel).

Off by default.

=item * C<< allow => [ ... ] >>

In strict mode, the C<allow> array can be used to exempt certain characters
from being flagged as invalid even though they normally would be.

=item * C<< C => { consonants map } >>

=item * C<< V => { independent vowels map } >>

=item * C<< D => { diacritic vowels map } >>

=item * C<< F => { finals map } >>

Translation maps in the direction Latin to Devanagari.

=item * C<< DC => { consonants map } >>

=item * C<< DV => { independent vowels map } >>

=item * C<< DD => { diacritic vowels map } >>

=item * C<< DF => { finals map } >>

Translation maps in the direction Devanagari to Latin.

The default maps are in C<Lingua::Deva::Maps>.  To customize, make a copy of an
existing mapping hash and pass it to one of these parameters.  Note that the
map keys need to be in Unicode NFD form (see C<Unicode::Normalize>).

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = {
        strict => 0,
        allow  => [], # converted to a hash for efficiency
        C      => \%Consonants,
        V      => \%Vowels,
        D      => \%Diacritics,
        F      => \%Finals,
        DC     => do { my %c = reverse %Consonants; \%c },
        DV     => do { my %v = reverse %Vowels;     \%v },
        DD     => do { my %d = reverse %Diacritics; \%d },
        DF     => do { my %f = reverse %Finals;     \%f },
        %opts,
    };

    # Make the inherent vowel translate to '' in the D map
    $self->{D}->{$Inherent} = '';

    # Convert the 'allow' array to a hash for fast lookup
    my %allow = map { $_ => 1 } @{ $self->{allow} };
    $self->{allow} = \%allow;

    # Make consonants, vowels, and finals available as tokens
    my %tokens = (%{ $self->{C} }, %{ $self->{V} }, %{ $self->{F} });
    $self->{T} = \%tokens;

    return bless $self, $class;
}

=item l_to_tokens()

Converts a string of Latin characters into "tokens" and returns a reference to
an array of tokens.  A "token" is either a character sequence which may
constitute a single Devanagari grapheme or a single non-Devanagari character.

    my $t = $d->l_to_tokens("Bhārata\n");
    # $t now refers to the array ['Bh','ā','r','a','t','a',"\n"]

The input string will be normalized (NFD).  No chomping takes place.  Upper
case and lower case distinctions are preserved.

B<Technical note:>  This is not a general-purpose tokenizer.  A token
consisting of more than one element is only correctly recognized if all
preceding subsequences are also tokens.  For the token "abc" to be recognized,
both "ab" and "a" need to be tokens as well.  Fortunately, the decomposed
tokens in IAST transliteration do fulfil this property:

    "r\x{0323}\x{0304}"
    "r\x{0323}"
    "r"

=cut

sub l_to_tokens {
    my ($self, $text) = @_;
    return unless defined $text;

    my @chars = split //, NFD($text);
    my @tokens;
    my $token = '';
    my $T = $self->{T};

    for my $c (@chars) {
        if (exists $T->{lc $token.$c}) {
            $token .= $c;
        }
        else {
            push @tokens, $token unless $token eq '';
            $token = $c;
        }
    }

    push @tokens, $token unless $token eq '';

    return \@tokens;
}

=item l_to_aksara()

Converts its argument into "aksaras" and returns a reference to an array of
aksaras (see C<Lingua::Deva::Aksara>).  The argument can be a Latin string, or a
reference to an array of tokens.

    my $a = $d->l_to_aksara('hyaḥ');
    is( ref($a->[0]), 'Lingua::Deva::Aksara', 'one aksara object' );
    done_testing();

Input tokens which can not be part of an aksara are passed through untouched.
This means that the resulting array can contain both aksara objects and
separate tokens.

In strict mode warnings for invalid tokens are output.

=cut

sub l_to_aksara {
    my ($self, $input) = @_;

    # Input can be either a string (scalar) or an array reference
    my $tokens = ref($input) eq '' ? $self->l_to_tokens($input) : $input;

    my @aksaras;
    my $a;
    my $state = 0;
    my ($C, $V, $F) = ($self->{C}, $self->{V}, $self->{F});

    # Aksarization is implemented with a state machine.
    # State 0: Not currently constructing an aksara, ready for any input
    # State 1: Constructing consonantal onset
    # State 2: Onset and vowel read, ready for final or end of aksara

    for my $t (@$tokens) {
        my $lct = lc $t;
        if ($state == 0) {
            if (exists $C->{$lct}) {         # consonant: new aksara
                $a = Lingua::Deva::Aksara->new( onset => [ $lct ] );
                $state = 1;
            }
            elsif (exists $V->{$lct}) {      # vowel: vowel-initial aksara
                $a = Lingua::Deva::Aksara->new( vowel => $lct );
                $state = 2;
            }
            else {                           # final or other: invalid
                if ($t !~ /\p{Space}/ and $self->{strict} and !exists $self->{allow}->{$t}) {
                    carp("Invalid token $t read");
                }
                push @aksaras, $t;
            }
        }
        elsif ($state == 1) {
            if (exists $C->{$lct}) {         # consonant: part of onset
                push @{ $a->{onset} }, $lct;
            }
            elsif (exists $V->{$lct}) {      # vowel: vowel nucleus
                $a->{vowel} = $lct;
                $state = 2;
            }
            else {                           # final or other: invalid
                push @aksaras, $a;
                if ($t !~ /\p{Space}/ and $self->{strict} and !exists $self->{allow}->{$t}) {
                    carp("Invalid token $t read");
                }
                push @aksaras, $t;
                $state = 0;
            }
        }
        elsif ($state == 2) {
            if (exists $C->{$lct}) {         # consonant: new aksara
                push @aksaras, $a;
                $a = Lingua::Deva::Aksara->new( onset => [ $lct ] );
                $state = 1;
            }
            elsif (exists $V->{$lct}) {      # vowel: new vowel-initial aksara
                push @aksaras, $a;
                $a = Lingua::Deva::Aksara->new( vowel => $lct );
                $state = 2;
            }
            elsif (exists $F->{$lct}) {      # final: end of aksara
                $a->{final} = $lct;
                push @aksaras, $a;
                $state = 0;
            }
            else {                           # other: invalid
                push @aksaras, $a;
                if ($t !~ /\p{Space}/ and $self->{strict} and !exists $self->{allow}->{$t}) {
                    carp("Invalid token $t read");
                }
                push @aksaras, $t;
                $state = 0;
            }
        }
    }

    # Finish aksara currently under construction
    push @aksaras, $a if $state == 1 or $state == 2;

    return \@aksaras;
}

=item d_to_aksara()

Converts a Devanagari string into "aksaras" and returns a reference to an
array of aksaras.

    my $text = 'बुद्धः';
    my $a = $d->d_to_aksara($text);

    my $o = $a->[1]->onset();
    # $o now refers to the array ['d','dh']

Input tokens which can not be part of an aksara are passed through untouched.
This means that the resulting array can contain both aksara objects and
separate tokens.

In strict mode warnings for invalid tokens are output.

=cut

sub d_to_aksara {
    my ($self, $input) = @_;

    my @chars = split //, $input;
    my @aksaras;
    my $a;
    my $state = 0;
    my ($DC, $DV, $DD, $DF) = ( $self->{DC}, $self->{DV},
                                $self->{DD}, $self->{DF} );

    # Aksarization is implemented with a state machine.
    # State 0: Not currently constructing an aksara, ready for any input
    # State 1: Consonant with inherent vowel, ready for vowel, Virama, final
    # State 2: Virama read, ready for consonant or end of aksara
    # State 3: Vowel read, ready for final or end of aksara
    # The inherent vowel needs to be taken into account specially

    for my $c (@chars) {
        if ($state == 0) {
            if (exists $DC->{$c}) {          # consonant: new aksara
                $a = Lingua::Deva::Aksara->new( onset => [ $DC->{$c} ] );
                $state = 1;
            }
            elsif (exists $DV->{$c}) {       # vowel: vowel-initial aksara
                $a = Lingua::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            else {                           # final or other: invalid
                if ($c !~ /\p{Space}/ and $self->{strict} and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
            }
        }
        elsif ($state == 1) {
            if ($c =~ /$Virama/) {           # Virama: consonant-final
                $state = 2;
            }
            elsif (exists $DD->{$c}) {       # diacritic: vowel nucleus
                $a->{vowel} = $DD->{$c};
                $state = 3;
            }
            elsif (exists $DV->{$c}) {       # vowel: new vowel-initial aksara
                $a->{vowel} = $Inherent;
                push @aksaras, $a;
                $a = Lingua::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            elsif (exists $DC->{$c}) {       # consonant: new aksara
                $a->{vowel} = $Inherent;
                push @aksaras, $a;
                $a = Lingua::Deva::Aksara->new( onset => [ $DC->{$c} ] );
            }
            elsif (exists $DF->{$c}) {       # final: end of aksara
                $a->{vowel} = $Inherent;
                $a->{final} = $DF->{$c};
                push @aksaras, $a;
                $state = 0;
            }
            else {                           # other: invalid
                $a->{vowel} = $Inherent;
                push @aksaras, $a;
                if ($c !~ /\p{Space}/ and $self->{strict} and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
                $state = 0;
            }
        }
        elsif ($state == 2) {
            if (exists $DC->{$c}) {          # consonant: cluster
                push @{ $a->{onset} }, $DC->{$c};
                $state = 1;
            }
            elsif (exists $DV->{$c}) {       # vowel: new vowel-initial aksara
                push @aksaras, $a;
                $a = Lingua::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            else {                           # other: invalid
                push @aksaras, $a;
                if ($c !~ /\p{Space}/ and $self->{strict} and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
                $state = 0;
            }
        }
        elsif ($state == 3) {                # final: end of aksara
            if (exists $DF->{$c}) {
                $a->{final} = $DF->{$c};
                push @aksaras, $a;
                $state = 0;
            }
            elsif (exists $DC->{$c}) {       # consonant: new aksara
                push @aksaras, $a;
                $a = Lingua::Deva::Aksara->new( onset => [ $DC->{$c} ] );
                $state = 1;
            }
            elsif (exists $DV->{$c}) {       # vowel: new vowel-initial aksara
                push @aksaras, $a;
                $a = Lingua::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            else {                           # other: invalid
                push @aksaras, $a;
                if ($c !~ /\p{Space}/ and $self->{strict} and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
                $state = 0;
            }
        }
    }

    # Finish aksara currently under construction
    given ($state) {
        when (1)      { $a->{vowel} = $Inherent; continue }
        when ([1..3]) { push @aksaras, $a }
    }

    return \@aksaras;
}

=item to_deva()

Converts a Latin string or an array of aksaras to a Devanagari string.

    say $d->to_deva('Kāmasūtra');

    # same as
    my $a = $d->l_to_aksara('Kāmasūtra');
    say $d->to_deva($a);

Aksaras are assumed to be well-formed.

=cut

sub to_deva {
    my ($self, $input) = @_;

    # Input can be either a string (scalar) or an array reference
    my $aksaras = ref($input) eq '' ? $self->l_to_aksara($input) : $input;

    my $s = '';
    my ($C, $V, $D, $F) = ($self->{C}, $self->{V}, $self->{D}, $self->{F});

    for my $a (@$aksaras) {
        if (ref($a) ne 'Lingua::Deva::Aksara') {
            $s .= $a;
        }
        else {
            if (defined $a->{onset}) {
                $s .= join($Virama, map { $C->{$_} } @{ $a->{onset} });
                $s .= defined $a->{vowel} ? $D->{$a->{vowel}} : $Virama;
            }
            elsif (defined $a->{vowel}) {
                $s .= $V->{$a->{vowel}};
            }
            $s .= $F->{$a->{final}} if defined $a->{final};
        }
    }

    return $s;
}

=item to_latin()

Converts a Devanagari string or an array of aksaras to an equivalent string in
Latin transliteration.

Aksaras are assumed to be well-formed.

=cut

sub to_latin {
    my ($self, $input) = @_;

    # Input can be either a string (scalar) or an array reference
    my $aksaras = ref($input) eq '' ? $self->d_to_aksara($input) : $input;

    my $s = '';
    for my $a (@$aksaras) {
        if (ref($a) eq 'Lingua::Deva::Aksara') {
            $s .= join '', @{ $a->{onset} } if defined $a->{onset};
            $s .= $a->{vowel} if defined $a->{vowel};
            $s .= $a->{final} if defined $a->{final};
        }
        else {
            $s .= $a;
        }
    }

    return $s;
}

=back 

=cut

1;
__END__

=head1 EXAMPLES

The synopsis gives the simplest usage patterns.  Here are a few more.

To use "ring below" instead of "dot below" for syllabic r:

    my %v = %Lingua::Deva::Maps::Vowels;
    $v{"r\x{0325}"}         = delete $v{"r\x{0323}"};
    $v{"r\x{0325}\x{0304}"} = delete $v{"r\x{0323}\x{0304}"};
    my %d = %Lingua::Deva::Maps::Diacritics;
    $d{"r\x{0325}"}         = delete $d{"r\x{0323}"};
    $d{"r\x{0325}\x{0304}"} = delete $d{"r\x{0323}\x{0304}"};

    my $d = Lingua::Deva->new( V => \%v, D => \%d );
    say $d->to_deva('Kr̥ṣṇa');

Use the aksara objects to produce simple statistics.

    # Count distinct rhymes in @aksaras
    for my $a (grep { defined $_->get_rhyme() } @aksaras) {
        $rhymes{ join '', @{$a->get_rhyme()} }++;
    }

    # Print number of 'au' rhymes
    say $rhymes{'au'};

The following script converts a Latin input file "in.txt" to Devanagari.

    #!/usr/bin/env perl
    use v5.12.1;
    use strict;
    use warnings;
    use open ':encoding(UTF-8)';
    use Lingua::Deva;

    open my $in,  '<', 'in.txt'  or die;
    open my $out, '>', 'out.txt' or die;

    my $d = Lingua::Deva->new();
    while (my $line = <$in>) {
        print $out $d->to_deva($line);
    }

On a Unicode-capable terminal one-liners are also possible:

    echo 'Himālaya' | perl -MLingua::Deva -e 'print Lingua::Deva->new()->to_deva(<>);'

=head1 DEPENDENCIES

There are no requirements apart from standard Perl modules.

Note that a modern, Unicode-capable version of Perl >= 5.12 is required.

=head1 AUTHOR

glts <676c7473@gmail.com>

=head1 BUGS

Report bugs to the author or at https://github.com/glts/Lingua-Deva

=head1 COPYRIGHT

This program is free software.  You may copy or redistribute it under the same
terms as Perl itself.

Copyright (c) 2012 by glts <676c7473@gmail.com>

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself, either Perl version 5.12.1 or, at your option,
any later version of Perl 5 you may have available.

=cut
