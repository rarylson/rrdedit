How can I change RRA step?
==========================

Some Tests
----------

It works:

    rrdtool fetch test/ping_rta.rrd AVERAGE --resolution 1800 --start 1372082860-1260000 --end 1372082860

It works too, but the resolution is the same (1800):

    rrdtool fetch test/ping_rta.rrd AVERAGE --resolution 900 --start 1372082860-1260000 --end 1372082860

It works. The resolution is 3600. It is, there is half of the points' values. So, I can only subtract points, but never increase it:

    rrdtool fetch test/ping_rta.rrd AVERAGE --resolution 3600 --start 1372082860-1260000 --end 1372082860

Using xport, we get similar results, but the start and end time was 1370824200 (1370824200 = 1372082860-1260000). So, end time is wrong. This is a bug?

    rrdtool xport --start 1372082860-1260000 --end 1372082860 --step 1800 --maxrows 700 "DEF:data=test/ping_rta.rrd:data:AVERAGE" \
        "DEF:warn=test/ping_rta.rrd:warn:AVERAGE" "DEF:crit=test/ping_rta.rrd:crit:AVERAGE" "XPORT:data" "XPORT:warn" "XPORT:crit"

Again, it works but the resolution is the same:

    rrdtool xport --start 1372082860-1260000 --end 1372082860 --step 900 --maxrows 1400 "DEF:data=test/ping_rta.rrd:data:AVERAGE" \
        "DEF:warn=test/ping_rta.rrd:warn:AVERAGE" "DEF:crit=test/ping_rta.rrd:crit:AVERAGE" "XPORT:data" "XPORT:warn" "XPORT:crit"

Again, it works and the resolution is half of the initial value:

    rrdtool xport --start 1372082860-1260000 --end 1372082860 --step 3600 --maxrows 350 "DEF:data=test/ping_rta.rrd:data:AVERAGE" \
        "DEF:warn=test/ping_rta.rrd:warn:AVERAGE" "DEF:crit=test/ping_rta.rrd:crit:AVERAGE" "XPORT:data" "XPORT:warn" "XPORT:crit"


### Conclusion

It's possible generate less points, but never more points. So, if we want insert point into a more precise RRA, we need to generate more points.


### Interpolation in Perl

See:

- http://search.cpan.org/~zefram/Math-Interpolator-0.005/lib/Math/Interpolator.pm
- http://search.cpan.org/~zefram/Math-Interpolator-0.005/lib/Math/Interpolator/Robust.pm
- http://search.cpan.org/~zefram/Math-Interpolator-0.005/lib/Math/Interpolator/Knot.pm


Algorithms
----------

We propose three algorithms:


### With add (--with-add)

**Add new RRAs, and a 'at' task to delete the old ones**

Do this:

- Add a new RRA to replace the old one;
- Print the 'at' command to delete the old one in the right time


### With step (--with-step)

**Insert new points using the step function**

Do this:

- Add the new RRA;
- Fetch data using the old RRA;
- Save all the points in the new RRA. When a point is new, this value will be the same of the previous real point.
- Delete the old RRA


### With interpolation (--with-interpolation)

**Insert new points using a smooth interpolation algorithm**

Do this:

- Add the new RRA;
- Fetch data using the old RRA;
- Foreach DS, generate points for the interpolation algorithm;
- Generate new points using the interpolation method;
- Save all the points in the new RRA;
- Delete the old RRA

The follow picture summarizes these three algorithms:

![](interpolation.png?raw=true)

