package trapmisc;
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(
	usage
	);

$VERSION = 1.00;

sub usage
{
    $prog = $0;
    $prog =~ s/.*\///;
    print <<EOF;
    usage : $prog [-i <infile>] [-o <outfile>] [-r <runId>] |
      [<infile>] [<runId>]
    -i <name>: input file name
    -o <name>: output file name
    -r <runId>: Run Identifier
    -I <interval>: Interval at which sample is taken
    -F <filter_value>: By default, all data points less than 1000
                       are ignored. Specify -F -1 to consider
                       _ALL_ data points

    Without input/output files specified, the 'stdin' and 'stdout'
    will be used.

EOF

    exit 1;
}

1;
