<%@page import="org.xanadu.view.model.*"%>
<%@page import="org.jfree.chart.*"%>
<%@page import="org.xanadu.chart.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="java.awt.Rectangle"%>
<%@page import="org.xanadu.view.model.*"%>

<%
    String title = Theme.getInstance().getHeader("advanced");
%>


<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
  <meta content="text/html; charset=ISO-8859-1" http-equiv="content-type">
  <title><%= title%></title>
  <link rel="stylesheet" type="text/css" href="http://romulus.sfbay/xanadu/html/xanadu.css">
</head>
<body vlink="#ff0000" alink="#000088" link="#0000ff" style="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255);">


<% 
    XanaduBean xb = (XanaduBean) request.getAttribute("bean");
%>

<table style="text-align: left;" border="0" cellspacing="0" cellpadding="2">
  <tbody>
<% if(Theme.getInstance().isDisplayHeader() == true) {
%>
    <tr>
      <td class="sunblue" style="vertical-align: top; height: 87px; width: 110px;">
      <img style="width: 107px; height: 54px;" alt="Sun" src="http://www.sun.com/im/sun_logo.gif"><br>
      </td>
      <td style="vertical-align: top; width: 8px;"> <br> </td>
      <td class="sunyellow" style="vertical-align: middle;" colspan="1" rowspan="1">
       <h1><%=title%></h1>
      </td>
      <td style="vertical-align: top;"><br>
      </td>
      <td class="sunred" style="vertical-align: top;"><br>
      </td>
    </tr>
    <tr>
      <td style="vertical-align:top"><br>
      <div id="sidebar">
       <div><a href="<%=xb.get("home")%>">Home</a></div>
       <div><a href="<%=xb.get("xanadu2")%>">Xanadu2</a></div>
       <div><a href="<%=xb.get("merge")%>">Merge Charts</a></div>
       <div><%=xb.get("customize")%></div>
       <div><a href="<%=xb.get("pae")%>">PAE</a></div>
      </div>
      </td>
<% } else {
%>
			<td></td>
<%
	} /* end of if(Theme.getInstance().isDisplayHeader() == true) */
%>
      <td style="vertical-align: top; width: 8px;"><br></td>
      <td style="vertical-align: top;"><br>

<!-- start customization -->      
      
      <h2>Advanced configuration </h2>
<table class="bordered" width="100%">
<tr><td><a name="DataDump"></a>Data Dump</td>
 <td><form name="Standard" action="xc" method="get"> 
    <input type="hidden" name="action" value="dump">
    <input type="hidden" name="id" value="<%= xb.get("id")%>">
    <input type="hidden" name="p" value="<%= xb.get("pattern")%>">
    <input type="text" name="sep" size="2" value=":">
    <input type="submit" name="DataDump" value="Dump"></form>
 </td>
</tr>
<tr><td class="odd"><a name="MovingAverge"></a>Moving Average</td><td class="odd">
    <form name="Standard" action="xc" method="get"> 
    <input type="hidden" name="action" value="MovingAverage">
    <input type="hidden" name="id" value="<%= xb.get("id")%>">
    <input type="hidden" name="action" value="MovingAverage">
    Add a <input type="text" name="p" size="4" value="30"> Point Moving Average for Series
    <input type="text" name="p" size="20" value="all"> (for ex c14.*)
    <input type="submit" name="xc" value="Submit"></form>
</td></tr>
<tr><td><a name="PlotAFunc"></a>Plot a Function</td><td>
    <form name="Standard" action="xc" method="get"> 
    <input type="hidden" name="action" value="add">
    <input type="hidden" name="id" value="<%= xb.get("id")%>">
     <input type="hidden" name="action" value="AddAFunc">
    Y = <input type="text" name="p" size="20" value="">
    Start X = <input type="text" name="p" size="4" value="0">
    End X = <input type="text" name="p" size="4" value="100">
    Step size = <input type="text" name="p" size="4" value="1">
    <input type="submit" name="AddAFunc" value="AddAFunc"></form>
</td><tr>    
<tr><td><a name="PlotAFunc"></a>Plot a Function</td><td>
    <form name="Standard" action="xc" method="get"> 
    <input type="hidden" name="action" value="adda">
    <input type="hidden" name="id" value="<%= xb.get("id")%>">
     <input type="hidden" name="action" value="AddAFuncAdvanced">
    Y = <input type="text" name="p" size="20" value="">
    <input type="submit" name="AddAFuncAdvanced" value="AddAFuncAdvanced">
		<BR>
		The Advanced "AddAFunction" allows you limited spread-sheet like
		functionality where each data series is denoted by 'a', 'b',
		etc.. You can enter functions of the a*60/(c+b) etc...
		</form>
</td><tr>    

<tr><td class="odd"><a name="Filter"></a>Filter</td><td class="odd">
    <form name="Standard" action="xc" method="get"> 
    <input type="hidden" name="action" value="filter">
        <input type="hidden" name="id" value="<%= xb.get("id")%>">    
        <input type="hidden" name="action" value="Filter">
        <input type="text" name="p" size="12" value="<%= xb.get("pattern") %>"> 
        <input type="hidden" name="charttype" value="<%= xb.get("charttype")%>">
        <input
        type="submit" name="Update" value="Update"> <br><i>For example: .*c14.*</i>
</td></tr>
<tr><td><a name="Zoom"></a>Viewing Rectangle</td><td>
   <form name="Standard" action="<%= xb.get("default")%>" method="get">
        <input type="hidden" name="id" value="<%= xb.get("id")%>">        
        <input type="hidden" name="charttype" value="<%= xb.get("charttype")%>">  
x1<input type="text" name="x1" size="4" value="<%= xb.get("x")%>"> 
y1<input type="text" name="y1" size="4" value="<%= xb.get("y")%>">
x2<input type="text" name="x2" size="4" value="<%= xb.get("width")%>">
y2<input type="text" name="y2" size="4" value="<%= xb.get("height")%>"> 
<input type="submit" name="Update" value="Update"> 
        </form>
</td></tr>
<tr><td class="odd"><a name="Size"></a>Size</td><td class="odd">
    <form name="Standard" action="<%= xb.get("default")%>" method="get">
        <input type="hidden" name="id" value="<%= xb.get("id")%>">        
        <input type="hidden" name="charttype" value="<%= xb.get("charttype")%>"> 
        <input type="text" name="w" size="4" value="<%= xb.get("width")%>"> 
        <input type="text" name="h" size="4" value="<%= xb.get("height")%>"> 
        <input type="submit" name="Update" value="Update"> 
</td></tr>
<tr><td ><a name="freq"></a>Frequency Plot</td><td>
    <form name="Standard" action="xc" method="get"> 
    <input type="hidden" name="action" value="histogram">
        <input type="hidden" name="id" value="<%= xb.get("id")%>">    
        <input type="hidden" name="action" value="Freq">
        No of Bins: <input type="text" name="p" size="3" value="100">
        For Series <input type="text" name="p" size="12" value="all">(Enter regular expression)
        <input
        type="submit" name="Update" value="Update"> 
</td></tr>
</table>
      
<!-- end customization -->      
      
      </td>
      <td style="vertical-align: top;"><br>
      </td>
      <td style="vertical-align: top;"> <br>    
      </td>
    </tr>

    <tr>
      <td style="vertical-align: top; "><br>
      </td>
      <td style="vertical-align: top; width: 8px;"><br>      </td>
      <td style="text-align: center; vertical-align: middle;">
      </td>
      <td style="vertical-align: top;"><br>
      </td>
      <td style="vertical-align: top;"><br>
      </td>
    </tr>
  </tbody>
</table>




<hr>

</body>
</html>

