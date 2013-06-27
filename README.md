rrdedit
=======

Command line tool that edit RRDs. It's a wrapper to some funcionalities of the RRD::Editor perl module.

Currently, there are only these funcionalities:

- Print datasource informations
- Remove datasources


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

Print all Datasources:

    ./rrdedit.pl --file test/ping_rta.rrd --print

Delete datasources:

    ./rrdedit.pl --file test/ping_rta.rrd --delete min,warn

or

    ./rrdedit.pl --file test/ping_rta.rrd --delete min --delete warn

To get help:

    ./rrdedit.pl --help


TODO
----

This plugin is very very simple. We want:

- Syntax like ./rrdedit.pl deleteds --file file.rrd --dsname name1,name2 (it is, ./rrdedit.pl command --param1 value1 --param2 --param3 value3)
- Short names in syntax, like ./rrdedit.pl deleteds -f file.rrd -n name1,name2
- Better print report
- Add/delete datasources, and add/delete rra

