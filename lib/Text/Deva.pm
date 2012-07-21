package Text::Deva;

use v5.12.1;
use strict;
use warnings;
use utf8;
use charnames ':full';

use open               qw( :encoding(UTF-8) :std );
use Unicode::Normalize qw( NFD NFC );
use Carp               qw( croak carp );

use Text::Deva::Maps;
use Text::Deva::Aksara;

=encoding UTF-8

=head1 NAME

Text::Deva - Translate between Latin and Devanagari Sanskrit text

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

Simple facilities for transforming transliterated Sanskrit text into its
equivalent in Devanagari script.

    use v5.12.1;
    use strict;
    use utf8;
    use charnames ':full';
    use Text::Deva;

    # Basic usage
    my $d = Text::Deva->new();
    say $d->to_latin("आसीद्राजा");    # returns "āsīdrājā"
    say $d->to_deva("Nalo nāma"); # returns "नलो नाम"

    # With configuration: strict, allow Danda character, 'w' for 'v'
    my %c = %Text::Deva::Maps::Consonants;
    $d = Text::Deva->new(
        strict => 1,
        allow  => [ "\N{DEVANAGARI DANDA}" ],
        C      => do { $c{'w'} = delete $c{'v'}; \%c },
    );
    say $d->to_deva("ziwāya");    # returns "zइवाय" with a warning for "z"
    say $d->to_latin("सर्वम।");    # returns "sarvam।" with no warnings

=head1 DESCRIPTION

Tokenizes Latin script text input into Devanagari aksaras and transforms it
into Devanagari.  `Deva' is the name for the Devanagari (I<Devanāgarī>) script
according to ISO 15924.

Using the module is as simple as creating a C<Text::Deva> instance and
calling C<to_deva()> or C<to_latin()> with an appropriate string argument.

    $d = Text::Deva->new();
    say $d->to_latin("कामसूत्र");
    say $d->to_deva("Kāmasūtra");

The default translation maps adhere to the IAST transliteration scheme, but it
is easy to customize these mappings.  This is done by copying and modifying a
map from C<Text::Deva::Maps>, then passing it to the C<Text::Deva>
constructor.

    # Copy the consonants map
    my %c = %Text::Deva::Maps::Consonants;

    # Replace the key "ś" with "ç"
    $c{"c\x{0327}"} = delete $c{"s\x{0301}"};

    # Pass a reference to the modified map to the constructor
    my $d = Text::Deva->new(C => \%c);

Note that the map keys need to be in Unicode NFD form (canonical
decomposition; see Unicode::Normalize). See the EXAMPLES section for more
examples.

All translation is done via an intermediate representation: I<Aksara> objects.
An I<akṣara> is the Sanskrit term for a sequence of one or more initial
consonants, optionally followed by a rhyme consisting of a vowel plus an
optional final.  Or more formally, "(C+(VF?)?)|(VF?)", where the capital
letters stand for consonant, vowel, and final.

    # Create an array of Aksaras
    $a = l_to_aksara("Kāmasūtra");

    # Print vowel in the fourth Aksara
    say $a->[3]->vowel(); # prints "a"

Breaking input up into Aksara objects is not the most efficient way of doing
this, but a useful one.  The C<Text::Deva::Aksara> interface is simple and
lets you produce statistics easily.

    # Count distinct rhymes
    # FIXME This doesn't work at all!! Those aren't aksaras
    my @lines = <$fh>;
    for my $l (grep { defined $_->get_rhyme() } @lines) {
        $rhymes{ join "", @{$r->get_rhyme()} }++;
    }

    # Print number of rhymes in "au"
    say $rhymes{"au"};

C<Aksara> objects built with the appropriate methods should always be
well-formed.  In other situations, the C<is_valid()> method can be used to
establish an Aksara's formal integrity.

These units are important because the rules for the placement of the accent
marks rely on them.

=head1 METHODS

=over 4

=item new()

Constructs a new Text::Deva object.

The C<new()> function takes two optional parameters which modify the module's
behaviour.

=over 4

=item * C<< strict => 0 or 1 >>

The 'strict' mode determines how lenient the translation behaves on invalid
input.  In strict mode warnings are output for all invalid input characters.
It is off by default.

=item * C<< allow => ['|', "\x{fffd}"] >>

In the 'allow' array you can specify additional characters which would not
normally be allowed in transliterated Devanagari.  Those will always be
regarded as valid.

=item * C<< C => consonants map >>

=item * C<< V => independent vowels map >>

=item * C<< D => diacritic vowels map >>

=item * C<< F => finals map >>

Translation maps in the direction Latin to Devanagari.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = {
        strict => 0,
        allow  => [],
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

    # Make the inherent vowel translate to "" in the I map
    $self->{D}->{$Inherent} = "";

    # Convert the 'allow' array to a hash for fast lookup
    my %allow = map { $_ => 1 } @{ $self->{allow} };
    $self->{allow} = \%allow;

    # Make consonants, vowels, and finals available as tokens
    my %tokens = (%{ $self->{C} }, %{ $self->{V} }, %{ $self->{F} });
    $self->{T} = \%tokens;

    return bless $self, $class;
}

=item l_to_tokens()

Converts a string of Latin script characters into "tokens" and returns a
reference to an array of tokens.  An output "token" is either a string which
may constitute a single Devanagari grapheme, eg. "e", "kh", "s ́", or it is a
single non-Devanagari character.  More technically, a token is a hash key in
any one of the translation maps.

    my $t = $d->l_to_tokens("Bhārata\n");
    # $t now refers to the array ['Bh','ā','r','a','t','a',"\n"]

The input string will be normalized (NFD).  No chomping takes place.  Upper
case and lower case distinctions are preserved.

=cut

sub l_to_tokens {
    my ($self, $text) = @_;
    return unless defined $text;

    my @chars = split //, NFD($text);
    my @tokens;
    my $token = "";
    my $T = $self->{T};

    for my $c (@chars) {
        if (exists $T->{lc $token.$c}) {
            $token .= $c;
        }
        else {
            push @tokens, $token;
            $token = $c;
        }
    }

    push @tokens, $token unless $token eq "";

    return \@tokens;
}

=item l_to_aksara()

Converts its argument into "Aksaras" and returns a reference to an array of
Aksaras.  The argument can be a Latin script string, or a reference to an
array of tokens.

I<Akṣara> is the Sanskrit term for the basic unit above the character level in
the Devanagari script.  This module makes use of a corresponding object
representation, C<Text::Deva::Aksara>.

    my $a = $d->l_to_aksara('hyaḥ');
    is( ref($a->[0]), 'Text::Deva::Aksara', "one Aksara object" );
    is( $a->[0]->vowel(), 'a', "vowel is 'a'" );

    $a = $d->l_to_aksara( ['h','y','a',"h\x{0323}"] );
    # same thing

Input tokens which can not form an Aksara are left untouched.  This means that
the resulting list can contain both Aksara objects and separate tokens.

In "strict" mode, warnings for all invalid characters are output.  A valid
token in an inappropriate position is also flagged.

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
    # Tokens are: 0 other, 1 consonant, 2 vowel, 3 final
    # State 0: Not currently constructing an Aksara, ready for any input
    # State 1: Constructing consonantal onset
    # State 2: Onset and vowel read, ready for final or end of Aksara
    for my $t (@$tokens) {
        my $lct = lc $t;
        if ($state == 0) {
            if (exists $C->{$lct}) {         # consonant: new aksara
                $a = Text::Deva::Aksara->new( onset => [ $lct ] );
                $state = 1;
            }
            elsif (exists $V->{$lct}) {      # vowel: vowel-initial aksara
                $a = Text::Deva::Aksara->new( vowel => $lct );
                $state = 2;
            }
            else {                           # final or other: invalid
                if ($self->{strict} and $t !~ /\p{Space}/ and !exists $self->{allow}->{$t}) {
                    carp("Invalid token $t read");
                }
                push @aksaras, $t;
            }
        }
        elsif ($state == 1) {
            if (exists $C->{$lct}) {         # consonant: part of onset
                push @{ $a->onset() }, $lct;
            }
            elsif (exists $V->{$lct}) {      # vowel: vowel nucleus
                $a->vowel( $lct );
                $state = 2;
            }
            else {                           # final or other: invalid
                if ($self->{strict} and $t !~ /\p{Space}/ and !exists $self->{allow}->{$t}) {
                    carp("Invalid token $t read");
                }
                push @aksaras, $a;
                push @aksaras, $t;
                $state = 0;
            }
        }
        elsif ($state == 2) {
            if (exists $C->{$lct}) {         # consonant: new aksara
                push @aksaras, $a;
                $a = Text::Deva::Aksara->new( onset => [ $lct ] );
                $state = 1;
            }
            elsif (exists $V->{$lct}) {      # vowel: new vowel-initial aksara
                push @aksaras, $a;
                $a = Text::Deva::Aksara->new( vowel => $lct );
                $state = 2;
            }
            elsif (exists $F->{$lct}) {      # final: coda
                $a->final( $lct );
                push @aksaras, $a;
                $state = 0;
            }
            else {                           # other: invalid
                if ($self->{strict} and $t !~ /\p{Space}/ and !exists $self->{allow}->{$t}) {
                    carp("Invalid token $t read");
                }
                push @aksaras, $a;
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

Converts a Devanagari string into I<aksaras> (C<Text::Deva::Aksara>) and
returns a reference to an array of aksaras.

    my $text = 'बुद्धः';
    my $a = $d->d_to_aksara($text);

    my $o = $a->[1]->onset();
    # $o refers to the array ['d','dh']

Input tokens which can not form an aksara are passed through untouched.  The
resulting list may contain both C<Aksara> objects and separate characters.

In "strict" mode, warnings for invalid or misplaced characters are output.

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
    # Tokens are: 0 other, 1 consonant, 2 initial vowel,
    # 3 diacritic vowel, 4 final, 5 Virama
    # State 0: Not currently constructing an aksara, ready for any input
    # State 1: Consonant with inherent vowel; ready for vowel, Virama, final
    # State 2: Ready for consonant or end of aksara
    # State 3: Onset and vowel read, ready for final or end of aksara
    # The inherent vowel needs to be taken into account specially
    for my $c (@chars) {
        if ($state == 0) {
            if (exists $DC->{$c}) {          # consonant: new aksara
                $a = Text::Deva::Aksara->new( onset => [ $DC->{$c} ] );
                $state = 1;
            }
            elsif (exists $DV->{$c}) {       # vowel: vowel-initial aksara
                $a = Text::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            else {                           # final or other: invalid
                if ($self->{strict} and $c !~ /\p{Space}/ and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
            }
        }
        elsif ($state == 1) {
            if ($c =~ /$Virama/) {           # virama: final consonant or cluster
                $state = 2;
            }
            elsif (exists $DD->{$c}) {       # diacritic: vowel nucleus
                $a->vowel( $DD->{$c} );
                $state = 3;
            }
            elsif (exists $DV->{$c}) {       # vowel: new vowel-initial aksara
                $a->vowel( $Inherent );
                push @aksaras, $a;
                $a = Text::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            elsif (exists $DC->{$c}) {       # consonant: new aksara
                $a->vowel( $Inherent );
                push @aksaras, $a;
                $a = Text::Deva::Aksara->new( onset => [ $DC->{$c} ] );
            }
            elsif (exists $DF->{$c}) {       # final: coda
                $a->vowel( $Inherent );
                $a->final( $DF->{$c} );
                push @aksaras, $a;
                $state = 0;
            }
            else {                           # other: invalid
                $a->vowel( $Inherent );
                push @aksaras, $a;
                if ($self->{strict} and $c !~ /\p{Space}/ and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
                $state = 0;
            }
        }
        elsif ($state == 2) {
            if (exists $DC->{$c}) {          # consonant: cluster
                push @{ $a->onset() }, $DC->{$c};
                $state = 1;
            }
            elsif (exists $DV->{$c}) {       # vowel: new vowel-initial aksara
                push @aksaras, $a;
                $a = Text::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            else {                           # other: invalid
                push @aksaras, $a;
                if ($self->{strict} and $c !~ /\p{Space}/ and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
                $state = 0;
            }
        }
        elsif ($state == 3) {                # final: coda
            if (exists $DF->{$c}) {
                $a->final( $DF->{$c} );
                push @aksaras, $a;
                $state = 0;
            }
            elsif (exists $DC->{$c}) {       # consonant: new aksara
                push @aksaras, $a;
                $a = Text::Deva::Aksara->new( onset => [ $DC->{$c} ] );
                $state = 1;
            }
            elsif (exists $DV->{$c}) {       # vowel: new vowel-initial aksara
                push @aksaras, $a;
                $a = Text::Deva::Aksara->new( vowel => $DV->{$c} );
                $state = 3;
            }
            else {                           # other: invalid
                push @aksaras, $a;
                if ($self->{strict} and $c !~ /\p{Space}/ and !exists $self->{allow}->{$c}) {
                    carp("Invalid character $c read");
                }
                push @aksaras, $c;
                $state = 0;
            }
        }
    }

    # Finish aksara currently under construction
    given ($state) {
        when (1)      { $a->vowel( $Inherent ); continue }
        when ([1..3]) { push @aksaras, $a }
    }

    return \@aksaras;
}

=item to_deva()

Converts a Latin script string or an array of "aksaras" to a Devanagari
string.

    say $d->to_deva('TODO');

    # same as
    my $a = $d->l_to_aksara('TODO');
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
        if (ref($a) ne 'Text::Deva::Aksara') {
            $s .= $a;
        }
        else {
            if (defined $a->onset()) {
                $s .= join($Virama, map { $C->{$_} } @{ $a->onset() });
                $s .= defined $a->vowel() ? $D->{$a->vowel()} : $Virama;
            }
            elsif (defined $a->vowel()) {
                $s .= $V->{$a->vowel()};
            }
            $s .= $F->{$a->final()} if defined $a->final();
        }
    }

    return $s;
}

=item to_latin()

Converts a Devanagari string or an array of aksaras to a transliterated string
in Latin script.

Aksaras are assumed to be well-formed.

=cut

sub to_latin {
    my ($self, $input) = @_;

    # Input can be either a string (scalar) or an array reference
    my $aksaras = ref($input) eq '' ? $self->d_to_aksara($input) : $input;

    my $s = '';
    for my $a (@$aksaras) {
        if (ref($a) eq 'Text::Deva::Aksara') {
            $s .= join '', @{ $a->onset() } if defined $a->onset();
            $s .= $a->vowel() if defined $a->vowel();
            $s .= $a->final() if defined $a->final();
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

Some examples will make your life easier: copy-and-paste.

    use Text::Deva;
    $d = Text::Deva->new();

    TODO

Bla bla examples bla.

=head1 AUTHOR

glts <676c7473@gmail.com>

=head1 BUGS

Report bugs to the author or at https://github.com/glts/Text-Deva

=head1 COPYRIGHT

This program is free software.  You may copy or redistribute it under the same
terms as Perl itself.

Copyright (c) 2012 by glts

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
