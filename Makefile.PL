use v5.12.1;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Text::Deva',
    VERSION_FROM     => 'lib/Text/Deva.pm',
    MIN_PERL_VERSION => 5.12.1,
    PREREQ_PM        => {},
    ABSTRACT_FROM    => 'lib/Text/Deva.pm',
    AUTHOR           => 'glts <676c7473@gmail.com>',
);
