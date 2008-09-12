package txt2xml;
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(
	xml_start_cell xml_end_cell
	xml_start_stat_group xml_end_stat_group
	xml_start_stat_doc xml_end_stat_doc
	xml_start_dim xml_end_dim
	xml_start_cell_list xml_end_cell_list
	xml_start_dimval xml_end_dimval
	xml_start_dim_list xml_end_dim_list
	xml_meta
	);

$VERSION = 2.00;

$INDENT = "";  # Indent string
$TAB = "   ";  # Tab stops
$CUR_TPOS = 0; # Current TAB position;

sub tab_forw
{
	$CUR_TPOS++;
	$INDENT = ($TAB x $CUR_TPOS);
}

sub tab_back
{
	$CUR_TPOS--;
	$CUR_TPOS = 0 if ($CUR_TPOS < 0);
	$INDENT = ($TAB x $CUR_TPOS);
}

sub tab
{
#	print $INDENT;
}

sub xml_start_cell
{
	tab();
	print "<cell";
	if (@_)
	{
		%args = @_;
		@attribs = qw( ordinal color type );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print ">";
}

sub xml_end_cell
{
	print "</cell>\n";
}

sub xml_start_stat_group
{
	tab();
	print "<stat_group";
	if (@_)
	{
		%args = @_;
		@attribs = qw( name display location type );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print ">\n";
	tab_forw();
}

sub xml_end_stat_group
{
	tab_back();
	tab();
	print "</stat_group>\n";
}

sub xml_start_stat_doc
{
	tab();
	print "<stat_doc";
	if (@_)
	{
		%args = @_;
		@attribs = qw( name version );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print ">\n";
	tab_forw();
}

sub xml_end_stat_doc
{
	tab_back();
	tab();
	print "</stat_doc>\n";
}

sub xml_start_dim
{
	tab();
	print "<dim";
	if (@_)
	{
		%args = @_;
		@attribs = qw( ordinal group level name color );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print ">\n";
	tab_forw();
}

sub xml_end_dim
{
	tab_back();
	tab();
	print "</dim>\n";
}

sub xml_start_cell_list
{
	tab();
	print "<cell_list";
	if (@_)
	{
		%args = @_;
		@attribs = qw( ordinal group level name color );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print ">\n";
	tab_forw();
}

sub xml_end_cell_list
{
	tab_back();
	tab();
	print "</cell_list>\n";
}

sub xml_start_dimval
{
	tab();
	print "<dimval";
	if (@_)
	{
		%args = @_;
		@attribs = qw( ordinal group level name color );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print ">";
}

sub xml_end_dimval
{
	print "</dimval>\n";
}

sub xml_start_dim_list
{
	tab();
	print "<dim_list";
	if (@_)
	{
		%args = @_;
		@attribs = qw( ordinal group level name color );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print ">\n";
	tab_forw();
}

sub xml_end_dim_list
{
	tab_back();
	tab();
	print "</dim_list>\n";
}

sub xml_meta
{
	tab();
	print "<meta";
	if (@_)
	{
		%args = @_;
		@attribs = qw( name value );
		foreach $attr (@attribs) {
			print " $attr=$args{$attr}" if exists $args{$attr};
		}
	}
	print "/>\n";
}

1;
