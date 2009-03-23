=head1 NAME

t/pmc/boolean.t - Boolean PMC

=head1 SYNOPSIS

    % perl t/harness t/pmc/boolean.t

=head1 DESCRIPTION

Tests C<EclectusBoolean> PMC.

=cut

.sub 'main' :main
    $P0 = loadlib "eclectus_group"
    unless $P0 goto LOADING_FAILED

    .include "test_more.pir"

    plan(6)

    truth_tests()
    type_tests()
    exit 0

  LOADING_FAILED:
    say "# eclectus_group could not be loaded"

.end

.sub truth_tests
    .local pmc true, false

    true = new 'EclectusBoolean'
    true = 1

    false = new 'EclectusBoolean'
    false = 0

    .local string s1
    s1 = false
    say false
    say true
    say s1
    s1 = true
    say s1

    is(true, 1, "true EclectusBoolean is 1")
    is(false, 0, "false EclectusBoolean is 0")

    is(true, "#t", "false EclectusBoolean is #t")
    is(false, "#f", "false EclectusBoolean is #f")
.end

.sub type_tests
    .local pmc true, false
    .local string true_type, false_type
    true = new 'EclectusBoolean'
    true = 1
    true_type = typeof true
    is(true_type, "EclectusBool", "type of true")

    false = new 'EclectusBoolean'
    false = 0
    false_type = typeof false
    is(false_type, "EclectusBool", "type of false")
.end

# Local Variables:
#   mode: pir
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
