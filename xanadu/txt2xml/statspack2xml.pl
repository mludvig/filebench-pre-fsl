#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;

sub calcColBounds
{
# Search for blanks
    $ind = $prevind = 0;
    @colboundary = ();
    s/\n$/ /;
    while (($ind = index($_, " ", $ind)) >= 0)
    {
	push @colboundary, $ind++;
    }
}

sub extractFields
{
    $prevbound = 0;
    @fields = ();

    foreach $colbound (@colboundary)
    {
	$field = trim(substr($_, $prevbound, $colbound - $prevbound));
	$field =~ s/,//g;
	$field =~ s/\#+/-/;
	push @fields, $field;
	$prevbound = $colbound;
    }
}

sub trim
{
    my($arg) = @_;

    $arg =~ s/^ +//;
    $arg =~ s/\s+$//;
    return $arg;
}

sub readWrites
{
    xml_start_stat_group(name => "\"@_\"");
    xml_start_cell_list();

    @dimlist = ();
    ($dimname, @dimlist) = split;

    <INFILE>;
    $heading1 = <INFILE>;
    $heading2 = <INFILE>;

    $_ = <INFILE>;

    @colboundary = ();
# Search for blanks
    $ind = $prevind = 0;
    s/\n$/ /;
    while (($ind = index($_, " ", $ind)) >= 0)
    {
	$colhead = trim(substr($heading1, $prevind, $ind - $prevind));
	$colhead = "$colhead " . 
	    trim(substr($heading2, $prevind, $ind - $prevind));
	push(@dimlist, $colhead);
	push @colboundary, $ind;
	$prevind = $ind++;
    }


    @rowdimlist = ();
    while (<INFILE>)
    {
	last if (/--/);
	next if (/^\n/);

	# If the section repeats, ignore the next few rows
	if (/IO Stats/) {
	  <INFILE>;<INFILE>;<INFILE>;<INFILE>;<INFILE>;<INFILE>;<INFILE>;
	  next;
	}

	@fields = split;
	$object = $fields[0];

	if (defined($fields[1]))
	{
	    xml_start_cell();
	    print $fields[1];
	    xml_end_cell();
	}

	$_ = <INFILE>;

	$prevbound = 0;
	@fields = ();

	foreach $colbound (@colboundary)
	{
	    $field = trim(substr($_, $prevbound, $colbound - $prevbound));
	    $field =~ s/,//g;

	    push(@fields, $field);

	    $prevbound = $colbound;
	}

	if ($fields[1] + $fields[5] > 0) {
	  foreach $field (@fields) {
	    xml_start_cell();
	    print $field;
	    xml_end_cell();
	  }
	  push(@rowdimlist, $object);
	}
    }


    xml_end_cell_list();
    xml_start_dim_list();
    xml_start_dim(name => '"Value"');

    foreach $dimval (@dimlist)
    {
	xml_start_dimval();
	print $dimval;
	xml_end_dimval();
    }
    xml_end_dim();

    xml_start_dim(name => "\"$dimname\"");
    
    foreach $field (@rowdimlist)
    {
	xml_start_dimval();
	print $field;
	xml_end_dimval();
    }

    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();

}


sub waitEvents
{    
xml_start_stat_group(name => "\"@_\"");
xml_start_cell_list();

@rowdimlist = ();
while (<INFILE>)
{
    last if (/--/);
}

&calcColBounds;

while (<INFILE>)
{
    last if (/--/);

    if (/Wait Events/)
    {
	while (<INFILE>)
	{
	    last if (/^--/);
	}
	next;
    }


    $prevbound = 0;
    @fields = ();

    foreach $colbound (@colboundary)
    {
	$field = trim(substr($_, $prevbound, $colbound - $prevbound));
	$field =~ s/,//g;
	$field =~ s/\#+/-/;
	push @fields, $field;
	$prevbound = $colbound;
    }

    if ($fields[3] > 0)
    {
	push @rowdimlist, $fields[0];

	for ($i = 1; $i <= $#fields; $i++)
	{
	    xml_start_cell();
	    print $fields[$i];
	    xml_end_cell();
	}
    }
}

xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Value"');
xml_start_dimval();
print "Waits";
xml_end_dimval();
xml_start_dimval();
print "Timeouts";
xml_end_dimval();
xml_start_dimval();
print "Total Wait (s)";
xml_end_dimval();
xml_start_dimval();
print "Avg Wait (ms)";
xml_end_dimval();
xml_start_dimval();
print "Waits / Trans";
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Stat"');

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();
}


#Main program begins here
open(INFILE, $ARGV[0]);

xml_start_stat_doc(name => '"Statspack Report"');
xml_meta(name => '"RunId"', value => "\"$ARGV[1]\"");

xml_start_stat_group(name => '"System Info"', type => '"categorical"');
xml_start_cell_list();

while (<INFILE>)
{
    last if /^DB Name/;
}

$heading = $_;
$_ = <INFILE>;
# Search for blanks
$ind = $prevind = 0;
while (($ind = index($_, " ", $ind)) >= 0)
{
    $colhead = trim(substr($heading, $prevind, $ind - $prevind));
    push(@dimlist, $colhead);
    $prevind = $ind++;
}

$colhead = trim(substr($heading, $prevind));
push(@dimlist, $colhead);

$_ = <INFILE>;
chomp;

$line = <INFILE>;
$_ = $_ . chomp($line);

@fields = split;

foreach $field (@fields)
{
    xml_start_cell();
    print $field;
    xml_end_cell();
}

xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Value"');

foreach $field (@dimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

xml_start_stat_group(name => '"Snaps"', type => '"categorical"');
xml_start_cell_list();

while (<INFILE>)
{
    last if /Snap/;
}

$heading = $_;
$_ = <INFILE>;
# Search for dash
$startind = index($_, "-");
@dimlist = ();

$ind = $prevind = $startind;
s/\n$/ /;

while (($ind = index($_, " ", $ind)) >= 0)
{
    push @colboundary, $ind++;
}

# Get the headings
$prevbound = $startind;
foreach $colbound (@colboundary)
{
    $colhead = trim(substr($heading, $prevbound, $colbound - $prevbound));
    push(@dimlist, $colhead);
    $prevbound = $colbound;
}

while (<INFILE>)
{
    last if ($_ eq "\n");

    $dimval = substr($_, 0, $startind);
    push @rowdimlist, $dimval;

    $prevbound = $startind;

    foreach $colbound (@colboundary)
    {
	if ($prevbound < length($_))
	{
	    $cell = substr($_, $prevbound, $colbound - $prevbound);
	    $cell = trim($cell);
	}
	else
	{
	    $cell = "";
	}

	xml_start_cell();
	print $cell;
	xml_end_cell();

	$prevbound = $colbound;
    }
}

xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Value"');

foreach $field (@dimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();

xml_start_dim();

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

# Cache Sizes statgroup
$_ = <INFILE>;
chomp;
xml_start_stat_group(name => "\"$_\"", type => '"categorical"');
xml_start_cell_list();
<INFILE>;

@rowdimlist = ();
while (<INFILE>)
{
    last if ($_ eq "\n");

    s/,//g;
    $field1 = substr($_, 0, 40);
    $field2 = substr($_, 40);

    @fields = split(':', $field1);
    push @rowdimlist, trim($fields[0]);

    xml_start_cell();
    print trim($fields[1]);
    xml_end_cell();

    @fields = split(':', $field2);
    push @rowdimlist, trim($fields[0]);

    xml_start_cell();
    print trim($fields[1]);
    xml_end_cell();
}

xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Value"');

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

# Load Profile statgroup
$_ = <INFILE>;
chomp;
xml_start_stat_group(name => "\"$_\"");
xml_start_cell_list();
<INFILE>; <INFILE>;

@rowdimlist = ();
while (<INFILE>)
{
    last if ($_ eq "\n");

    s/,//g;
    @fields = split(':');
    push @rowdimlist, trim($fields[0]);

    $_ = $fields[1];
    @fields = split;

    xml_start_cell();
    print $fields[0];
    xml_end_cell();

    xml_start_cell();
    print $fields[1] if (defined($fields[1]));
    xml_end_cell();
}

while (<INFILE>)
{
    last if ($_ eq "\n");

    s/\#+/-/;
    $field1 = substr($_, 0, 40);
    $field2 = substr($_, 40);

    @fields = split(':', $field1);
    push @rowdimlist, trim($fields[0]);

    xml_start_cell();
    xml_end_cell();
    xml_start_cell();
    print trim($fields[1]);
    xml_end_cell();

    @fields = split(':', $field2);
    push @rowdimlist, trim($fields[0]);

    xml_start_cell();
    xml_end_cell();
    xml_start_cell();
    print trim($fields[1]);
    xml_end_cell();
}

xml_end_cell_list();
xml_start_dim_list();

xml_start_dim(name => '"Value"');
xml_start_dimval();
print 'Per Second';
xml_end_dimval();
xml_start_dimval();
print 'Per Transaction';
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Stat"');

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

# Instance Efficiency Statgroup
$_ = <INFILE>;
chomp;
xml_start_stat_group(name => "\"$_\"");
xml_start_cell_list();
<INFILE>;

@rowdimlist = ();
while (<INFILE>)
{
    last if ($_ eq "\n");
    $field1 = substr($_, 0, 40);
    $field2 = substr($_, 40);

    @fields = split(':', $field1);
    push @rowdimlist, trim($fields[0]);

    xml_start_cell();
    print trim($fields[1]);
    xml_end_cell();

    @fields = split(':', $field2);
    push @rowdimlist, trim($fields[0]);

    xml_start_cell();
    print trim($fields[1]);
    xml_end_cell();
}

while (<INFILE>)
{
    last if (/-/);
}

while (<INFILE>)
{
    last if ($_ eq "\n");

    @fields = split(':');
    push @rowdimlist, trim($fields[0]);

    $_ = $fields[1];
    @fields = split;

    xml_start_cell();
    print (($fields[0] + $fields[1]) / 2);
    xml_end_cell();
}

xml_end_cell_list();
xml_start_dim_list();
xml_start_dim();
xml_start_dimval();
print "Value";
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Stat"');

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

while (<INFILE>)
{
    last if (/Snap/);
}

if (/Cluster/)
{
    xml_start_stat_group(name => "\"Cache Fusion Stats\"");
    xml_start_cell_list();

    @rowdimlist = ();
    while (<INFILE>)
    {
	last if (/Snaps/);
	next unless (/:/);

	@fields = split(':');

	xml_start_cell();
	print trim($fields[1]);
	xml_end_cell();

	push @rowdimlist, $fields[0];
    } 

    xml_end_cell_list();
    xml_start_dim_list();
    xml_start_dim();
    xml_start_dimval();
    print "Value";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => '"Stat"');

    foreach $field (@rowdimlist)
    {
	xml_start_dimval();
	print $field;
	xml_end_dimval();
    }

    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();

    xml_start_stat_group(name => "\"GES Statistics\"");
    xml_start_cell_list();

    @rowdimlist = ();
    while (<INFILE>)
    {
	last if (/-/);
    }

    &calcColBounds;

    while (<INFILE>)
    {
	last if (/--/);

	if (/GES Statistics/)
	{
	    <INFILE>; <INFILE>; <INFILE>;
	    next;
	}

	$prevbound = 0;
	@fields = ();

	foreach $colbound (@colboundary)
	{
	    push @fields, trim(substr($_, $prevbound, $colbound - $prevbound));
	    $prevbound = $colbound;
	}

	$fields[1] =~ s/,//g;
	if ($fields[1] > 0)
	{
	    push @rowdimlist, $fields[0];

	    for ($i = 1; $i <= $#fields; $i++)
	    {
		xml_start_cell();
		print $fields[$i];
		xml_end_cell();
	    }
	}
    }

    xml_end_cell_list();
    xml_start_dim_list();
    xml_start_dim(name => '"Value"');
    xml_start_dimval();
    print "Total";
    xml_end_dimval();
    xml_start_dimval();
    print "Per Sec";
    xml_end_dimval();
    xml_start_dimval();
    print "Per Trans";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => '"Stat"');

    foreach $field (@rowdimlist)
    {
	xml_start_dimval();
	print $field;
	xml_end_dimval();
    }

    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

waitEvents("Wait Events");
waitEvents("Background Wait Events");

while (<INFILE>)
{
    last if /Instance Activity/;
}

<INFILE>;
$heading = <INFILE>;
$_ = <INFILE>;

@dimlist = ();
@colboundary = ();
# Search for blanks
$ind = $prevind = 0;
s/\n$/ /;
while (($ind = index($_, " ", $ind)) >= 0)
{
    $colhead = trim(substr($heading, $prevind, $ind - $prevind));
    if ($prevind == 0)
    {
	$dimname = $colhead;
    }
    else
    {
	push(@dimlist, $colhead);
    }
    push @colboundary, $ind;
    $prevind = $ind++;
}


xml_start_stat_group(name => "\"Instance Activity Stats\"");
xml_start_cell_list();

@rowdimlist = ();
while (<INFILE>)
{
    last if (/--/);

    if (/Instance Activity/)
    {
	<INFILE>; <INFILE>; <INFILE>;
	next;
    }

    $prevbound = 0;
    @fields = ();

    foreach $colbound (@colboundary)
    {
	$field = trim(substr($_, $prevbound, $colbound - $prevbound));
	$field =~ s/,//g if $prevbound != 0;
	push @fields, $field;
	$prevbound = $colbound;
    }

    if ($fields[2] !~ /^#/ && $fields[2] > 0)
    {
	push @rowdimlist, $fields[0];

	for ($i = 1; $i <= $#fields; $i++)
	{
	    xml_start_cell();
	    print $fields[$i];
	    xml_end_cell();
	}
    }
}

xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Value"');

foreach $dimval (@dimlist)
{
    xml_start_dimval();
    print $dimval;
    xml_end_dimval();
}
xml_end_dim();

xml_start_dim(name => "\"$dimname\"");

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

while (<INFILE>)
{
    last if (/^Tablespace/);
}
readWrites("Tablespace I/O");


while (<INFILE>)
{
    last if (/Default Pools/);
#    last if (/^Tablespace/);
}
#readWrites("File I/O");



xml_start_stat_group(name => '"Buffer Stats"');
xml_start_cell_list();

while (<INFILE>)
{
    last if (/^\n/);
}

# Do the following until multi-line headers processed
@heading = ();
$lines = 0;

do 
{
    for ($i = 0; <INFILE>; $i++)
    {
	chomp;
	if (/^-/)
	{
	    @fields = split;
	    $numCols += $#fields;
	    $numCols++;

	    last;
	}
	$heading[$i] .= $_;
    }
    $lines++;
}
until ($numCols == 9);

#for ($i = 0; $i <= $#heading; $i++)
#{
#    print STDERR "$heading[$i]\n";
#}



@dimlist = ();
@colboundary = ();
# Search for blanks
$ind = $prevind = 0;
s/  / -/g;
s/\n$/ /;
while (($ind = index($_, " ", $ind)) >= 0)
{
    $colhead = "";
    foreach $head (@heading)
    {
	$colhead = "$colhead " . 
	    trim(substr($head, $prevind, $ind - $prevind));
    }
    if ($prevind == 0)
    {
	$dimname = $colhead;
    }
    else
    {
	push(@dimlist, $colhead);
    }
    push @colboundary, $ind;
    $prevind = $ind++;
}

# Now get to the data
@rowdimlist = ();
while (<INFILE>)
{
    last if (/--/);

    # Read all lines to concatenate
    for ($i = 1; $i <$lines; $i++)
    {
	$x = <INFILE>;
	$_ .= $x;
    }

#    print STDERR $_;

    $prevbound = 0;
    @fields = ();

    foreach $colbound (@colboundary)
    {
	$field = trim(substr($_, $prevbound, $colbound - $prevbound));
	if ($prevbound == 0)
	{
	    push(@rowdimlist, $field);
	}
	else
	{
	    $field =~ s/,//g;

	    xml_start_cell();
	    print $field;
#	    print STDERR "$field\t";
	    xml_end_cell();
	}

	$prevbound = $colbound;
    }
}

xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Value"');

foreach $dimval (@dimlist)
{
    xml_start_dimval();
    print $dimval;
    xml_end_dimval();
}
xml_end_dim();

xml_start_dim(name => "\"$dimname\"");
    
foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();


#Look for Latch Activity
while (<INFILE>)
{
    last if (/^Latch/);
}

$_ = <INFILE>;

xml_start_stat_group(name => '"Latch Activity"');
xml_start_cell_list();

@rowdimlist = ();

# Find the boundaries of the cols
&calcColBounds;


while (<INFILE>)
{
    last if (/--/);

    if (/Latch Activity/)
    {
	while (<INFILE>)
	{
	    last if (/^--/);
	}
	next;
    }

    &extractFields;

    if ($fields[1] >= 10)
    {
	push @rowdimlist, $fields[0];

	for ($i = 1; $i <= $#fields; $i++)
	{
	    xml_start_cell();
	    print $fields[$i];
	    xml_end_cell();
	}
    }
}


xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Requests"');
xml_start_dimval();
print "Get Requests";
xml_end_dimval();
xml_start_dimval();
print "Pct Get Miss";
xml_end_dimval();
xml_start_dimval();
print "Avg Slps/Miss";
xml_end_dimval();
xml_start_dimval();
print "Wait Time (s)";
xml_end_dimval();
xml_start_dimval();
print "NoWait Requests";
xml_end_dimval();
xml_start_dimval();
print "Pct NoWait Miss";
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Latch"');

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();


#Look for Latch Sleeps
while (<INFILE>)
{
    last if (/^Latch/);
}

$_ = <INFILE>;

xml_start_stat_group(name => '"Latch Sleeps"');
xml_start_cell_list();

@rowdimlist = ();

# Find the boundaries of the cols
&calcColBounds;


while (<INFILE>)
{
    last if (/--/);

    next if (/^ /);

    if (/Latch Sleep/)
    {
	while (<INFILE>)
	{
	    last if (/^--/);
	}
	next;
    }

    &extractFields;

    if ($fields[2] >= 10)
    {
	push @rowdimlist, $fields[0];

	for ($i = 1; $i < $#fields; $i++)
	{
	    xml_start_cell();
	    print $fields[$i];
	    xml_end_cell();
	}
    }
}


xml_end_cell_list();
xml_start_dim_list();
xml_start_dim(name => '"Requests"');
xml_start_dimval();
print "Get Requests";
xml_end_dimval();
xml_start_dimval();
print "Misses";
xml_end_dimval();
xml_start_dimval();
print "Sleeps";
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Latch Name"');

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();




# Now for the init.ora parameters

while (<INFILE>)
{
    last if (/^.init\.ora/);
}
while (<INFILE>)
{
    last if (/^-/);
}



xml_start_stat_group(name => '"init.ora Parameters"', type => '"categorical"');
xml_start_cell_list();

@colboundary = ();
# Search for blanks
$ind = 0;
while (($ind = index($_, " ", $ind)) >= 0)
{
    push @colboundary, $ind++;
}

@rowdimlist = ();
while (<INFILE>)
{
    last if (/--/);

    if (/init.ora/)
    {
	<INFILE>; <INFILE>; <INFILE>; <INFILE>;
	next;
    }

    $prevbound = 0;
    @fields = ();
    $numfields = 0;

    foreach $colbound (@colboundary)
    {
	$field = trim(substr($_, $prevbound, $colbound - $prevbound));
	if ($prevbound == 0)
	{
	    push(@rowdimlist, $field);
	}
	else
	{
	    xml_start_cell();
	    print $field;
	    xml_end_cell();
	}

	$prevbound = $colbound;
	last if (++$numfields == 2);
    }
}

xml_end_cell_list();
xml_start_dim_list();

xml_start_dim();
xml_start_dimval();
print "Value";
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Parameter"');

foreach $field (@rowdimlist)
{
    xml_start_dimval();
    print $field;
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

xml_end_stat_doc();






