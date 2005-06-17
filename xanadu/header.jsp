<%@page import="org.jfree.chart.*"%>
<%@page import="org.xanadu.chart.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="java.awt.Rectangle"%>
<!--  <%@page errorPage="error.jsp" %> -->

<% 
    LRUCache lruc = LRUCache.getLRUCache(session, false);
    ViewProperties vp = ViewProperties.RequestToViewProperties(request);
    if(lruc == null){
        request.setAttribute("zerror", new ZError(ErrorHelper.LRUC_NULL, new Exception("Cache is null")));
  %>
        <jsp:forward page="error.jsp"/>        
        
  <%   
    }
    ChartBean cb = (ChartBean) lruc.get(vp.getID());
    if(cb == null){ 
        request.setAttribute("zerror", new ZError(ErrorHelper.CHART_BEAN_NULL, new Exception("Cache is null")));
   %>
        <jsp:forward page="error.jsp"/>        
   <%
    }   
		Theme gTheme = cb.getTheme();
		String header = gTheme.getHeader(title);
   String ZanaduURL = "";
%>

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
  <meta content="text/html; charset=ISO-8859-1"
 http-equiv="content-type">
  <title><%= header%> (Xanadu)</title>
  <link rel="stylesheet" type="text/css"
 href="http://romulus.sfbay/xanadu/html/xanadu.css">
</head>
<body vlink="#ff0000" alink="#000088" link="#0000ff"
 style="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255);">

<%
  if(gTheme.isDisplayHeader() == true){
%>

<!-- Sun Template -->
<table frame=border cellpadding="5" cellspacing="10" border="0" width="100%">
    <tbody>
      <tr>

        <td style="vertical-align: middle;background-color:#d12124; width=25%;"><h1><BR></h1><br>
        </td>
        <td valign="top" bgcolor="#ffde00" width="50%"><h1><%= header%></h1></td>
        <td valign="top" bgcolor="#594fbf" width="25%"><br></td>
      </tr>
  </tbody>
</table>
<br>
<%
}
%>
