<%@page import="org.xanadu.view.model.*"%>
<%@page import="org.jfree.chart.*"%>
<%@page import="org.xanadu.chart.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="java.awt.Rectangle"%>
<%@page import="org.xanadu.view.model.*"%>

<%
	String title = Theme.getInstance().getHeader("detail");
%>

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
  <meta content="text/html; charset=ISO-8859-1" http-equiv="content-type">
  <title><%= title%> (Xanadu)</title>
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
       <h1><%= title%></h1>
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
<% }else {
%>
      <td></td>
<%
			  } /* end of if(Theme.getInstance().isDisplayHeader() == true) */
%>

      <td style="vertical-align: top; width: 8px;"><br></td>
      <td style="vertical-align: top;"><br>
      <div class="p-shadow">
      <div>
      <p><img src="<%=xb.get("image")%>" title="Click to zoom" 
           style="width: <%=xb.get("width")%>px; height: <%=xb.get("height")%>px;"
           alt="<%=xb.get("title")%>" usemap="#xanadumap"> </p>
      </div>
      </div>
      </td>
      <td style="vertical-align: top;"><br>
      </td>
      <td style="vertical-align: top;"> <br>
      <div class="header"><small>Chart</small></div>
        <dl style="text-align: left;">
         <% for(int i = 0; i< 14; i++){ %>
          <dt><%= xb.get("chart"+i) %> </dt>
          <% } %>                
      </dl>
      </td>
    </tr>

    <tr>
      <td style="vertical-align: top; "><br>
      </td>
      <td style="vertical-align: top; width: 8px;"><br>      </td>
      <td style="text-align: center; vertical-align: middle;">
<%=xb.get("split")%> |       
<a href="<%=xb.get("filter")%>">Filter</a> | 
<a href="<%=xb.get("addafunc")%>">Add a function</a> |
<a href="<%=xb.get("datadump")%>">Data Dump</a> | 
<a href="<%=xb.get("htmldump")%>">HTML Dump</a> | 
<a href="<%=xb.get("save")%>">Save image</a> | 
<a href="<%=xb.get("histogram")%>">Histogram</a> | 
<a href="<%=xb.get("total")%>">Total</a> | 
<a href="<%=xb.get("average")%>">Average</a><br>
<b>Moving Average:</b> 
<a href="<%=xb.get("ma5")%>">5</a>| 
<a href="<%=xb.get("ma10")%>">10</a> | 
<a href="<%=xb.get("ma20")%>">20</a> | 
<a href="<%=xb.get("ma50")%>">50</a> | 
<a href="<%=xb.get("ma100")%>">100</a>| 
<a href="<%=xb.get("macustom")%>">Custom</a> |
<a href="<%=xb.get("bspline")%>">BSpline</a> <br>
<b>Zoom:</b>

<%= xb.get("zoominx") %> | <%= xb.get("zoominy") %> | 
<%= xb.get("zoomoutx") %> | <%= xb.get("zoomouty") %> |
<%= xb.get("zoomin") %> | <%= xb.get("zoomout") %> |     


<span style="font-weight: bold;">Size</span>: 
<%=xb.get("sizesmall")%> | 
<a href="<%=xb.get("default")%>">default</a> | 
<%=xb.get("sizelarge")%> | 
<a href="<%=xb.get("sizecustom")%>">Custom Size</a><BR>

<% if(Theme.getInstance().isDisplayHeader() == false) {
%>
       <a href="<%=xb.get("merge")%>">Merge Charts</a> | <%=xb.get("customize")%>
<% } %>
      </td>
      <td style="vertical-align: top;"><br>
      </td>
      <td style="vertical-align: top;"><br>
      </td>
    </tr>
  </tbody>
</table>

<!-- DONT DELELTE -->
<%= xb.get("map")%>

</body>
</html>
