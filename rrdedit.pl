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
	print "Usage: $0 --file filename.rrd --delete dsname1 [--delete dsname2 ...] [--ignore]\n";
	print "   or: $0 --file filename.rrd --delete dsname1,dsname2,... [--ignore]\n";
	print "   or: $0 --file filename.rrd --print\n";
}
if ($#ARGV eq -1) {
    usage();
	exit 1;
} 

# Parsing
my $file = '';
my $delete = '';
my $ignore = '';
my $help = '';
my $print = '';
GetOptions ('help' => \$help, 'print' => \$print, 'file=s' => \$file, 'delete=s' => \@delete, 'ignore' => \$ignore);
@delete = split(/,/,join(',',@delete));
usage() and exit 0 if $help;

# Error while parsing
if ($print and !$file) {
	print "Syntax error. You must pass one file to print dsnames.\n";
	usage();
	exit 1;
} elsif (!$print and (!$file or !@delete)) {
	print "Syntax error. You must pass one file and one or more dsnames to be deleted.\n";
	usage();
	exit 1;
}

# Open RRD
my $rrd = RRD::Editor->new();
$rrd->open($file);

# Print
if ($print) {
	my @dsnames = $rrd->DS_names();
	print "DS names: @dsnames\n";
	exit 0;
}

# Deleting DS from RRD
print "Deleting DS: @delete\n";
foreach my $dsname (@delete) {
	# Error handling
	# See: http://affy.blogspot.com.br/p5be/ch13.htm
	eval{$rrd->delete_DS($dsname);};
	die "DS '$dsname' does not exists\n" if $@ and !$ignore;
}
$rrd->save();
$rrd->close();

# XXX There is a BUG in delete_DS that not update the size header.
#     Dump and restore the RRD will correct the size field.
my $file_xml = $file;
$file_xml =~ s/\.rrd/\.xml/;
RRDs::dump($file, $file_xml);
unlink($file);
RRDs::restore($file_xml, $file);
unlink($file_xml);

print "All DS deleted\n";

