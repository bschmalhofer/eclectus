#! perl

# Copyright (C) 2007-2009, The Perl Foundation.
# $Id$

# A wrapper for running scheme scripts with Eclectus

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More;

my ( $scheme_fn ) = @ARGV;


if ($^O eq 'MSWin32') {
    # 'petite' is Petite Chez Scheme
    # 7.4 is the current version
    my $petite_version = `petite --version 2>&1` || q{};
    my $has_petite = $petite_version =~ /^7.4/;

    if ( ! $has_petite ) {
        plan skip_all => 'petite 7.4 is needed for running this test';
    }
    else {
        exec 'petite', '--script', $scheme_fn;
    }
}
else {
    # 'gosh' is Gauche
    # 0.8 is the current version
    my $gauche_version = `gosh -V 2>&1` || q{};
    my $has_gauche = $gauche_version =~ m/  0\.8 # inexact version
                                         /xms;
    if ( ! $has_gauche ) {
        plan skip_all => 'gauche 0.8 is needed for running this test';
    }
    else {
        exec 'gosh', '-fcase-fold', '-I', '.',  '-l', 'gauche/prelude.scm', $scheme_fn;
    }
}

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
