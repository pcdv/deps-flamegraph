#!/usr/bin/perl -w
#
# Convert the output of gradle dependencies to format compatible with flamegraph.pl
# http://www.brendangregg.com/flamegraphs.html
#
# Example
# -------
# ./gradlew dependencies --configuration runtime | stackcollapse-gradle-dependencies.pl --size --org > deps-collapsed
# flamegraph.pl deps-collapsed  > deps-collapsed.svg

use strict;
use Getopt::Long;
use File::Find::Rule;

# options
my $include_org;
my $no_size;
my $no_dups;
my $include_version;
my $jar_path;

GetOptions (org => \$include_org,
            'no-size' => \$no_size,
            'no-dups' => \$no_dups,
            version => \$include_version,
            'jar-cache=s' => \$jar_path,
            )
or die <<USAGE_END;
USAGE: $0 [options] infile > outfile\n
  --org             # include dependency organisation in label
  --version         # include dependency version in label
  --no-size         # ignore jar size (all deps have equal weight)
  --no-dups         # count deps only once (allows to more accurately aggregate size)
  --jar-cache DIR   # specify alternate path for gradle jar cache

USAGE_END

$jar_path = $jar_path || "$ENV{'HOME'}/.gradle/caches/modules-2/files-2.1";

my %jar_size_cache;
# return size in KiB for specified dependency (org, name, version)
sub getSize {
  my $key = join(":", @_);
  my $size = $jar_size_cache{$key};
  $jar_size_cache{$key} = $size = findSize(@_) unless $size;
  return $size;
}

# find jar in cache and return its size (or 1 if not found)
sub findSize{
  my ($org, $name, $version) = @_;
  my $root = "$jar_path/$org/$name/$version";
  if (-d $root) {
    my @files = File::Find::Rule->file()->name( '*.jar' )->in( $root);
    foreach (@files) {
      next if ($_ =~ /.*-sources.*/);
      return int((-s $_) / 1024);
    }
  }
  return 1;
}

my %all;        # contains already seen deps
my @stack;      # contains the current dep "stack" 
foreach (<>) {
  next if (!m/.*[+\\]--- .*/);   # grep "+--- " or "\--- "
  chomp;

  my ($org, $name, $version) = ('', '', '');
  my $line = $_;

  # convert indent level to stack depth
  my $depth = (index($line, '-') - 1) / 5;

  # trim unwanted content
  $line =~ s/.*--- (.*)/$1/;
  $line =~ s/ \(\*\)//;

  if ($line =~ /^([^: ]+):([^: ]+):([^: ]+)/) {
    ($org, $name, $version) = ($1, $2, $3);
    $version && $version =~ s/.* -> //;  # use overridden version
  }
  if ($line =~ /project .*:(.*)/) {
    $org = "(project)";
    $name = $1;
  }

  # handle no-dups option
  next if $no_dups && $all{"$org:$name"};
  $all{"$org:$name"} = 1;

  my $size = $no_size ? 1 : getSize($org, $name, $version);
  my $entry = $name;

  $entry = "$org:$entry" if ($include_org && $org);
  $entry = "$entry:$version" if ($include_version && $version);

  # build and output "stack"
  $stack[$depth] = $entry;
  splice(@stack, $depth + 1);
  my $joined_stack = join(';', @stack);
  print "$joined_stack $size\n";
}