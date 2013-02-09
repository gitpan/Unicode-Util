package Unicode::Util;

use 5.008;
use strict;
use warnings;
use utf8;
use parent 'Exporter';
use Encode qw( encode find_encoding );
use Unicode::Normalize qw( normalize );
use Scalar::Util qw( looks_like_number );

our $VERSION = '0.08';
our @EXPORT_OK = qw(
    grapheme_length
    grapheme_chop
    grapheme_reverse
    grapheme_index
    grapheme_rindex
    grapheme_split
    graph_length graph_chop graph_reverse
    byte_length code_length code_chop
);
our %EXPORT_TAGS = (
    all    => \@EXPORT_OK,
    length => [qw( graph_length code_length byte_length )], # deprecated
);

use constant DEFAULT_ENCODING => 'UTF-8';
use constant IS_NORMAL_FORM   => qr{^ (?:NF)? K? [CD] $}xi;

sub grapheme_length (;$) {
    my ($str) = @_;
    $str = $_ unless defined $str;
    return undef unless defined $str;
    return scalar( () = $str =~ m{ \X }xg );
}

sub grapheme_chop (;\[$@%]) {
    my ($ref) = @_;
    $ref = \$_ unless defined $ref;

    if (ref $ref eq 'SCALAR') {
        $$ref =~ s{ ( \X ) \z }{}x;
        return $1;
    }
    elsif (ref $ref eq 'ARRAY') {
        return undef unless @$ref;

        for my $i ( 0 .. $#{$ref} ) {
            if ( $i < $#{$ref} ) {
                $ref->[$i] =~ s{ \X \z }{}x;
            }
            else {
                $ref->[$i] =~ s{ ( \X ) \z }{}x;
                return $1;
            }
        }
    }
    elsif (ref $ref eq 'HASH') {
        my $elems = keys %$ref;
        return undef unless $elems;

        my $count = 0;
        for my $str (values %$ref) {
            if (++$count < $elems) {
                $str =~ s{ \X \z }{}x;
            }
            else {
                $str =~ s{ ( \X ) \z }{}x;
                return $1;
            }
        }
    }
}

sub grapheme_reverse (;@) {
    my (@strings) = @_;
    return reverse @strings if wantarray;
    @strings = $_ unless @strings;
    return join '', map { reverse m{ \X }xg } reverse @strings;
}

# experimental functions

sub grapheme_index ($$;$) {
    my ($str, $substr, $pos) = @_;

    if (!looks_like_number($pos) || $pos < 0) {
        $pos = 0;
    }
    elsif ($pos > (my $graphs = grapheme_length($str))) {
        $pos = $graphs;
    }

    if ($str =~ m{ ^ ( \X{$pos} \X*? ) \Q$substr\E }xg) {
        return grapheme_length($1);
    }
    else {
        return -1;
    }
}

sub grapheme_rindex ($$;$) {
    my ($str, $substr, $pos) = @_;

    if (!looks_like_number($pos) || $pos < 0) {
        $pos = 0;
    }

    if ($pos) {
        # TODO: replace with grapheme_substr
        $str = substr $str, 0, $pos + ($substr ? 1 : 0);
    }

    if ($str =~ m{ ^ ( \X* ) \Q$substr\E }xg) {
        return grapheme_length($1);
    }
    else {
        return -1;
    }
}

sub grapheme_substr ($$;$$) :lvalue {
    my ($str, $offset, $length, $replacement) = @_;
    return;
}

sub grapheme_split (;$$) {
    my ($str) = @_;
    my @graphs = $str =~ m{ \X }xg;
    return @graphs;
}

# deprecated functions

sub graph_length {
    my ($str) = @_;
    utf8::upgrade($str);
    return scalar( () = $str =~ m{ \X }xg );
}

sub code_length {
    my ($str, $nf) = @_;
    utf8::upgrade($str);

    if ($nf && $nf =~ IS_NORMAL_FORM) {
        $str = normalize(uc $nf, $str);
    }

    return length $str;
}

sub byte_length {
    my ($str, $enc, $nf) = @_;
    utf8::upgrade($str);

    if ( !$enc || !find_encoding($enc) ) {
        $enc = DEFAULT_ENCODING;
    }

    if ($nf && $nf =~ IS_NORMAL_FORM) {
        $str = normalize(uc $nf, $str);
    }

    return length encode($enc, $str);
}

sub graph_chop {
    my ($str) = @_;
    utf8::upgrade($str);
    $str =~ s{ \X \z }{}x;
    return $str;
}

sub code_chop {
    my ($str) = @_;
    utf8::upgrade($str);
    chop $str;
    return $str;
}

sub graph_reverse {
    my ($str) = @_;
    utf8::upgrade($str);
    return join '', reverse $str =~ m{ \X }xg;
}

1;

__END__

=encoding UTF-8

=head1 NAME

Unicode::Util - Unicode grapheme-level versions of core Perl functions

=head1 VERSION

This document describes Unicode::Util v0.08.

=head1 SYNOPSIS

    use Unicode::Util qw( grapheme_length grapheme_reverse );

    # grapheme cluster ю́ (Cyrillic small letter yu, combining acute accent)
    my $grapheme = "ю\x{0301}";

    say length($grapheme);           # 2 (length in code points)
    say grapheme_length($grapheme);  # 1 (length in grapheme clusters)

    # Spın̈al Tap; n̈ = Latin small letter n, combining diaeresis
    my $band = "Spın\x{0308}al Tap";

    say scalar reverse $band;     # paT länıpS
    say grapheme_reverse($band);  # paT lan̈ıpS

=head1 DESCRIPTION

This module provides versions of core Perl string functions tailored to work on
Unicode grapheme clusters, which are what users perceive as characters, as
opposed to code points, which are what Perl considers characters.

=head1 FUNCTIONS

These functions are implemented using the C<\X> character class, which was
introduced in Perl v5.6 and significantly improved in v5.12 to properly match
Unicode extended grapheme clusters.  An example of a notable change is that
CR+LF <0x0D 0x0A> is now considered a single grapheme cluster instead of two.
For that reason, as well as additional Unicode improvements, Perl v5.12 or
greater is strongly recommended, both for use with this module and as a language
in general.

These functions may each be exported explicitly or by using the C<:all> tag for
everything.

=over

=item grapheme_length($string)

=item grapheme_length

Works like C<length> except the length is in number of grapheme clusters.

=item grapheme_chop($string)

=item grapheme_chop(@array)

=item grapheme_chop(%hash)

=item grapheme_chop

Works like C<chop> except it operates on the last grapheme cluster.

=item grapheme_reverse($string)

=item grapheme_reverse(@list)

=item grapheme_reverse

Works like C<reverse> except it reverses grapheme clusters in scalar context.

=back

=head1 TODO

C<grapheme_index>, C<grapheme_rindex>, C<grapheme_substr>

=head1 SEE ALSO

L<Unicode::GCString>, L<http://www.unicode.org/reports/tr29/>, L<Perl6::Str>,
L<http://perlcabal.org/syn/S32/Str.html>, L<String::Multibyte>

=head1 AUTHOR

Nick Patch <patch@cpan.org>

=head1 COPYRIGHT AND LICENSE

© 2011–2013 Nick Patch

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.