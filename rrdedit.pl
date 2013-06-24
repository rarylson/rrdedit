#!/usr/bin/env perl
#
# Remove data sources from a file
#
# Note: To install rrdtool bind for python:
#     apt-get install libcairo2-dev libpango1.0-dev libglib2.0-dev libxml2-dev librrd-dev
#     pip install python-rrdtool
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
my $names = '';
my $ignore = '';
my $old = '';
my $new = '';
# [DS:ds-name:DST:heartbeat:min:max] 
GetOptions ('file=s' => \$file, 'names=s' => \@names, 'ignore' => \$ignore, 'old' => \$old, 'new' => \$new);
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
    foreach my $dsname (@names) {
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


