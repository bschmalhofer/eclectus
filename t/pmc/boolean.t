#! ../../parrot
# Copyright (C) 2008, The Perl Foundation.
# $Id$

=head1 NAME

t/pmc/boolean.t - Boolean PMC

=head1 SYNOPSIS

    % perl t/harness t/pmc/boolean.t

=head1 DESCRIPTION

Tests C<EclectusBoolean> PMC.

=cut

.sub 'main' :main
    $P0 = loadlib "eclectus_group"

    .include "include/test_more.pir"
    plan(2)

    truth_tests()
.end

.sub truth_tests
    .local pmc true, false

    true = new 'EclectusBoolean'
    true = 1

    false = new 'EclectusBoolean'
    false = 0

    is(true, 1, "true EclectusBoolean is 1")
    is(false, "", "false EclectusBoolean is empty")
.end

# Local Variables:
#   mode: pir
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
