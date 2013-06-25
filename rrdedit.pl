#!/usr/bin/env perl
#
# Edit RRDs. Edit data sources and RRA from a RRD file.
#
# To understand this code
# See: http://perldoc.perl.org/Getopt/Long.html#Simple-options
#      http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/getopts/
#      http://search.cpan.org/~dougleith/RRD-Editor/lib/RRD/Editor.pm
#      http://oss.oetiker.ch/rrdtool/prog/RRDs.en.html
#

use Getopt::Long;
use RRD::Editor;
use RRDs;

# Usage
sub usage {
	print "Usage: $0 <subcommand> ...\n";
	print "       where: <subcommand> = add-ds|delete-ds|rename-ds|print-ds|\n" . 
          "                             add-rra|delete-rra|resize-rra|print-rra\n";
	print "For a complete help, use: $0 --help\n";
}

# Help
sub help {
    print "BAD NEWS: We not implemented 'help' yet. :(\n";
}

# Recovery RRD
# After some RRD::Editor operations, the RRD could be with a header
# inconsistent. For example, the delete_DS command may corrupt the size value of
# the header.
# In these cases, dump and restore the RRD recovery the RRD database. 
sub recovery {
    local($file) = $_[0];
    # XML file for recovery purpose
    my $file_xml = $file;
    $file_xml =~ s/\.rrd/\.xml/;
    RRDs::dump($file, $file_xml);
    unlink($file);
    RRDs::restore($file_xml, $file);
    unlink($file_xml);
}

# At least one argument
if ($#ARGV eq -1) {
    usage();
	exit 1;
} 

# Help and usage
my $help = '';
my $usage = '';
GetOptions ('help' => \$help, 'usage' => \$usage);
help() and exit 0 if $help;
usage() and exit 0 if $usage;

# Parse
@validcommands = ("add-ds", "delete-ds", "rename-ds", "print-ds", "add-rra", "delete-rra", "rename-rra", "print-rra");
my $command = $ARGV[0];
print "Invalid command name.\n" and usage() and exit 1 if ! grep $_ eq $command, @validcommands;

# Parse vars
my $file = '';
my $full = '';
my $names = '';
my $ignore = '';
my $old = '';
my $new = '';
# [DS:ds-name:DST:heartbeat:min:max] 
GetOptions ('file=s' => \$file, 'full' => \$full, 'names=s' => \@names, 'ignore' => \$ignore, 'old' => \$old, 'new' => \$new);
@names = split(/,/,join(',',@names));

# Error
print "Syntax error. You must pass one file as argument.\n" and usage() and
        exit 1 if !$file;

# Open RRD
my $rrd = RRD::Editor->new();
$rrd->open($file);

# Print data sources
if ($command eq "print-ds") {
    # Print
    my @dsnames = $rrd->DS_names();
    print "DS names: @dsnames\n";
    # Print full
    if ($full) {
        my @infos = split /\n/, $rrd->info();
        foreach $info (@infos) {
            print "$info\n" if $info =~ /^ds/;
        }
    }
	$rrd->close();
    exit 0;
}    

# Delete data sources
if ($command eq "delete-ds") {
    # Error
	print "Syntax error. You must pass one or more data source names to be deleted.\n" and usage() and
            exit 1 if !@names;
    # Deleting
    print "Deleting: @names...\n";
    foreach $dsname (@names) {
        # If ignore was setted, not die if a dsname does not exist.
        # See: http://affy.blogspot.com.br/p5be/ch13.htm
        eval{$rrd->delete_DS($dsname);};
        die "DS '$dsname' does not exists\n" if $@ and !$ignore;
    }
    $rrd->save();
    $rrd->close();
    # After RRD::Editor->delete_DS, the RRD header was inconsistent, with a wrong size.
    # So, recovery RRD usind dump+restore
    recovery($file);
    print "All DS deleted\n";
    exit 0;
}

# Print RRAs
if ($command eq "print-rra") {
    # Print
    my $num_rra = $rrd->num_RRAs();
    my $minstep = $rrd->minstep();
    print "Number of RRAs: $num_rra\n";
    print "Minimum step size: $minstep\n";
    # RRAs doesn't have names. They're indexed from 0 to num_RRAs()-1.
    # Print number of rows foreach RRA
    # See: http://search.cpan.org/~dougleith/RRD-Editor/lib/RRD/Editor.pm#num_RRAs
    foreach $i (0 .. $num_rra-1) {
        printf "RRA %s:\n\tStep: %s\n\tRows: %s\n", $i, $rrd->RRA_step($i), $rrd->RRA_numrows($i);
        my $totaltime = $rrd->RRA_step($i) * $rrd->RRA_numrows($i);
        printf "\tTotal time: %d seconds (%d hours)\n", $totaltime, $totaltime / 3600;
    }
    if ($full) {
        my @infos = split /\n/, $rrd->info();
        foreach $info (@infos) {
            print "$info\n" if $info =~ /^rra/;
        }
    }
	$rrd->close();
    exit 0;
}    

