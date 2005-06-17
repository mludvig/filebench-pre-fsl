<%@page isErrorPage="true" %>
<%@page contentType="text/html"%>
<%@page import="org.xanadu.chart.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="org.xanadu.view.model.*"%>
<%
    String title = Theme.getInstance().getHeader("error");
%>

<HTML>
<HEAD><TITLE><%=title%></TITLE>
<link rel="stylesheet" type="text/css" href="http://romulus.sfbay/xanadu/html/xanadu.css">
</HEAD>
<BODY>
<!-- Sun Template -->
<% if(Theme.getInstance().isDisplayHeader() == true) {
%>
<table frame=border cellpadding="5" cellspacing="10" border="0" width="100%">
    <tbody>
      <tr>

        <td style="vertical-align: middle;background-color:#d12124; width=25%;"><br>
        </td>
        <td valign="top" bgcolor="#ffde00" width="50%"></td>
        <td valign="top" bgcolor="#594fbf" width="25%"></td>
      </tr>
  </tbody>
</table>
<% } %>


<br>
<center><H1><%=title%></H1></center>
<P>
There was an error processing your request.
<P>
<% XanaduBean xb = (XanaduBean) request.getAttribute("bean");
   /*ZError zerr = null;
   if(xb != null){
    zerr = new ZError(xb.getErrno(), xb.getException());
   }
    **/
   if(xb != null){
       
%>

<% if(xb.getErrno() == ErrorHelper.XML_FILE_NOT_FOUND) {
    String file = (String) request.getParameter("file");
    if(file == null || file.length() == 0)
        file="/null";
%>
   <div class="errhdr">The File <i> <%= file %> </i> was not found
   <P>
   <form name="Standard" action="xc" method="get">
        <input type="hidden" name="action" value="view"> 
        <input type="hidden" name="old" value="<%=file.substring(0,file.lastIndexOf("/")) %>">
        Choose File: <input type="text" name="file" size="80" value="<%= file %>"> 
              <input type="submit" name="Submit" value="Submit"> 
        </form>
   </div>
<% } else if(xb.getErrno() == ErrorHelper.XML_PARSE_ERROR) {
    String file = (String) request.getParameter("file");
%>
   <div class="errhdr">There was an error Parsing file: <i><%= file %></i> 
   <P><form name="Standard" action="xc" method="get">
        <input type="hidden" name="action" value="view">
        
        Choose another File: <input type="text" name="file" size="80" value="<%= file %>"> 
              <input type="submit" name="Submit" value="Submit"> 
        </form>
   </div>
<% } else if(xb.getErrno() == ErrorHelper.UNKNOWN_HOST) {
    String file = (String) request.getParameter("file");
%>
   <div class="errhdr">There was an error connecting to the specified host: <i><%= file %></i> 
   <P><form name="Standard" action="xc" method="get">
        <input type="hidden" name="action" value="view"> 
        Choose another URL: <input type="text" name="file" size="80" value="<%= file %>"> 
              <input type="submit" name="Submit" value="Submit"> 
        </form>
   </div>
<% } else if(xb.getErrno() == ErrorHelper.CHART_DATA_NULL) {
    String file = (String) request.getParameter("file");
%>
   <div class="errhdr">No Displayable stat groups in <i><%= file %></i> 
   <P><form name="Standard" action="xc" method="get">
        <input type="hidden" name="action" value="view"> 
        Choose another File: <input type="text" name="file" size="80" value="<%= file %>"> 
              <input type="submit" name="Submit" value="Submit"> 
        </form>
   </div>
<% } %>

<table class="bordered" padding="3">
<tr><td class="errhdr">Short Message</td><td><%= ErrorHelper.getInstance().getShortDescForError(xb.getErrno()) %></td></tr>
<tr><td class="errhdr">Long Message</td><td><%= ErrorHelper.getInstance().getLongDescForError(xb.getErrno()) %></td></tr>
<tr><td class="errhdr">Exception</td><td><%= xb.getException().getMessage() %></td></tr>

<!-- < zerr.getException().printStackTrace(new java.io.PrintWriter(out)); %></small></td></tr> -->
</table>
       
       
<% } //zerr!=null  
 else if (exception != null){ %>
<TABLE>
<tr>
<td>Exception Class:</td>
<td><%= exception.getClass() %></td>
</tr>

<tr>
<td>Message:</td>
<td><%= exception.getMessage() %></td>
</tr>
<tr>
   <td>Cause:</td>
   <td><%= request.getParameter("cause") %></td>
</tr>
<tr>
   <td>Stack Trace</td><td>
   <% exception.printStackTrace(new java.io.PrintWriter(out)); %>
    </td>
</tr>
</table>
<% } %>


</BODY>
</HTML>
