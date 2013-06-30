#!/usr/bin/env perl
#
# Edit RRDs. Edit data sources and RRA from a RRD file.
#
# To understand this code
# See: http://perldoc.perl.org/Getopt/Long.html#Simple-options
#      http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/getopts/
#      http://search.cpan.org/~dougleith/RRD-Editor/lib/RRD/Editor.pm
#      http://oss.oetiker.ch/rrdtool/prog/RRDs.en.html

use Getopt::Long;
use POSIX;
use RRD::Editor;
use RRD::Tweak;
use RRDs;
use Math::Interpolator::Robust;
use Math::Interpolator::Knot;

use Data::Printer;

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
    my $file = $_[0];
    
    # XML file for recovery purpose
    my $file_xml = $file;
    $file_xml =~ s/\.rrd/\.xml/;
    RRDs::dump($file, $file_xml);
    unlink($file);
    RRDs::restore($file_xml, $file);
    unlink($file_xml);
}

# Get total time of a RRA
sub totaltime_rra {
    my ($file, $id) = @_;
    my $rrd = RRD::Editor->new();

    $rrd->open($file);
    my $totaltime = $rrd->RRA_step($id) * $rrd->RRA_numrows($id);
    $rrd->close(); 

    return $totaltime;
}

# Change RRA from a RRD
# Create a new RRD with a RRA cheged by a new RRA
sub change_rra {
    my ($file, $new_file, $old_id, $new_step, $new_rows, $new_rra_string) = @_;
    
    my $rrd_editor = RRD::Editor->new();
    $rrd_editor->open($file);
    my $rrd_tweak = RRD::Tweak->new();
    $rrd_tweak->load_file($file);

    # Get definition string for all datasources
    $rrd_editor->open($file);
    my $ds_num = scalar $rrd_editor->DS_names();
    my @ds_string;
    for $i (0 .. $ds_num - 1) {
        push @ds_string, $rrd_tweak->ds_descr($i);
    }

    # Get definition string for all RRAs
    my $rra_num = $rrd_editor->num_RRAs();
    my @rra_string;
    for $i (0 .. $rra_num - 1) {
        # Not get definition of the old RRA
        if ($i ne $old_id) {
            push @rra_string, [$i, $rrd_editor->RRA_step($i), $rrd_editor->RRA_numrows($i), $rrd_tweak->rra_descr($i)];
        }
    }
    # Push definition of the new RRA
    push @rra_string, [$rra_num, $new_step, $new_rows, $new_rra_string];
    # Sort RRA by precision (step)
    @rra_string = sort {$a->[1] <=> $b->[1]} @rra_string;

    # Calculate new RRD string
    # To undestand what is a map
    # See: http://www.misc-perl-info.com/join-aoa.html
    my $minstep = $rrd_editor->minstep();
    # Start is calculated by: endtime - max(rra_step * rra_rows); 
    my $max_totaltime = (sort {$b <=> $a} map ($_->[1] * $_->[2], @rra_string) )[0];
    my $start_time = $rrd_editor->last() - $max_totaltime;
    my $rrd_new_string = sprintf "--start %s --step %s %s %s", $start_time, $minstep, join(" ", @ds_string), 
            join(" ", map ($_->[3], @rra_string));

    # Create new RRD
    my $rrd_editor_new = RRD::Editor->new();
    $rrd_editor_new->create($rrd_new_string);
    $rrd_editor_new->save( "$file.new" );
    $rrd_editor_new->close();
}

# At least one argument
if (scalar(@ARGV) eq 0) {
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
    my $orig_time = $orig_step * $orig_rows;
    my $new_time = $new_rows * $tostep;
    my $newrra_string = "RRA:$orig_type:$orig_xff:$step_relative:$new_rows";

    # Error
    print "Invalid value error. The step must be a multiple of the minimum step: $minstep\n" and
            exit 1 if $step_relative =~ /\D/;

    # With add (--with-add)
    # Add new RRAs, and a 'at' task to delete the old ones
    if ($with_add) {
        
        # Adding new RRA
        print "Adding new RRA: [$newrra_string]...\n";
        $rrd->add_RRA($newrra_string);
        $rrd->save();
        $rrd->close();
        printf "New RRA added\n";
        # Time changed. New rows was ceilled
        printf "Total time changed: from $orig_time seconds to $new_time\n" if $orig_time ne $new_time;
        
        # Generate 'at' command to schedule the delete operation
        # 'at' is a linux tool that permits executing commands at a specified time.
        # See: http://linux.die.net/man/1/at
        my $time_hours =  $orig_time / 3600;
        print "Old RRA (id=$id) expires in $time_hours hours.\n";
        my $script_name = $0;
        $script_name =~ s{./}{};
        my $at_string = sprintf "%s/%s delete-rra --file %s --id %s", $ENV{PWD}, $script_name, $file, $id;
        my $script_string = "echo \"$at_string\" | at now + $time_hours hours";
        
        # Only print the 'at' command
        if (! $schedule) {
            print "Run this command to delete this RRA after it's no more necessary:\n"; 
            printf "    $script_string\n";
        }
        # Schedule the delete operation (--schedule)
        else {
            print "Scheduling delete operation: $at_string\n";
            `$script_string`;
        }

        $rrd->save();
        $rrd->close();
        exit 0;
    }

    # Other algorithms
    if ($with_step or $with_interpolation) {
        
        # We need to create a new RRD with the new RRA and insert the new points in it, because 
        # "you MUST always feed values in chronological order. Stuff breaks if you don't, so don't.".
        # See: http://ds9a.nl/rrd-mini-howto/cvs/rrd-mini-howto/output/rrd-mini-howto-1.html#ss1.3
        #      https://lists.oetiker.ch/pipermail/rrd-users/2012-June/018661.html 
        
        # Create the new RRA
        print "Creating new RRD structure\n";
        my $new_file = $file;
        $new_file =~ s/\.rrd/_new.rrd/; 
        change_rra($file, $new_file, $id, $tostep, $new_rows, $newrra_string);
        print "New RRD structure created\n";
        # Time changed. New rows was ceilled
        printf "RRA time changed: from $orig_time seconds to $new_time\n" if $orig_time ne $new_time;

        # Create RRA array and sort by precision (step)
        my @rra_sort;
        my $num_rra = $rrd->num_RRAs();
        my $end_time = $rrd->last();
        
        for $i (0 .. $num_rra - 1) {
            push @rra_sort, [$i, $rrd->RRA_step($i), $rrd->RRA_numrows($i)];
        }
        @rra_sort = sort {$a->[1] <=> $b->[1]} @rra_sort;

        # Foreach RRA, fetch data
        print "Generating points\n";
        my %data_hash = ();
        my @dsnames = $rrd->DS_names();
        for $i (0 .. $num_rra - 1) {
            my $iter_id = $rra_sort[$i]->[0];
            my $iter_step = $rra_sort[$i]->[1];
            my $iter_rows = $rra_sort[$i]->[2];
            my $iter_time = $iter_step * $iter_rows;
            my $start_time = $end_time-$iter_time;

            # RRDs::fetch is better than RRD::editor->fetch
            # Notes: $dsnames is a pointer to an array; $data is a pointer to an array that all elements also
            #        are a ponter to an array
            # See: http://oss.oetiker.ch/rrdtool/prog/RRDs.en.html
            my ($iter_start, $real_step, undef, $data) = RRDs::fetch($file, "AVERAGE", "-r", $iter_step, "-s", $start_time, 
                    "-e", $end_time-$iter_step);

            # Insert points into the data hash
            # Because the fetchs used RRAs in a sorted way, data hash always is setted with the most precise value
            # To understant what is a hash
            # See: http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/hash/
            my $insert_time = $iter_start; 
            foreach $data_line (@$data) {
                $data_hash{$insert_time} = $data_line;
                $insert_time += $iter_step; 
            }
        }
        print "Points generated\n";

        # Interpolation is only needed when new step is smaller then orig step. That is, the new rra is more precise
        if ($tostep > $orig_step) {
            # With step (--with-step)
            # Insert new points using the step function
            if ($with_step) {
                 
            }
            # With interpolation (--with-interpolation)
            # Insert new points using a smooth interpolation
            elsif ($with_interpolation) {
                print "Not yet implemented :(\n" and exit 1;
            }
        }

        # Save data in the new RRD
        $rrd_new = RRD::Editor->new();
        $rrd_new->open($new_file);
        my $update_string = '';
        foreach $timestamp (keys %data_hash) {
            my $temp_data = %data_hash{$timestamp};
            p $temp_data;
            @iter_data = @$temp_data;
            # TODO We need to map undefined values to 'U'
            $update_string = sprintf "%d:%s", $timestamp, join(":", @iter_data);
            # $rrd_new->update($update_string);
            p $update_string;
            exit;
        }
            
        $rrd_new->save();
        $rrd_new->close();
        $rrd->close();
        # TODO Overwrite the old RRD
        exit 0;
    }
    
}

# Command not implemented yet
print "BAD NEWS. We not implemented this feature yet.\n";
exit 0;

