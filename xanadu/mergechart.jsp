<%@page import="org.jfree.chart.*"%>
<%@page import="org.xanadu.chart.*"%>
<%@page import="org.xanadu.view.model.*"%>
<%@page import="org.xanadu.view.controller.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="java.awt.Rectangle"%>
<%@page import="java.util.*"%>

<%
    String title = Theme.getInstance().getHeader("merge");
%>


<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
    <meta content="text/html; charset=ISO-8859-1"
    http-equiv="content-type">
    <title><%= title%> (Xanadu)</title>   
    <link rel="stylesheet" type="text/css" href="http://mde.sfbay/%7Eneel/xanadu.css">
</head>
<body vlink="#ff0000" alink="#000088" link="#0000ff"
 style="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255);">
 
<% 
    MergeChartBean xb = (MergeChartBean) request.getAttribute("bean");
%>
 
<form name="Standard" action="xc" method="get">
<input type="hidden" name="action" value="merge">
<input type="hidden" name="step" value="2">
<table style="text-align: left;" border="0" cellspacing="1" cellpadding="2">
  <tbody>
    <tr>
	<% if(Theme.getInstance().isDisplayHeader() == true) {
	 %>

      <td style="vertical-align: top; background-color: rgb(89, 79, 191); height: 87px; width: 50px;">
      <img style="width: 107px; height: 54px;" alt="Sun" src="http://www.sun.com/im/sun_logo.gif"><br>
      </td>
      <td style="vertical-align: top; width: 8px;"> <br> </td>
      <td style="background-color: rgb(251, 226, 73); vertical-align: middle;" colspan="1" rowspan="1">
       <h1><%= title%></h1>
      </td>
    </tr>
    <tr>
      <td style="vertical-align: top; background-color: rgb(255, 255, 255); width: 50px;"><br>
      <div id="sidebar">
       <div><a href="<%=xb.get("home")%>">Home</a></div>
       <div><a href="<%=xb.get("xanadu2")%>">Xanadu2</a></div>
       <div><a href="<%=xb.get("merge")%>">Merge Charts</a></div>
       <div><%=xb.get("customize")%></div>
       <div><a href="<%=xb.get("pae")%>">PAE</a></div>
      </div>
      </td>
	<% } %>
      <td style="vertical-align: top; width: 8px;"> <br> </td>
      <td>
      <BR>
      <!-- begin mergechart -->
<%      if(xb.hasErrors()){ 
%>    
      <BR><div class="myblock"><%= xb.getAllErrorsAsHTML()%></div>
<% } %>      
      <FIELDSET><LEGEND><span class="customizeheader"><%=xb.get("header")%></SPAN></LEGEND>
      <P>
    <table cellspacing="2" cellpadding="2">
<% if (xb.getStep().equals("1")){
      for(int i = 0; i < xb.getNoFiles(); i++){
%>
         <tr><td><input type="checkbox" name="file" value="<%=xb.get("file"+i)%>">
           <a href="<%= xb.get("fileurl"+i)%>"><%= xb.get("file"+i)%></a></td></tr>
<%     }   
%>
      <tr><td><input type="checkbox" name="dynamic" value="yes">Use Dynamically generated charts</td></tr>
      <tr><td>Enter a filename (optional): <input type="file" name="file" size="40" value=""></td></tr>

<%
    }//end step1
    else {        
        //step 2
                
%>
<input type="hidden" name="nextstep" value="3">
<input type="hidden" name="step" value="2">
<TR>
<%      
        for(int i = 0; i < xb.getNoFiles();i++){   
            String file =  xb.get("filefullpath"+i);
%>
<input type="hidden" name="file" value="<%= file%>">
<td class="mergetd"><h3><%= xb.get("file"+i)%></h3>
<%
       String sfilesize = xb.get("filesiz"+i);
       if(sfilesize == null) continue;
       int filesiz = Integer.parseInt(sfilesize);
       for(int j = 0; j < filesiz; j++){ 
            String group = xb.get(file+"-grp"+j);            
%>     <input type="checkbox" name="group" value="<%= group.hashCode()%>">
       <a href="<%=xb.get(file+"-grpurl"+j)%>"><%= group%></a><br>
<%                       
       
       }//end for
       out.println("</td>");
       if((i+1)%3==0)out.println("</tr><tr>");      
      }
        //check to see if we have to show dynamic data
      if(xb.getNoDynamic() > 0){
%>          
        <input type="hidden" name="dynamic" value="true">  
        <td class="mergetd"><h3>Dynamic Data</h3>
<%       for(int k = 0; k < xb.getNoDynamic(); k++){       
%>                        
          <input type="checkbox" name="id" value="<%=xb.get("dynid"+k)%>">
          <a href="<%=xb.get("dynurl"+k)%>"><%=xb.get("dynheader"+k) %></a>
           <BR>
<%                        
       } //end for dynamic
       out.println("</td>");
       }//end if dynamic
        out.println("</td></tr>");
    
    }//end step2
%>
<table> <tr><td colspan=2><input type="submit" name="Update" value="Next"> </td></tr></table>
</tr></table>

<P>
</td></tr>
</table>

</form>
</body>
</html>
