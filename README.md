# deps-flamegraph
Generate flame graphs from gradle dependencies.

This is an experiment to see if flamegraphs can help analyzing dependencies
in (big) java projects.

The included perl script takes the output of `gradle dependencies` and converts
it to a format accepted by flamegraph.pl

## Usage
```
USAGE: ./stackcollapse-gradle-dependencies.pl [options] infile > outfile

  --org             # include dependency organisation
  --version         # include dependency version
  --size            # use jar size
  --jar-cache DIR   # specify alternate path for gradle jar cache
```

## Example

See included example that computes the dependencies of the Cassandra driver.

![alt text](samples/cassandra/deps-collapsed.svg "Cassandra driver dependencies")

