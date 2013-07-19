#!/usr/bin/env perl
#
# Edit RRDs. Edit data sources and RRAs.
#
# To understand this code
# See: http://perldoc.perl.org/Getopt/Long.html#Simple-options
#      http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/getopts/
#      http://search.cpan.org/~dougleith/RRD-Editor/lib/RRD/Editor.pm
#      http://oss.oetiker.ch/rrdtool/prog/RRDs.en.html

use 5.10.0;
use strict;
use warnings;

use Getopt::Long;
use POSIX;
use Scalar::Util::Numeric;
use RRD::Editor;
use RRD::Tweak;
use RRDs;
use Math::Interpolator::Robust;
use Math::Interpolator::Knot;

use Data::Printer;
use Time::HiRes;

# Version and author
our $VERSION = '1-beta';
our $YEAR = '2013';
our $AUTHOR = 'Rarylson Freitas';
our $AUTHOR_EMAIL = 'rarylson@vialink.com.br';

# ENV vars
# DEBUG => Print debug info
# DEBUG_TIME => Print exec time info

# DEBUG TIME
my $start_run = Time::HiRes::time();

# Usage
sub usage {
    my $usage_command = '';
    my $from_help = 0;
    my $usage_string = '';

    # Usage for a specific command?
    $usage_command = $_[0] if scalar(@_) >= 1;
    # Usage called from help
    $from_help = $_[1] if scalar(@_) == 2;

    # To undestand the "EOF"
    # See: http://perlmaven.com/here-documents

    # Generic usage
    if ($usage_command eq '') {
        ($usage_string = <<"        EOF") =~ s/^ {12}//gm;
            Usage: $0 <subcommand> ...
                   where: <subcommand> = add-ds|delete-ds|rename-ds|print-ds|add-rra|
                                         delete-rra|resize-rows-rra|resize-step-rra|print-rra
        EOF
    }
    # 'print-ds' usage
    elsif ($usage_command eq 'print-ds') {
        $usage_string = "Usage: $0 print-ds --file <filename> [--full]\n";
    }
    # 'add-ds' usage
    elsif ($usage_command eq 'add-ds') {
        $usage_string = "Usage: $0 add-ds --file <filename> --string <dsstring>\n";
    }
    # 'delete-ds' usage
    elsif ($usage_command eq 'delete-ds') {
        $usage_string = "Usage: $0 delete-ds --file <filename> --name <name1>[,<name2>,...] [--ignore]\n";
    }
    # 'rename-ds' usage
    elsif ($usage_command eq 'rename-ds') {
        $usage_string = "Usage: $0 rename-ds --file <filename> --old <oldname> --new <newname>\n";
    }
    # 'print-rra' usage
    elsif ($usage_command eq 'print-rra') {
        $usage_string = "Usage: $0 print-rra --file <filename> [--full]\n";
    }
    # 'add-rra' usage
    elsif ($usage_command eq 'add-rra') {
        $usage_string = "Usage: $0 add-rra --file <filename> --string <rrastring>\n";
    }
    # 'delete-rra' usage
    elsif ($usage_command eq 'delete-rra') {
        $usage_string = "Usage: $0 delete-rra --file <filename> --id <id1>[,<id2>,...]\n";
    }
    # 'resize-rows-rra' usage
    elsif ($usage_command eq 'resize-rows-rra') {
        $usage_string = "Usage: $0 resize-rows-rra --file <filename> --id <id> --torows <newrows>\n";
    }
    # 'resize-step-rra' usage
    elsif ($usage_command eq 'resize-step-rra') {
        ($usage_string = <<"        EOF") =~ s/^ {12}//gm;
            Usage: $0 resize-step-rra --file <filename> --id <id> --tostep <newstep> 
                   [--with-add|--with-step|--with-interpolation] [--schedule]
        EOF
    }
    # Error - Invalid command
    # Using die instead of 'say' when occours an logic error intead of a user input error
    # See: http://perlmaven.com/die
    #      http://perlmaven.com/writing-to-files-with-perl
    else {
        die "Usage from unknown command";
    }

    # Add help if it isn't called from help
    if ($from_help == 0) {
        print $usage_string;
        if ($usage_command eq '') {
            say "For help: $0 --help";
        } else {
            say "For help: $0 $usage_command --help";
        }
    }
    # If called from help, return a string
    else {
        return $usage_string;
    }
    return;
}

# Help
sub help {
    my $help_command = '';

    # Help for a specific command?
    $help_command = $_[0] if scalar(@_) == 1;

    # Header
    (my $help_header = <<"    EOF") =~ s/^ {8}//gm;
        $0 - v$VERSION - $AUTHOR <$AUTHOR_EMAIL>

        Command line tool that edit RRDs, like add/remove DS and add/remove/resize RRAs.
        It uses the RRD::Editor and RRDs perl modules.
    EOF

    # Usage
    my $help_usage = usage($help_command, 1);
    
    my $help_string = '';
    # Generic help
    if ($help_command eq '') {

        # Other usage strings
        my $usage_print_ds = usage('print-ds', 1);
        my $usage_add_ds = usage('add-ds', 1);
        my $usage_delete_ds = usage('delete-ds', 1);
        my $usage_rename_ds = usage('rename-ds', 1);
        my $usage_print_rra = usage('print-rra', 1);
        my $usage_add_rra = usage('add-rra', 1);
        my $usage_delete_rra = usage('delete-rra', 1);
        my $usage_resize_rows_rra = usage('resize-rows-rra', 1);
        my $usage_resize_step_rra = usage('resize-step-rra', 1);

        # Indent multiple-lines usage strings
        # Only indent lines after the first line
        # TODO Find a better solution 
        $usage_resize_step_rra =~ s/^(.*)$/                    $1/gm;
        $usage_resize_step_rra =~ s/^ {20}//;

        # Help string
        ($help_string = <<"        EOF") =~ s/^ {12}//gm;
            GENERAL OPTIONS:
                
                --help: Print this help
                --usage: Print the usage

            COMMANDS:

                print-ds
                    
                    Print information about all datasources of an RRD

                    $usage_print_ds
                add-ds

                    Add one datasource in an RRD

                    $usage_add_ds
                delete-ds

                    Delete one or more datasources from an RRD

                    $usage_delete_ds
                rename-ds

                    Rename a datasource of an RRD

                    $usage_rename_ds
                print-rra

                    Print information about all RRAs of an RRD
                
                    $usage_print_rra
                add-rra

                    Add one RRA in an RRD

                    $usage_add_rra
                delete-rra

                    Delete one or more RRA from an RRD

                    $usage_delete_rra
                resize-rows-rra

                    Resize the number of rows of an RRA of an RRD.
                    The step will be the same. The time will be resized according with the new number of rows.

                    $usage_resize_rows_rra
                resize-step-rra

                    Resize the step of an RRA of an RRD.
                    The time will be the same. The number of rows will be resized to maintain the time constant.

                    $usage_resize_step_rra
            COMMAND HELP:

                Usage: $0 <subcommand> --help
        EOF
    }
    # 'print-ds' help
    elsif ($help_command eq 'print-ds') {
        # Help string
        ($help_string = <<"        EOF") =~ s/^ {12}//gm;
            OPTIONS:
                
                --file: Name of the RRD file
                --full: Print extended informations 
        EOF
    }
    # TODO Implement help
    else {
        die "Help not implemented for command";
    }
    
    # Print help
    say $help_header;
    say $help_usage;
    say $help_string;
    
    return;
}

# Recovery RRD
# After some RRD::Editor operations, the RRD could be with a header
# inconsistent. For example, the delete_DS command may corrupt the size value of
# the header.
# In these cases, dump and restore the RRD will recovery the RRD database. 
sub recovery {
    my $file = $_[0];
    # XML file for recovery purpose
    (my $file_xml = $file) =~ s/\.rrd/\.xml/;
    RRDs::dump($file, $file_xml);
    unlink($file);
    RRDs::restore($file_xml, $file);
    unlink($file_xml);
    return;
}

# Change RRA from a RRD
# Create a new RRD with a RRA changed by a new RRA
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
    foreach my $i (0 .. $ds_num - 1) {
        push @ds_string, $rrd_tweak->ds_descr($i);
    }

    # Get definition string for all RRAs
    my $rra_num = $rrd_editor->num_RRAs();
    my @rra_string;
    foreach my $i (0 .. $rra_num - 1) {
        # Not get definition of the old RRA
        if ($i ne $old_id) {
            push @rra_string, [$i, $rrd_editor->RRA_step($i), $rrd_editor->RRA_numrows($i), $rrd_tweak->rra_descr($i)];
        }
    }
    # Push definition of the new RRA
    push @rra_string, [$rra_num, $new_step, $new_rows, $new_rra_string];
    # Sort RRA by precision (step)
    # Using the '<=>' because we are performing a numeric comparison
    # See: http://perlmaven.com/sorting-arrays-in-perl
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
    $rrd_editor_new->save($new_file);
    $rrd_editor_new->close();

    # Recovery new RRD
    recovery($new_file);
    return;
}

# Update a RRD using cache
# Concat the new update string into the cache array
# If the total number of cached updates reaches the max value, then flush the cache
#
# RRD:Editor->update flushs to disk and closes the file descriptor. There is no cache and it's slow.
# See: https://rt.cpan.org/Public/Bug/Display.html?id=86596
# Although RRD already has a lot of I/O performance improvements (http://oss.oetiker.ch/rrdtool-trac/wiki/TuningRRD),
# the write operation has some header calculation overhead.
# See: http://net.doit.wisc.edu/~dwcarder/rrdcache/
# So, we are using RRDs::update and cache.
# To understand how to pass many args in perl
# See: http://www.cs.cf.ac.uk/Dave/PERL/node61.html
# Note: If you need more performance, use the rrdcached deamon
#       See: http://oss.oetiker.ch/rrdtool/doc/rrdcached.en.html           
my $CACHE_MAX = 1024;
my @update_cache_array = ();
my $update_cache_count = 0;
sub update_cache_rrd {
    my ($file, $update_string) = @_;
    # Add string to cache
    push @update_cache_array, $update_string;
    $update_cache_count++;
    # Flush if it's needed
    update_flush_rrd($file) if $update_cache_count == $CACHE_MAX;
    return;
}
sub update_flush_rrd {
    my ($file) = @_;
    # Return if it's already empty
    return if scalar(@update_cache_array) == 0;
    # Flush to disk
    RRDs::update($file, @update_cache_array);
    @update_cache_array = ();
    $update_cache_count = 0;
    return;
}

# At least one argument
if (scalar(@ARGV) == 0) {
    usage();
	exit 1;
} 

# Commands
my @validcommands = ("add-ds", "delete-ds", "rename-ds", "print-ds", "add-rra", "delete-rra", 
        "resize-rows-rra", "resize-step-rra", "print-rra");
# Parse command
my $command = $ARGV[0];

# No command
if (not grep $_ eq $command, @validcommands) {
    # Generic options (help and usage)
    my $help = '';
    my $usage = '';
    GetOptions ('help' => \$help, 'usage' => \$usage);
    help() and exit 0 if $help;
    usage() and exit 0 if $usage;
    # Invalid command
    say "Invalid subcommand name" and usage() and exit 1;
}

# At least two arguments
# If was set only the subcommand, print usage
if (scalar(@ARGV) == 1) {
    usage($command);
	exit 1;
} 


# Vars
#
# Generic
my ($usage, $help, $file) = ('', '', '');
# Print
my $full = '';
# DS
my ($name, $names) = ('', '');
# DS Delete
my ($ignore, $old, $new) = ('', '', '');
# RRA
my ($id, $ids) = ('', '');
# RRA resize row
my $torows = '';
# RRA resize step
my ($tostep, $with_add, $with_step, $with_interpolation, $schedule) = ('', '', '', '', '');
# Parsing vars
GetOptions ('usage' => \$usage, 'help' => \$help, 'file=s' => \$file, 'full' => \$full, 'name=s' => \$name, 
        'ignore' => \$ignore, 'old=s' => \$old, 'new=s' => \$new, 'id=s' => \$id, 'torows=i' => \$torows, 
        'tostep=i' => \$tostep, 'with-add' => \$with_add, 'with-step' => \$with_step, 
        'with-interpolation' => \$with_interpolation, 'schedule' => \$schedule);
my @names = split(/,/,$name);
my @ids = split(/,/,$id);


# Help and usage of a command
help($command) and exit 0 if $help;
usage($command) and exit 0 if $usage;

# Error
say "Syntax error. You must pass one file as argument." and usage() and
        exit 1 if not $file;

# Open RRD
my $rrd = RRD::Editor->new();
$rrd->open($file);

# Print data sources
if ($command eq "print-ds") {
    # Print
    my @dsnames = $rrd->DS_names();
    say "DS names: @dsnames";
    # Print full
    if ($full) {
        my @infos = split /\n/, $rrd->info();
        foreach my $info (@infos) {
            say $info if $info =~ /^ds/;
        }
    }
	$rrd->close();
    exit 0;
}    

# Delete data sources
if ($command eq "delete-ds") {
    # Error
	say "Syntax error. You must pass one or more data source names to be deleted." and usage() and
            exit 1 if not @names;
    # Deleting
    say "Deleting: @names...";
    foreach my $dsname (@names) {
        # Print an error if dnname does not exits. If '--ignore', continue.
        # We print an error instead of die because occours an user input error, and not a logic error
        # See: http://affy.blogspot.com.br/p5be/ch13.htm
        eval{$rrd->delete_DS($dsname);};
        say "DS '$dsname' does not exists" and exit 1 if $@ and not $ignore;
    }
    $rrd->save();
    $rrd->close();
    # After RRD::Editor->delete_DS, the RRD header can be inconsistent, with a wrong size.
    # So, recovery RRD
    recovery($file);
    say "All DS deleted";
    exit 0;
}

# Print RRAs
if ($command eq "print-rra") {
    # Print
    my $num_rra = $rrd->num_RRAs();
    my $minstep = $rrd->minstep();
    say "Number of RRAs: $num_rra";
    say "Minimum step size: $minstep";
    # RRAs doesn't have names. They're indexed from 0 to num_RRAs()-1.
    # See: http://search.cpan.org/~dougleith/RRD-Editor/lib/RRD/Editor.pm#num_RRAs
    # Print number of rows, step and other informations foreach RRA
    foreach my $i (0 .. $num_rra-1) {
        printf "RRA %s:\n\tStep: %s\n\tRows: %s\n", $i, $rrd->RRA_step($i), $rrd->RRA_numrows($i);
        my $totaltime = $rrd->RRA_step($i) * $rrd->RRA_numrows($i);
        printf "\tTotal time: %d seconds (%d hours)\n", $totaltime, $totaltime / 3600;
    }
    # Print full
    if ($full) {
        my @infos = split /\n/, $rrd->info();
        foreach my $info (@infos) {
            say $info if $info =~ /^rra/;
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
	say "Syntax error. You must pass one id and the new number of rows." and usage() and
            exit 1 if not $id or not $torows;

    my $orig_rows = $rrd->RRA_numrows($id);

    # Resize 
    say "Resizing rows of RRA $id from $orig_rows to $torows...";
    $rrd->resize_RRA($id, $torows);
    $rrd->save();
    $rrd->close();
    say "Number of rows changed";
    exit 0;
}

# Resize RRAs - Step
if ($command eq "resize-step-rra") {
    # This command changes the step and row values and manteins the same period.
    # Example: If the step is divided by two, the number of rows is duplicated
    #
    # According to RRD::Editor, "changing the step size is hard as it would require resampling 
    # the data stored in the RRA". So, they didn't implement this.
    # See: http://search.cpan.org/~dougleith/RRD-Editor/lib/RRD/Editor.pm#RRA_step
    #
    # We propose three methods to implement this: with-add, with-step or with-interpolation
    # See: RRA_STEP.md

    # Error
	say "Syntax error. You must pass one id and the new step." and usage() and
            exit 1 if not $id or not $tostep;
    $with_add = 1 if not $with_add and not $with_step and not $with_interpolation;
    say "Syntax error. You must select only one algorithm." and usage() and
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
    say "Invalid value error. The step must be a multiple of the minimum step: $minstep" and
            exit 1 if not Scalar::Util::Numeric::isint($step_relative);

    # With add (--with-add)
    # Add new RRAs, and a 'at' task to delete the old ones
    if ($with_add) {
        
        # Adding new RRA
        say "Adding new RRA: [$newrra_string]...";
        $rrd->add_RRA($newrra_string);
        $rrd->save();
        $rrd->close();
        say "New RRA added";
        # Time changed. New rows was ceilled
        say "Total time changed: from $orig_time seconds to $new_time" if $orig_time != $new_time;
        
        # Generate 'at' command to schedule the delete operation
        # 'at' is a linux tool that permits executing commands at a specified time.
        # See: http://linux.die.net/man/1/at
        my $time_hours =  $orig_time / 3600;
        print "Old RRA (id=$id) expires in $time_hours hours.\n";
        (my $script_name = $0) =~ s{./}{};
        my $at_string = sprintf "%s/%s delete-rra --file %s --id %s", $ENV{PWD}, $script_name, $file, $id;
        my $script_string = "echo \"$at_string\" | at now + $time_hours hours";
        
        # Only print the 'at' command
        if (not $schedule) {
            say "Run this command to delete this RRA when it's no more necessary:"; 
            say "    $script_string";
        }
        # Schedule the delete operation (--schedule)
        else {
            say "Scheduling delete operation: $at_string";
            # TODO What is better? backslash ` or 'system function'?
            `$script_string`;
        }

        exit 0;
    }

    # Other algorithms
    if ($with_step or $with_interpolation) {
        
        # We need to create a new RRD with the new RRA and insert the new points in it, because 
        # "you MUST always feed values in chronological order. Stuff breaks if you don't, so don't.".
        # See: http://ds9a.nl/rrd-mini-howto/cvs/rrd-mini-howto/output/rrd-mini-howto-1.html#ss1.3
        #      https://lists.oetiker.ch/pipermail/rrd-users/2012-June/018661.html 
        
        say "Resizing step of RRA $id from $orig_step to $tostep...";
        # Create the new RRA
        say "Creating new RRD structure" if $ENV{"DEBUG"};
        $rrd->close();
        my $new_file = $file . ".new";
        change_rra($file, $new_file, $id, $tostep, $new_rows, $newrra_string);
        say "New RRD structure created" if $ENV{"DEBUG"};
        # Time changed. New rows was ceilled
        say "RRA time changed: from $orig_time seconds to $new_time" if $orig_time ne $new_time;

        # Create RRA array and sort by precision (step)
        my @rra_sort;
        my $num_rra = $rrd->num_RRAs();
        my $end_time = $rrd->last();
        
        foreach my $i (0 .. $num_rra - 1) {
            push @rra_sort, [$i, $rrd->RRA_step($i), $rrd->RRA_numrows($i)];
        }
        @rra_sort = sort {$a->[1] <=> $b->[1]} @rra_sort;

        # Foreach RRA, fetch data
        say "Generating points" if $ENV{"DEBUG"};
        my %data_hash = ();
        my @dsnames = $rrd->DS_names();
        foreach my $i (0 .. $num_rra - 1) {
            my $iter_id = $rra_sort[$i]->[0];
            my $iter_step = $rra_sort[$i]->[1];
            my $iter_rows = $rra_sort[$i]->[2];
            my $iter_time = $iter_step * $iter_rows;
            my $start_time = $end_time - $iter_time;

            # RRDs::fetch is better than RRD::editor->fetch
            # See: http://oss.oetiker.ch/rrdtool/prog/RRDs.en.html
            my ($iter_start, $real_step, undef, $data) = RRDs::fetch($file, "AVERAGE", "-r", $iter_step, "-s", $start_time, 
                    "-e", $end_time-$iter_step);

            # Insert points into the data hash
            # Because the fetchs used RRAs in a sorted way, data hash always is setted with the most precise value
            # To understant what is a hash
            # See: http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/hash/
            my $insert_time = $iter_start; 
            foreach my $data_line (@$data) {
                $data_hash{$insert_time} = $data_line;
                $insert_time += $iter_step; 
            }
        }
        say "Points generated" if $ENV{"DEBUG"};

        # DEBUG TIME
        my $run_time = Time::HiRes::time() - $start_run;;
        say "From start to this moment: $run_time" if $ENV{"DEBUG_TIME"};
        $start_run = Time::HiRes::time();

        # Interpolation is only needed when new step is smaller then orig step. That is, the new rra is more precise
        if ($tostep <= $orig_step) {
            # With step (--with-step)
            # Insert new points using the step function
            if ($with_step) {
                say "Not yet implemented :(" and exit 1;
            }
            # With interpolation (--with-interpolation)
            # Insert new points using a smooth interpolation
            elsif ($with_interpolation) {
                say "Not yet implemented :(" and exit 1;
            }
        }

        # Save data in the new RRD
        say "Inserting new points" if $ENV{"DEBUG"};
        my $update_string = '';
        foreach my $timestamp (sort keys %data_hash) {
            my $temp_data = $data_hash{$timestamp};
            my @iter_data = @$temp_data;
            # Change undefined values to 'U'
            foreach my $value (@iter_data) {
                $value = "U" if not defined $value;
            }
            $update_string = sprintf "%d:%s", $timestamp, join(":", @iter_data);
            update_cache_rrd($new_file, $update_string);
        }
        # Flush if there is some cache
        update_flush_rrd($new_file);
        say "Points inserted" if $ENV{"DEBUG"};
        
        # DEBUG_TIME
        $run_time = Time::HiRes::time() - $start_run;
        say "From 'insert points' to this moment: $run_time" if $ENV{"DEBUG_TIME"};
        
        # Overwrite the original RRD with the new RRD
        rename($new_file, $file);
        say "RRD migrated";
        exit 0;
    }
    
}

# Command not implemented yet
die "Command not implemented";

