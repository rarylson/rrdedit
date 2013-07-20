rrdedit
=======

Command line tool that edit RRDs.

It uses the RRD::Editor and RRDs perl modules.

Currently, there are only these funcionalities:

- Print datasource information
- Print RRA information
- Remove datasources
- Resize RRA time by changing the number of rows
- Resize RRA precision by changing the RRA step


Requirements
------------

Perl version 5.10.0 or newer (if you are using Ubuntu):

    apt-get install perl

RRDTool (if you are using Ubuntu):

    apt-get install rrdtool

Perl Modules:

    cpan install ExtUtils::MakeMaker RRD::Editor
    cpan install RRD::Tweak
    cpan install Scalar::Util::Numeric
    cpan install Math::Interpolator
    cpan install Data::Printer Time::HiRes

To install CPAN (if you are using Ubuntu):

    apt-get install perl-modules

Quick start
-----------

To print information:

    # print datasource information
    ./rrdedit.pl print-ds --file test/ping_rta.rrd
    
    # print more detailed
    ./rrdedit.pl print-ds --file test/ping_rta.rrd --full
    
    # print rra information
    ./rrdedit.pl print-rra --file test/ping_rta.rrd

To edit datasources:

    # Delete two datasources
    ./rrdedit.pl delete-ds --file test/ping_rta.rrd --name min,warn

To edit RRA:

    # Adding more rows
    ./rrdedit.pl resize-rows-rra --file test/ping_rta.rrd --id 3 --torows 900
    
    # Increasing precision (changing step) using 'with-add' algorithm
    ./rrdedit.pl resize-step-rra --file test/ping_rta.rrd --id 2 --tostep 7800 --with-add


To get help:

    # Usage
    ./rrdedit.pl --usage

    # Help
    ./rrdedit.pl --help

    # Usage for 'delete-rra' command
    ./rrdedit.pl delete-rra --usage

    # Help for 'print-ds' command
    ./rrdedit.pl print-ds --help

And more...


License
-------

This software is protected by Revised BSD License.
See: [rrdedit.pl License](LICENSE)


TODO
----

This plugin is very, very simple. We want to implement:

- Short names in syntax, like:

  ```./rrdedit.pl delete-ds -f file.rrd -n name1,name2```

- A help for every command

- Two more algorithms for resize-step-rra (You'll choose the one you prefer!)

- Convert between file formats (native-double, portable-double, portable-single)

- Other operations with datasource and RRA

- Implement a complete test suit
