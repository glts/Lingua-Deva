package Text::Deva::Aksara;

use v5.12.1;
use strict;
use warnings;

use Text::Deva::Maps qw( %Vowels %Consonants %Finals );

=encoding UTF-8

=head1 NAME

Text::Deva::Aksara - Object representation of a Devanagari "syllable"

=head1 SYNOPSIS

    use v5.12.1;
    use strict;
    use charnames ':full';
    use open qw( :encoding(UTF-8) :std );
    use Text::Deva::Aksara;

    my $a = Text::Deva::Aksara->new(
        onset => [ 'dh', 'r' ],
        vowel => 'au',
        final => "h\N{COMBINING DOT BELOW}",
    );
    $a->vowel( 'ai' );
    say 'valid' if $a->is_valid();
    say @{ $a->get_rhyme() };

=head1 DESCRIPTION

I<Akṣara> is the Sanskrit term for the basic unit above the character level in
the Devanagari script.  A C<Text::Deva::Aksara> object is a Perl
representation of such a unit.

C<Text::Deva::Aksara> objects serve as an intermediate format for the
conversion facilities in C<Text::Deva>.  Onset, vowel, and final tokens are
stored in separate fields.  Tokens are in Latin script, with no distinction
between upper and lower case.

=head2 Methods

=over 4

=item new()

Constructor.  Can take optional initial data as its argument.

    Text::Deva::Aksara->new( onset => ['gh', 'r'] );

=cut

sub new {
    my $class = shift;
    my $self = { @_ };
    return bless $self, $class;
}

=item onset()

Accessor method for the array of onset tokens of this aksara.

    my $a = Text::Deva::Aksara->new();
    $a->onset( ['d', 'r'] ); # sets onset tokens to ['d', 'r']
    $a->onset(); # returns a reference to ['d', 'r']

Returns undefined when there is no onset.

=cut

sub onset {
    my $self = shift;
    $self->{onset} = shift if @_;
    return $self->{onset};
}

=item vowel()

Accessor method for the vowel token of this aksara.  Returns undefined when
there is no vowel.

=cut

sub vowel {
    my $self = shift;
    $self->{vowel} = shift if @_;
    return $self->{vowel};
}

=item final()

Accessor method for the final token of this aksara.  Returns undefined when
there is no final.

=cut

sub final {
    my $self = shift;
    $self->{final} = shift if @_;
    return $self->{final};
}

=item get_rhyme()

Returns the rhyme of this aksara.  This is a reference to an array consisting
of vowel and final.  Undefined if there is no rhyme.

The aksara is assumed to be well-formed.

=cut

sub get_rhyme {
    my $self = shift;
    if ($self->{final}) { return [ $self->{vowel}, $self->{final} ] }
    if ($self->{vowel}) { return [ $self->{vowel} ] }
    return;
}

=item is_valid()

Checks the formal validity of this aksara.  This method first checks if the
aksara conforms to the structure C<(C+(VF?)?)|(VF?)>, where the letters
represent onset consonants, vowel, and final.  Then it checks whether the
onset, vowel, and final fields contain only appropriate tokens.

If the maps have been modified in the C<Text::Deva> instance, a reference to
that instance can be passed along and the modified maps will be used.

    $d; # Text::Deva object with custom maps
    $a->is_valid($d);

An aksara constructed through C<Text::Deva>'s public interface is already
well-formed and no validity check is necessary.

=cut

sub is_valid {
    my ($self, $deva) = @_;

    my ($C, $V, $F) = (\%Consonants, \%Vowels, \%Finals);
    if (ref($deva) eq 'Text::Deva') {
        ($C, $V, $F) = ($deva->{C}, $deva->{V}, $deva->{F});
    }

    # Check aksara structure
    my $s = @{ $self->{onset} // [] } ? 'C' : '';
    $s   .=    $self->{vowel}         ? 'V' : '';
    $s   .=    $self->{final}         ? 'F' : '';
    return 0 if $s =~ m/^(C?F|)$/;

    # After this point empty strings and arrays have been rejected

    # Check aksara tokens
    if (defined $self->{onset}) {
        for my $o (@{ $self->{onset} }) {
            return 0 if not defined $C->{$o};
        }
    }
    if (defined $self->{vowel}) {
        return 0 if not defined $V->{ $self->{vowel} };
    }
    if (defined $self->{final}) {
        return 0 if not defined $F->{ $self->{final} };
    }

    return 1;
}

=back

=cut

1;
