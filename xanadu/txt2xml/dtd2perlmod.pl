#!/bin/perl -w
#
# Precondition:
# 1. ELEMENT definition must precede corresponding ATTLIST definition.
# 2. EMPTY ELEMENT ends with EMPTY>
# 3. LEAF ELEMENT ends with (#PCDATA)>
# 3. ATTLIST format is:
#            <!ATTLIST {element_name}
#                {attrib1} ...
#                {attrib2} ...>
#    i.e. attribute definitions are on their own lines, with the last
#    definition containing the >
#
# Note: Parser is insensitve to DTD tag case.
#

$VERSION = "2.00";
%xml_element = ();
%xml_empty_element = ();
%xml_leaf_element = ();

#
# Parse DTD
#
while (<>) {
  
  if (/<!ELEMENT/i) {
    
    @field = split;
    $xml_element{$field[1]} = ();  
    $field[2] =~ tr/a-z/A-Z/;
    SWITCH: { 
	if ($field[2] eq "EMPTY>") { $xml_empty_element{$field[1]} = (); last SWITCH; }
	if ($field[2] eq "(#PCDATA)>") { $xml_leaf_element{$field[1]} = (); last SWITCH; }
      }
  } 
  elsif (/<!ATTLIST/i) {
    
    @field = split;
    $name = $field[1];
    
    while (<>) {
      @field = split;
      push @{$xml_element{$name}}, $field[0];
      last if (/>/);
    }
  }
}


#
# Generate code
#

print "package txt2xml;\n";
print "require Exporter;\n";
print "\n";
print "\@ISA = qw(Exporter);\n";
print "\@EXPORT = qw(\n";
foreach $element (keys %xml_element) {
  if (exists $xml_empty_element{$element}) {
    print "\txml_", $element, "\n";
  } else {
    print "\txml_start_", $element, " ";
    print "xml_end_", $element, "\n";
  }
}
print "\t);\n";
print "\n";

print "\$VERSION = ", $VERSION, ";\n";
print "\n";
print "\$INDENT = \"\";  \# Indent string\n";
print "\$TAB = \"   \";  \# Tab stops\n";
print "\$CUR_TPOS = 0; \# Current TAB position;\n";
print "\n";

print "sub tab_forw\n";
print "{\n";
print "\t\$CUR_TPOS++;\n";
print "\t\$INDENT = (\$TAB x \$CUR_TPOS);\n";
print "}\n";
print "\n";

print "sub tab_back\n";
print "{\n";
print "\t\$CUR_TPOS--;\n";
print "\t\$CUR_TPOS = 0 if (\$CUR_TPOS < 0);\n";
print "\t\$INDENT = (\$TAB x \$CUR_TPOS);\n";
print "}\n";
print "\n";

print "sub tab\n";
print "{\n";
print "\#\tprint \$INDENT;\n";
print "}\n";
print "\n";



foreach $element (keys %xml_element) {
  
  @attr_list = @{$xml_element{$element}} if defined @{$xml_element{$element}}; 
  $EMPTY_ELEMENT = exists $xml_empty_element{$element};
  $LEAF_ELEMENT = exists $xml_leaf_element{$element};

  #
  # START tag	
  #
  if ($EMPTY_ELEMENT) {
    print "sub xml_$element\n";
  } else {
    print "sub xml_start_$element\n";
  }
  print "{\n";
  print "\ttab();\n";
  print "\tprint \"<$element\";\n";

  if (defined @attr_list) {
    print "\tif (\@_)\n\t{\n";  
    print "\t\t\%args = \@_;\n";
    print "\t\t\@attribs = qw(";
    foreach $attr (@attr_list) {
      print " $attr";
    } 
    print " );\n";
    print "\t\tforeach \$attr (\@attribs) {\n";
    print "\t\t\tprint \" \$attr=\$args{\$attr}\" if exists \$args{\$attr};\n";
    print "\t\t}\n\t}\n";
  }
  if ($EMPTY_ELEMENT) {
    print "\tprint \"/>\\n\";\n";
  } else {
    print "\tprint \">"; 
    if ($LEAF_ELEMENT) {
      # No newline or tab
      print "\";\n";
    } else {
      print "\\n\";\n";
      print "\ttab_forw();\n";
    }
  }
  
  print "}\n";
  print "\n";

  next if ($EMPTY_ELEMENT);
  
  #
  # END tag	
  #
  print "sub xml_end_$element\n";
  print "{\n";
  if (!$LEAF_ELEMENT) {
    print "\ttab_back();\n";
    print "\ttab();\n";
  }
  print "\tprint \"</$element>\\n\";\n";
  print "}\n";
  print "\n";
}


print "1;\n";

 
