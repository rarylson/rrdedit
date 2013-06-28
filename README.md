rrdedit
=======

Command line tool that edit RRDs. It 

It uses the RRD::Editor and RRDs perl modules.

Currently, there are only these funcionalities:

- Print datasource informations
- Print RRA informations
- Remove datasources
- Resize RRA time by changing the number of rows
- Resize RRA precision by changing the RRA step


Requirements
------------

RRDTool (if you are using Ubuntu):

    apt-get install rrdtool

Perl Modules:

    cpan install ExtUtils::MakeMaker
    cpan install RRD::Editor
    cpan install Math::Interpolator


Quick start
-----------

To print informations:

    # print datasource informations
    ./rrdedit.pl print-ds --file test/ping_rta.rrd
    
    # print more detailed
    ./rrdedit.pl print-ds --file test/ping_rta.rrd --full
    
    # print rra informations
    ./rrdedit.pl print-rra --file test/ping_rta.rrd

Edit datasources:

    # Delete two datasources
    ./rrdedit.pl delete-ds --file test/ping_rta.rrd --names min,warn

Edit RRA:

    # Adding more rows
    ./rrdedit.pl resize-rows-rra --file test/ping_rta.rrd --id 3 --torows 900
    
    # Increasing precision (changing step) using 'with-add' algorithm
    ./rrdedit.pl resize-step-rra --file test/ping_rta.rrd --id 2 --tostep 7800 --with-add


To get help:

    # Usage
    ./rrdedit.pl --usage

    # Help (not yet implemented)
    ./rrdedit.pl --help


TODO
----

This plugin is very very simple. We want to implement:

- Short names in syntax, like:

  ```./rrdedit.pl delete-ds -f file.rrd -n name1,name2```

- A useful help and a usage for every command

- Two more algorithms for resize-step-rra (You'll choose the one you prefer!)

- Others operations with datasource and RRA

