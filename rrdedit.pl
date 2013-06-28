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
# TODO Consider change array lenght to "scalar @array"

use Getopt::Long;
use POSIX;
use RRD::Editor;
use RRDs;
use Math::Interpolator::Robust;
use Math::Interpolator::Knot;

# Usage
sub usage {
	print "Usage: $0 <subcommand> ...\n";
	print "       where: <subcommand> = add-ds|delete-ds|rename-ds|print-ds|\n" . 
          "                             add-rra|delete-rra|resize-rows-rra|resize-step-rra|print-rra\n";
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
@validcommands = ("add-ds", "delete-ds", "rename-ds", "print-ds", "add-rra", "delete-rra", "resize-rows-rra", 
        "resize-step-rra", "print-rra");
my $command = $ARGV[0];
print "Invalid command name.\n" and usage() and exit 1 if ! grep $_ eq $command, @validcommands;

# Parse vars
my $file = '';
my $full = '';
my $name = '';
my $names = '';
my $ignore = '';
my $old = '';
my $new = '';
my $string = '';
my $id = '';
my $ids = '';
my $torows = '';
my $tostep = '';
my $with_add = '';
my $with_step = '';
my $with_interpolation = '';
my $schedule = '';
GetOptions ('file=s' => \$file, 'full' => \$full, 'name=s' => \$name, 'ignore' => \$ignore, 'old=s' => \$old, 'new=s' => \$new, 
        'id=s' => \$id, 'torows=i' => \$torows, 'tostep=i' => \$tostep, 'with-add' => \$with_add, 'with-step' => \$with_step, 
        'with-interpolation' => \$with_interpolation, 'schedule' => \$schedule);
@names = split(/,/,$name);
@ids = split(/,/,$id);


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
    # After RRD::Editor->delete_DS, the RRD header can be inconsistent, with a wrong size.
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
    # Print full
    if ($full) {
        my @infos = split /\n/, $rrd->info();
        foreach $info (@infos) {
            print "$info\n" if $info =~ /^rra/;
        }
    }
	$rrd->close();
    exit 0;
}    

# Resize RRAs - Rows
if ($command eq "resize-rows-rra") {
    # This command changes only the row value and mantein the same step. Obviously, the period is also scaled.
    # Example: If the number of rows is duplicated, the period is duplicated too.

    # Error
	print "Syntax error. You must pass one id and the new number of rows.\n" and usage() and
            exit 1 if !$id or !$torows;

    my $orig_rows = $rrd->RRA_numrows($id);

    # Resize 
    print "Resizing RRA $id from $orig_rows to $torows...\n";
    $rrd->resize_RRA($id, $torows);
    $rrd->save();
    $rrd->close();
    print "Number of rows changed\n";
    # TODO - Test if it's needed to use recovery.
    exit 0;
}

# Resize RRAs - Step
if ($command eq "resize-step-rra") {
    # This command changes the step and row values to mantein the same period.
    # Example: If the step is divided by two, the number of rows is duplicated
    #
    # According to RRD::Editor, "changing the step size is hard as it would require resampling the data stored in the RRA".
    # So, they "leave this 'to do'".
    # See: http://search.cpan.org/~dougleith/RRD-Editor/lib/RRD/Editor.pm#RRA_step
    #
    # How can we implement this?
    # 3 algothims: with-add, with-step or with-interpolation
    # See: RRA_STEP.md

    # Error
	print "Syntax error. You must pass one id and the new step.\n" and usage() and
            exit 1 if !$id or !$tostep;
    $with_add = 1 if !$with_add and !$with_step and !$with_interpolation;
    print "Syntax error. You must select only one algorithm.\n" and usage() and
            exit 1 if ($with_add and $with_step) or ($with_add and $with_interpolation) or 
            ($with_step and $with_interpolation);
    
    # New RRA
    my $orig_step = $rrd->RRA_step($id);
    my $orig_rows = $rrd->RRA_numrows($id);
    my $orig_xff = $rrd->RRA_xff($id);
    my $orig_type = $rrd->RRA_type($id);
    my $minstep = $rrd->minstep();
    my $step_relative = $tostep / $minstep;
    my $new_rows = $orig_step * $orig_rows / $tostep;
    # Round new_rows when the result is not integer
    $new_rows = ceil($new_rows);
    my $newrra_string = "RRA:$orig_type:$orig_xff:$step_relative:$new_rows";

    # Error
    print "Invalid value error. The step must be a multiple of the minimum step: $minstep\n" and
            exit 1 if $step_relative =~ /\D/;

    # With add (--with-add)
    # Add new RRAs, and a 'at' task to delete the old ones
    if ($with_add) {
        
        # Add RRA
        print "Adding new RRA: [$newrra_string]...\n";
        $rrd->add_RRA($newrra_string);
        $rrd->save();
        $rrd->close();
        printf "New RRA added\n";
        # Time changed. New rows was ceilled
        my $orig_time = $orig_step * $orig_rows;
        my $new_time = $new_rows * $tostep;
        printf "Total time changed: from $orig_time seconds to $new_time\n" if $orig_time ne $new_time;
        
        # Generate 'at' command
        my $time_hours =  $orig_time / 3600;
        print "Old RRA (id=$id) expires in $time_hours hours.\n";
        my $script_name = $0;
        $script_name =~ s{./}{};
        my $at_string = sprintf "%s/%s delete-rra --file %s --id %s", $ENV{PWD}, $script_name, $file, $id;
        my $script_string = "echo \"$at_string\" | at now + $time_hours hours";
        
        # Only print the command to schedule the delete operation
        if (! $schedule) {
            print "Run this command to delete this RRA after it's no more necessary:\n"; 
            printf "    $script_string\n";
        }
        # Schedule delete operation
        else {
            print "Scheduling delete operation: $at_string\n";
            `$script_string`;
        }
    }


    # Algorithm 2 - With interpolation
    #my $endtime = $rrd->last();
    #my $orig_step = $rrd->RRA_step($id);
    #my $orig_rows = $rrd->RRA_numrows($id);
    #my $interval = $orig_step * $orig_rows;

    # RRDs::fetch is much better than RRD::editor->fetch
    # dsnames is a pointer to an array
    # data is a pointer to an array of pointer to array
    #my ($start,$step,$dsnames,$data) = RRDs::fetch($file, "AVERAGE", "-r", "$orig_step", "-s", "$endtime-$interval", "-e", "$endtime");
    
    #my @knots = '';
    

    # Create the knots for interpolator
    #foreach $line (@$data) {
    #    print "@$line\n";
    #    foreach $i (0 .. scalar @$line - 1) {
    #       print $i; 
    #    }
    #}

    exit 0;
}

# Command not implemented yet
print "BAD NEWS. We not implemented this feature yet.\n";
exit 0;

