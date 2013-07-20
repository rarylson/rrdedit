#!/usr/bin/env perl
# Test suit for rrdedit.pl program
#
# To undestant this program
# See: http://search.cpan.org/~mschwern/Test-Simple-0.98/lib/Test/Simple.pm

use 5.10.0;
use strict;
use warnings;

use File::Basename;
use File::Spec;
use Cwd;

use Data::Printer;

use Test::Simple qw(no_plan);

# Constants
our $RRDEDIT_NAME = 'rrdedit.pl';
our $TESTDIR_NAME = 'tmp';
our $TESTFILE_NAME = 'ping_rta.rrd';
our $TESTDIR = File::Basename::dirname( Cwd::abs_path($0) ) . '/' . $TESTDIR_NAME;
our $RRDEDIT = Cwd::abs_path( File::Spec->updir() ) . '/' . $RRDEDIT_NAME;
our $TESTFILE_COPY = File::Basename::dirname( Cwd::abs_path($0) ) . '/' . $TESTFILE_NAME;
our $TESTFILE = $TESTDIR . '/' . $TESTFILE_NAME;
our $TESTFILE_BAK = $TESTFILE . '.bak';

# SetUp and TearDown
sub setup {
    system "mkdir -p $TESTDIR";
    system "cp $TESTFILE_COPY $TESTFILE";
    system "cp $TESTFILE_COPY $TESTFILE_BAK";
    return;
}
sub teardown {
    system "rm -Rf $TESTDIR";
    return;
}

# Test help and usage
#
# To understand how to examine exit code
# See: http://perlmaven.com/how-to-exit-from-perl-script
# To understand the diff between backsticks and system
# See: http://stackoverflow.com/questions/799968/ \
#       whats-the-difference-between-perls-backticks-system-and-exec/800034#800034
setup();
my ($output, $output2) = ('', '');
# './rrdedit.pl' prints usage with 'Usage' and '<subcommand>' substring
$output = `$RRDEDIT | grep 'Usage' | grep '<subcommand>'`;
ok $output ne '', "'./$RRDEDIT_NAME' prints usage";
# './rrdedit.pl' exits with 1
`$RRDEDIT`;
ok (($? >> 8) == 1, "'./$RRDEDIT_NAME' exits 1");
# './rrdedit.pl --help' prints help with generic usage and 'GENERAL OPTIONS' 
$output = `$RRDEDIT --help | grep 'Usage' | grep '<subcommand>'`;
$output2 = `$RRDEDIT --help | grep 'GENERAL OPTIONS:'`;
ok (($output ne '' and $output2 ne ''), "'./$RRDEDIT_NAME --help' prints help");
# './rrdedit.pl --help' and './rrdedit.pl --usage' exits with 0
`$RRDEDIT --help`;
$output = $? >> 8;
`$RRDEDIT --usage`;
$output2 = $? >> 8;
ok (($output == 0 and $output2 == 0), "'./$RRDEDIT_NAME --help' and '--usage' exits 0");
$output = `$RRDEDIT print-ds --help | grep 'Usage' | grep \"[--full]\"`;
$output2 = `$RRDEDIT print-ds --help | grep 'full' | grep 'Print extended'`;
ok (($output ne '' and $output2 ne ''), "'./$RRDEDIT_NAME print-ds --help' works fine");
$output = `$RRDEDIT delete-rra --usage | grep 'id' | grep 'id2'`;
ok $output ne '', "'./$RRDEDIT_NAME delete-rra --usage' works fine";
teardown();

# Test print-ds method

