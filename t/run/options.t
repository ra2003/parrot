#!perl
# Copyright (C) 2005-2010, Parrot Foundation.

=head1 NAME

t/run/options.t - test parrot command line options

=head1 SYNOPSIS

    % prove t/run/options.t

=head1 DESCRIPTION

Tests C<parrot> command line options.

=cut

use strict;
use warnings;
use lib qw( lib . ../lib ../../lib );

use Test::More tests => 42;
use Parrot::Config;
use File::Temp 0.13 qw/tempfile/;
use File::Spec;

my $PARROT = ".$PConfig{slash}$PConfig{test_prog}";

# looking at the help message
for my $help ('-h', '--help') {
    my $help_message = `$PARROT $help`;
    is( substr( $help_message, 0, 23 ), 'parrot [Options] <file>', "Start of $help message" );
    ok( index( $help_message, '-t --trace [flags]' ) > 0, '$help for --trace' );
}

# setup PIR files for tests below
my $first_pir_file  = create_pir_file('first');
my $second_pir_file = create_pir_file('second');

# executing a PIR file
is( `"$PARROT" "$first_pir_file"`,  "first\n",  'running first.pir' );
is( `"$PARROT" "$second_pir_file"`, "second\n", 'running second.pir' );

# Ignore further arguments
is( `"$PARROT" "$first_pir_file" "$second_pir_file"`, "first\n", 'ignore a pir-file' );
is( `"$PARROT" "$first_pir_file" "asdf"`,             "first\n", 'ignore nonsense' );

# redirect STDERR to avoid warnings
my $redir = '2>' . File::Spec->devnull();

# --pre-process-only
# This is just sanity testing
my $expected_preprocesses_pir = <<'END_PIR';

.macro 

.sub main :main

say "first" 

.end

END_PIR
for my $e ('-E', '--pre-process-only') {
    is( `"$PARROT" $e "$first_pir_file" $redir`, $expected_preprocesses_pir, "option $e" );
}

# Test the trace option
for my $t ('-t', '--trace') {
    is( `"$PARROT" $t "$first_pir_file" $redir`, "first\n", "option $t" );
    is( `"$PARROT" $t "$first_pir_file" "$second_pir_file" $redir`, "second\n", "option $t with flags" );
}

## test the -R & --runcore options
{
my $cmd;

## this test assumes these cores work on all platforms (a safe assumption)
for my $val (qw/ slow fast bounds trace /) {
    for my $opt ( '-R ', '--runcore ', '--runcore=' ) {
        $cmd = qq{"$PARROT" $opt$val "$second_pir_file" $redir};
        is( qx{$cmd}, "second\n", "<$opt$val> option)" ) or diag $cmd;
    }
}

for my $d8 ('-D 8', '--parrot-debug 8', '--parrot-debug=8') {
    $cmd = qq{"$PARROT" $d8 -R slow "$second_pir_file" $redir};
    is( qx{$cmd}, "second\n", "$d8 doesn't touch STDOUT" );

    $cmd = qq{"$PARROT" $d8 -R slow "$second_pir_file" 2>&1};
    like( qx{$cmd}, qr/Parrot VM: slow core/, "$d8 prints runcore name" );
}
}

# Test --runtime-prefix
like( qx{$PARROT --runtime-prefix}, qr/^.+$/, "--runtime-prefix" );

# TT #1797: check for warning error and mask off "did it crash?" bits
needs_an_argument('--gc-dynamic-threshold');

# GC nursery-size check for warning error and mask off "did it crash?" bits
needs_an_argument('--gc-nursery-size');

{
    my $output = qx{$PARROT --gc-nursery-size=51 2>&1 };
    my $exit   = $? & 127;
    like( $output, qr/maximum GC nursery size is 50%/,
                     '--gc-nursery-size max warning' );
    is( $exit, 0, '... and should not crash' );
}


# Test --leak-test
is( qx{$PARROT --leak-test "$first_pir_file"}, "first\n", '--leak-test' );

# clean up temporary files
unlink $first_pir_file;
unlink $second_pir_file;

sub create_pir_file {
    my $word = shift;

    my ( $fh, $filename ) = tempfile( UNLINK => 0, SUFFIX => '.pir', UNLINK => 1 );
    print $fh <<"END_PIR";

.macro println(word)
   say .word
.endm

.sub main :main
  .println( "$word" )
.end
END_PIR
    close $fh;

    return $filename;
}

# Check that an option checks for its argument
sub needs_an_argument {
    my $arg    = shift;
    my $output = qx{$PARROT $arg 2>&1 };
    my $exit   = $? & 127;
    like( $output, qr/$arg needs an argument/, "$arg needs argument warning" );
    is( $exit, 0, '... and should not crash' );
}


#make sure that VERSION matches the output of --version
open(my $version_fh, "<", "VERSION") or die "couldn't open VERSION: $!";
my $file_version = <$version_fh>;
chomp($file_version);
close($version_fh);
for my $version ('-V', '--version') {
    like( qx{$PARROT $version}, qr/.*${file_version}.*/, "VERSION matches $version" );
}

## GH #346 test remaining options

# TODO: Add tests for attached options
# Basically all long options
# See runcore tests for good way to do it

# TODO: Add tests for more options
# -I --include PATH
# -L --library PATH
# -X --dynext PATH
#    --hash-seed HEX
#    --help-debug
# -w --warnings
# -G --no-gc
# -h --gc ms2|gms|ms|inf
#    --gc-min-threshold
#    --gc-debug
#    --destroy-at-end (is this same as --leak-test?)
# -. --wait
# FILE  (.pasm, .pir, .pbc)

# These are IMCC options.  Add tests here or in t/compilers/imcc ?
# -d --imcc-debug HEX
# -v --verbose
# -o --output FILE
#        .pasm, .pbc, .o endings
#    --output-pbc
# -O --optimize INT
# -a --pasm
# -c --pbc
# -r --run-pbc
# -y --yydebug
# -p --profile (in docs/running.pod, not in --help)

# These IMCC options are tested here.  Move them?
# -E --pre-process-only

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4

#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
