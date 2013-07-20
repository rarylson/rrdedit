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

# SetUp and TearDown
sub setup {
    system "mkdir -p $TESTDIR";
    system "cp $TESTFILE_COPY $TESTFILE";
    return;
}
sub teardown {
    system "rm -Rf $TESTDIR";
    return;
}

my ($output, $output2, $output3) = ('', '', '');

# Test help and usage
#
# To understand how to examine exit code
# See: http://perlmaven.com/how-to-exit-from-perl-script
# To understand the diff between backsticks and system
# See: http://stackoverflow.com/questions/799968/ \
#       whats-the-difference-between-perls-backticks-system-and-exec/800034#800034
say "Test help and usage";
setup();
# './rrdedit.pl' prints usage with 'Usage' and '<subcommand>' substring
$output = `$RRDEDIT | grep 'Usage' | grep '<subcommand>'`;
ok $output ne '', "'./$RRDEDIT_NAME' - usage";
# './rrdedit.pl' exits with 1
`$RRDEDIT`;
ok (($? >> 8) == 1, "'./$RRDEDIT_NAME' exits 1");
# './rrdedit.pl --help' prints help with generic usage and 'GENERAL OPTIONS' 
$output = `$RRDEDIT --help | grep 'Usage' | grep '<subcommand>'`;
$output2 = `$RRDEDIT --help | grep 'GENERAL OPTIONS:'`;
ok (($output ne '' and $output2 ne ''), "'./$RRDEDIT_NAME --help' - help");
# './rrdedit.pl --help' and './rrdedit.pl --usage' exits with 0
`$RRDEDIT --help`;
$output = $? >> 8;
`$RRDEDIT --usage`;
$output2 = $? >> 8;
ok (($output == 0 and $output2 == 0), "'./$RRDEDIT_NAME --help' and '--usage' exit value");
$output = `$RRDEDIT print-ds --help | grep 'Usage' | grep \"[--full]\"`;
$output2 = `$RRDEDIT print-ds --help | grep 'full' | grep 'Print extended'`;
ok (($output ne '' and $output2 ne ''), "'./$RRDEDIT_NAME print-ds --help' - subcommand help");
$output = `$RRDEDIT delete-rra --usage | grep 'id' | grep 'id2'`;
ok $output ne '', "'./$RRDEDIT_NAME delete-rra --usage' - subcommand usage";
$output = `$RRDEDIT print-ds | grep 'Usage' | grep 'print-ds'`;
`$RRDEDIT print-ds`;
$output2 = $? >> 8;
ok (($output ne '' and $output2 == 1), "'./$RRDEDIT_NAME print-ds' - subcommand usage with exit 1");
teardown();

# Test print-ds method
say "Test print-ds";
setup();
$output = `$RRDEDIT print-ds --file | grep 'Syntax error'`;
`$RRDEDIT print-ds --file`;
$output2 = $? >> 8;
ok (($output ne '' and $output2 == 1), "print-ds with syntax error");
$output = `$RRDEDIT print-ds --file $TESTFILE | grep 'data warn crit min'`;
ok $output ne '', "print-ds - general";
$output = `$RRDEDIT print-ds --file $TESTFILE --full`;
$output2 = 0;
$output2 = 1 if $output =~ /data warn crit min/ and $output =~ /ds\[data\]\.index/ 
        and $output =~ /ds\[data\]\.type = "GAUGE"/ and $output =~ /ds\[data\]\.last_ds = "0\.002558"/
        and $output =~ /ds\[min\]\.minimal_heartbeat = 600/;
ok $output2, "print-ds with '--full'";
teardown();

# Test delete-ds method
say "Test delete-ds";
setup();
$output = `$RRDEDIT delete-ds --file $TESTFILE --name max5`;
$output2 = $? >> 8;
$output3 = 0;
$output3 = 1 if $output =~ /'max5' does not exists/;
ok (($output2 == 1 and $output3 ne ''), "delete-ds with unknown ds printing error");
teardown();
setup();
`$RRDEDIT delete-ds --file $TESTFILE --name min`;
$output = `$RRDEDIT print-ds --file $TESTFILE | grep 'data warn crit' | grep -v 'min'`;
ok $output ne '', "delete-ds with single name";
teardown();
setup();
`$RRDEDIT delete-ds --file $TESTFILE --name min,warn`;
$output = `$RRDEDIT print-ds --file $TESTFILE | grep 'data crit' | grep -v 'min' | grep -v 'warn'`;
ok $output ne '', "delete-ds with two names";
teardown();
setup();
`$RRDEDIT delete-ds --file $TESTFILE --name min,max --ignore`;
$output = `$RRDEDIT print-ds --file $TESTFILE | grep 'data warn crit' | grep -v 'min\|max'`;
ok $output ne '', "delete-ds with '--ignore'";
teardown();

# Test print-rra method
say "Test print-rra";
setup();
$output = `$RRDEDIT print-rra --file $TESTFILE`;
$output2 = 0;
$output2 = 1 if $output =~ /Number of RRAs: 4/ and $output =~ /Minimum step size: 300/ 
        and $output =~ /Total time: 180000 seconds \(50 hours\)/;
ok $output2, "print-rra - general";
$output = `$RRDEDIT print-rra --file $TESTFILE --full`;
$output2 = 0;
$output2 = 1 if $output =~ /Number of RRAs: 4/ and $output =~ /Minimum step size: 300/ 
        and $output =~ /Total time: 180000 seconds \(50 hours\)/ 
        and $output =~ /rra\[0\]\.cf = "AVERAGE"/ and $output =~ /rra\[2\]\.pdp_per_row = 24/;
$output3 = 0;
$output3 = 1 if $output =~ /ds\[data\]\.index/;
ok (($output2 and not $output3), "print-rra with '--full'");
teardown();

# Test resize-rows-rra method
say "Test resize-rows-rra";
setup();
$output = `$RRDEDIT resize-rows-rra --file $TESTFILE --torows 1800 | grep 'Syntax error'`;
ok $output, "resize-rows-rra syntax error";
`$RRDEDIT resize-rows-rra --file $TESTFILE --id 1 --torows 800`;
$output = `$RRDEDIT print-rra --file $TESTFILE --full | grep 'rra\\[1\\]\\.rows = 800'`;
ok $output, "resize-rows-rra - single resize";
teardown();
setup();
`$RRDEDIT resize-rows-rra --file $TESTFILE --id 0 --torows 300`;
$output = `$RRDEDIT print-rra --file $TESTFILE --full`;
$output2 = 0;
$output2 = 1 if $output =~ /rra\[0\]\.rows = 300/;
($output3 = $output) =~ /rra\[0\]\.cur_row = (.*)/m;
$output3 = $1;
ok (($output2 ne '' and $output3 == 0), "resize-rows-rra with --torows smaller than " . 
        "the previous num rows");
teardown();
setup();
`$RRDEDIT resize-rows-rra --file $TESTFILE --id 0 --torows 300`;
`$RRDEDIT resize-rows-rra --file $TESTFILE --id 1 --torows 800`;
`$RRDEDIT resize-rows-rra --file $TESTFILE --id 2 --torows 1800`;
$output = `$RRDEDIT print-rra --file $TESTFILE --full`;
$output2 = 0;
$output2 = 1 if $output =~ /rra\[0\]\.rows = 300/ and $output =~ /rra\[1\]\.rows = 800/
        and $output =~ /rra\[2\]\.rows = 1800/;
ok $output2, "resize-rows-rra with many resizes";
teardown();
