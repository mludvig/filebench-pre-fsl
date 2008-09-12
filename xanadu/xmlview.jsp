<%@page import="org.jfree.chart.*"%>
<%@page import="org.xanadu.chart.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="org.xanadu.view.model.*"%>
<%@page import="java.awt.Rectangle"%>
<%@page import="java.util.*"%>

<%
    String title = Theme.getInstance().getHeader("xmlview");
%>


<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
    <meta content="text/html; charset=ISO-8859-1"
    http-equiv="content-type">
    <title><%=title%></title>   
    <link rel="stylesheet" type="text/css" href="http://mde.sfbay/%7Eneel/xanadu.css">
</head>
<body vlink="#ff0000" alink="#000088" link="#0000ff"
 style="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255);">

<% 
    XmlViewBean xvb = (XmlViewBean) request.getAttribute("bean");
%>
 


<table style="text-align: left;" border="0" cellspacing="1" cellpadding="2">
  <tbody>
	<% if(Theme.getInstance().isDisplayHeader() == true) {
	%>

    <tr>
      <td style="vertical-align: top; background-color: rgb(89, 79, 191); height: 87px; width: 50px;">
      <img style="width: 107px; height: 54px;" alt="Sun" src="http://www.sun.com/im/sun_logo.gif"><br>
      </td>
      <td style="vertical-align: top; width: 8px;"> <br> </td>
      <td style="background-color: rgb(251, 226, 73); vertical-align: middle;" colspan="1" rowspan="1">
       <h1><%=title%></h1>
      </td>
    </tr>
    <tr>
      <td style="vertical-align: top; background-color: rgb(255, 255, 255); width: 50px;"><br>
      <div id="sidebar">
       <div><a href="<%=xvb.get("home")%>">Home</a></div>
       <div><a href="<%=xvb.get("xanadu2")%>">Xanadu2</a></div>
       <div><a href="<%=xvb.get("merge")%>">Merge Charts</a></div>
       <div><%=xvb.get("customize")%></div>
       <div><a href="<%=xvb.get("pae")%>">PAE</a></div>
      </div>
      </td>
<% } else {
 %>
    <td></td>
<%
  } /* end of if(Theme.getInstance().isDisplayHeader() == true) */
%>

      <td style="vertical-align: top; width: 8px;"> <br> </td>
      <td>
      <div style="text-align: right;" >
      <a href="<%=xvb.get("smaller")%>">Smaller</a>|
      <a href="<%=xvb.get("bigger")%>">Bigger</a>
      </div>
      <div style="text-align: center;" class="header"><%= xvb.get("file")%></div>
      <div class="container">
      <div class="spacer">
       &nbsp;
      </div>
<%
       String tdclass="odd";
       for(int i = 0; i<xvb.getSize();i++){
%>                         
          <div class="float">
             <a href="<%= xvb.get("url"+i)%>">
             <img src="<%= xvb.get("img"+i)%>" width="<%= xvb.get("w")%>" height="<%= xvb.get("h")%>" alt="<%= xvb.get("heading"+i)%>" title="Click to examine in more detail"></img></a>            
             <p style="width:<%= xvb.get("w")%>px;">
             <a href="<%= xvb.get("url"+i)%>"><%= xvb.get("heading"+i)%></a>
             </P>
          </div>    
<%
    }   
  %>
<div class="spacer">
  &nbsp;
</div>
</div>
<div >Click on image or link to look in more detail</div>
</body>
</html>
