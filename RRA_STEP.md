How can I change RRA step?
==========================

Tests using RRD Tool
--------------------

It works:

    rrdtool fetch test/ping_rta.rrd AVERAGE --resolution 1800 --start 1372082700-1260000 --end 1372082700

It works too, but the resolution is the same (1800):

    rrdtool fetch test/ping_rta.rrd AVERAGE --resolution 900 --start 1372082700-1260000 --end 1372082700

It works. The resolution is 3600. It is, there is half of the points' values. So, I can only subtract points, but never increase it:

    rrdtool fetch test/ping_rta.rrd AVERAGE --resolution 3600 --start 1372082700-1260000 --end 1372082700

Using xport, we get similar results, but the start and end time was 1370824200 (1370824200 = 1372082700-1260000). So, end time is wrong. This is a bug?

    rrdtool xport --start 1372082700-1260000 --end 1372082700 --step 1800 --maxrows 700 "DEF:data=test/ping_rta.rrd:data:AVERAGE" \
        "DEF:warn=test/ping_rta.rrd:warn:AVERAGE" "DEF:crit=test/ping_rta.rrd:crit:AVERAGE" "XPORT:data" "XPORT:warn" "XPORT:crit"

Again, it works but the resolution is the same:

    rrdtool xport --start 1372082700-1260000 --end 1372082700 --step 900 --maxrows 1400 "DEF:data=test/ping_rta.rrd:data:AVERAGE" \
        "DEF:warn=test/ping_rta.rrd:warn:AVERAGE" "DEF:crit=test/ping_rta.rrd:crit:AVERAGE" "XPORT:data" "XPORT:warn" "XPORT:crit"

Again, it works and the resolution is half of the initial value:

    rrdtool xport --start 1372082700-1260000 --end 1372082700 --step 3600 --maxrows 350 "DEF:data=test/ping_rta.rrd:data:AVERAGE" \
        "DEF:warn=test/ping_rta.rrd:warn:AVERAGE" "DEF:crit=test/ping_rta.rrd:crit:AVERAGE" "XPORT:data" "XPORT:warn" "XPORT:crit"


### Conclusion

It's possible generate less points, but never more points.


Interpolation
-------------

See:

- http://search.cpan.org/~zefram/Math-Interpolator-0.005/lib/Math/Interpolator.pm
- http://search.cpan.org/~zefram/Math-Interpolator-0.005/lib/Math/Interpolator/Robust.pm
- http://search.cpan.org/~zefram/Math-Interpolator-0.005/lib/Math/Interpolator/Knot.pm


Logic
-----

I propose two solutions:


### With new RRAs, and a cron task

Do this:

- Add a new RRA to replace the old one;
- Print a crontab job to run after the new RRA to be filled


### With interpolation

Do this:

- Foreach RRA, get the real values using fetch, and remember it id;
- Add a new RRA and remember it id too;
- Fetch the RRD to get all points of this RRA;
- Interpolate all points to generate new points;
- Save new points in the new RRA;
- Delete the old RRA

