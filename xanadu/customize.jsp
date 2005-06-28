<%@page import="org.jfree.chart.*"%>
<%@page import="org.xanadu.chart.*"%>
<%@page import="org.xanadu.view.utility.*"%>
<%@page import="java.awt.Rectangle"%>
<%@page import="java.lang.*"%>
<% String title="customize"; %>
<%@ include file="header.jsp"%>
    <div id="mainleft">
    Enter sidebar here
    </div>

    <jsp:useBean id="formHandler" class="org.xanadu.chart.ChartProperties" scope="request">
    <jsp:setProperty name="formHandler" property="*"/>
    </jsp:useBean>
    <jsp:useBean id="theme" class="org.xanadu.chart.Theme" scope="request">
    <jsp:setProperty name="theme" property="*"/>
    </jsp:useBean>

    

<%       
    ChartProperties cp = cb.getChartProperties();
    ChartData cd = cb.getChartData();
    String u = request.getParameter("u");
    if(u != null && u.equals("true")){
      /* usr has done submit, check to see if right, then do redirect */
     /* for some reason, the bean does not parse these two values */ 
     formHandler.setXTickUnit(request.getParameter("xTickUnit"));
     formHandler.setYTickUnit(request.getParameter("yTickUnit"));
     if (formHandler.validate() && theme.validate()) {
         /*
         int ibgc = Integer.parseInt(theme.getBgc(),16);
         int idgc = Integer.parseInt(theme.getDgc(),16);
         int irgc = Integer.parseInt(theme.getRgc(),16);
         int ipgc = Integer.parseInt(theme.getPgc(),16);
         java.awt.Color bgcol =  new java.awt.Color(ibgc);
         java.awt.Color rgcol =  new java.awt.Color(irgc);
         java.awt.Color dgcol =  new java.awt.Color(idgc);
         java.awt.Color pgcol =  new java.awt.Color(ipgc);
          **/
         gTheme.setBackgroundPaint(ZChartColor.getColor(theme.getBgc()));
         gTheme.setDomainGridlinePaint(ZChartColor.getColor(theme.getDgc()));
         gTheme.setRangeGridlinePaint(ZChartColor.getColor(theme.getRgc()));  
         gTheme.setPlotBackgroundPaint(ZChartColor.getColor(theme.getPgc()));
         gTheme.setForegroundAlpha(theme.getForegroundAlpha());
         gTheme.setBackgroundAlpha(theme.getBackgroundAlpha());
         gTheme.setShowShape(theme.getShowShape());
         gTheme.setShowLegend(theme.getShowLegend());
         gTheme.setAntiAlias(theme.getAntiAlias());
         gTheme.setOrientation(theme.getOrientation());
         cp.setMinAxisSize(formHandler.getMinAxisSize());
         cp.setAutoRange("No");
         cp.setStartXAxis(formHandler.getStartXAxis());
         cp.setStartYAxis(formHandler.getStartYAxis());
         cp.setEndXAxis(formHandler.getEndXAxis());
         cp.setEndYAxis(formHandler.getEndYAxis());
         cp.setIsXAxisInteger(formHandler.getIsXAxisInteger());
         cp.setIsYAxisInteger(formHandler.getIsYAxisInteger());
         cp.setXTickUnit(formHandler.getXTickUnit());
         cp.setYTickUnit(formHandler.getYTickUnit());
         cp.setSeriesColors(formHandler.getSeriesColors());
         cp.setSeriesWidth(formHandler.getSeriesWidth());
         for (int i = 0; i < cd.getDataset().getSeriesCount();i++){
             cd.getDataset().getSeries(i).setName(formHandler.getSeriesName(i));
         }
             
         /* chart specific */
         cd.setHeader(request.getParameter("header"));
         cd.setXAxis(request.getParameter("xaxis"));
         cd.setYAxis(request.getParameter("yaxis"));
         String redirectURL="xc?action=detail&id="+vp.getID();
         response.sendRedirect(redirectURL);
         return;      
   }
 }
 
%>

<div id="maincenter">
   <P>
    <form name="Standard" action="xc" method="post">
        <input type="hidden" name="id" value="<%= vp.getID() %>"> 
        <input type="hidden" name="action" value="customize"> 
        <input type="hidden" name="u" value="true"> 
        
       
        <FIELDSET><LEGEND><span class="customizeheader">Global Theme Customizations</SPAN></LEGEND>
            <table class="customizetable">            
                <tr><td>Background color</td>
                <td><input type="text" name="bgc" size="12" value="<%= theme.getBgc() %>"></td>
                <td><font size=2 color=red><%=theme.getErrorMsg("bgc")%></font></td>
                </tr>
                <tr>
                <td>Plot Background color</td>
                <td><input type="text" name="pgc" size="12" value="<%= theme.getPgc() %>"></td>
                <td><font size=2 color=red><%=theme.getErrorMsg("pgc")%></font></td>
                </tr>                
                <tr>
                <td>Y Axis GridLine color</td>
                <td><input type="text" name="dgc" size="12" value="<%= theme.getDgc() %>"> </td>
                <td><font size=2 color=red><%=theme.getErrorMsg("dgc")%></font></td>
                </tr>
        
                <tr>
                <td>X Axis GridLine color</td>
                <td><input type="text" name="rgc" size="12" value="<%= theme.getRgc() %>"> </td>
                <td><font size=2 color=red><%=theme.getErrorMsg("rgc")%></font></td>
                </tr>
                   
                <tr>
                <td>Foreground Alpha</td>
                <td><input type="text" name="foregroundAlpha" size="4" value="<%= theme.getForegroundAlpha() %>"> </td>
                <td><font size=2 color=red><%=theme.getErrorMsg("foregroundAlpha")%></font></td>
                </tr>
                <tr>
                <td>Background Alpha</td>
                <td><input type="text" name="backgroundAlpha" size="4" value="<%= theme.getBackgroundAlpha() %>"> </td>
                <td><font size=2 color=red><%=theme.getErrorMsg("backgroundAlpha")%></font></td>
                </tr>
                <tr>
                <td>Show Legends?</td>
                <td><input type="radio" name="showLegend" value="Yes" <%=theme.isRbSelected("Yes")%>>Yes       
                <input type="radio" name="showLegend" value="No"  <%=theme.isRbSelected("No")%>> No </td>
                </tr>  
                <tr>
                <td>Show Shapes?</td>
                <td><input type="radio" name="showShape" value="Yes" <%=theme.isShowShapeSelected("Yes")%>>Yes       
                <input type="radio" name="showShape" value="No"  <%=theme.isShowShapeSelected("No")%>> No </td>
                </tr>  
                <tr>
                    <td>AntiAlias?</td>
                    <td><input type="radio" name="antiAlias" value="Yes" <%=theme.isAntiAliasSelected("Yes")%>>Yes       
                    <input type="radio" name="antiAlias" value="No"  <%=theme.isAntiAliasSelected("No")%>> No </td>
                </tr>  
                <td>Plot Orientation</td>
                <td><input type="radio" name="orientation" value="Yes" <%=theme.isPlotVertical("Yes")%>>Vertical
                <input type="radio" name="orientation" value="No"  <%=theme.isPlotVertical("No")%>>Horizontal</td>
                </tr>
            </table>
        </FIELDSET>
        <P>
        <!--
        <tr>
        <td>Auto Range Axis?</td>
        <td><input type="radio" name="autoRange" value="Yes" <%=formHandler.isAutoRangeSelected("Yes")%>>Yes       
        <input type="radio" name="autoRange" value="No"  <%=formHandler.isAutoRangeSelected("No")%>> No </td>
        </tr>  
        <tr>
        <td>Minimum Axis Size</td>
        <td><input type="text" name="minAxisSize" size="4" value="<%= formHandler.getMinAxisSize() %>"> </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("minAxisSize")%></font></td>
        </tr>
        -->
        <FIELDSET><LEGEND><span class="customizeheader">Chart Specific Customizations</SPAN></LEGEND>
        <table class="customizetable">
        <tr>
        <td>Chart title</td><td><input type="text" name="header" size="40" value="<%= cd.getHeader() %>"></td>
        </tr>
        <tr>
        <td>X Axis</td><td><input type="text" name="xaxis" size="40" value="<%= cd.getXAxis() %>"></td>
        </tr>
        <tr>
        <td>Y Axis</td><td><input type="text" name="yaxis" size="40" value="<%= cd.getYAxis() %>"></td>
        </tr>
        <tr>
        <td>Start XAxis at </td>
        <td><input type="text" name="startXAxis" size="4" value="<%= cp.getStartXAxis() %>"> </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("startXAxis")%></font></td>
        </tr>
        <tr>
        <td>End X Axis at</td>
        <td><input type="text" name="endXAxis" size="4" value="<%= cp.getEndXAxis() %>"> </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("endXAxis")%></font></td>
        </tr>
        <tr>
        <td>Start Y Axis at</td>
        <td><input type="text" name="startYAxis" size="4" value="<%= cp.getStartYAxis() %>"> </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("startYAxis")%></font></td>
        </tr>
        <tr>
        <td>End Y Axis at</td>
        <td><input type="text" name="endYAxis" size="4" value="<%= cp.getEndYAxis() %>"> </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("endYAxis")%></font></td>
        </tr>
        <tr>
        <td>Is X Axis an Integer?</td>
        <td><input type="radio" name="isXAxisInteger" value="Yes" <%=cp.isXAxisIntegerSelected("Yes")%>>Yes       
        <input type="radio" name="isXAxisInteger" value="No"  <%=formHandler.isXAxisIntegerSelected("No")%>> No </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("isXAxisInteger")%></font></td>
        </tr>  
        <tr>
        <td>Is Y Axis an Integer?</td>
        <td><input type="radio" name="isYAxisInteger" value="Yes" <%=cp.isYAxisIntegerSelected("Yes")%>>Yes       
        <input type="radio" name="isYAxisInteger" value="No"  <%=formHandler.isYAxisIntegerSelected("No")%>> No </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("isYAxisInteger")%></font></td>
        </tr>  
        <tr>
        <td>X Axis Tick unit size<br>(Enter a number or auto)</td>
        <td><input type="text" name="xTickUnit" size="4" value="<%= cp.getXTickUnit() %>"> </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("xTickUnit")%></font></td>
        </tr>
        <tr>
        <td>Y Axis Tick unit size<br>(Enter a number or auto)</td>
        <td><input type="text" name="yTickUnit" size="4" value="<%= cp.getYTickUnit() %>"> </td>
        <td><font size=2 color=red><%=formHandler.getErrorMsg("yTickUnit")%></font></td>
        </tr>
        </table>       
        </FIELDSET>
        <P>
        <FIELDSET><LEGEND><span class="customizeheader">Legend/Series Customizations</SPAN></LEGEND>
        <table class="customizetable" spacing = "3">
        <tr><td class="customizetablehdr">Series</td>
            <td class="customizetablehdr">Color</td>
            <td class="customizetablehdr">Line Width</td>
        </tr>
        <% for (int i = 0; i < cd.getDataset().getSeriesCount();i++){
        %>
        <tr><td><input type="text" name="seriesName" size="40" value="<%=cd.getDataset().getSeriesName(i) %>"></td>
            <td><input type="text" name="seriesColors" size="20" value="<%= cp.getSeriesColors(i) %>"> </td>
            <td><input type="text" name="seriesWidth" size="2" value="<%= cp.getSeriesWidth(i) %>"> </td>
        </tr>
        <% } %>
        </table>
        <P>
        <table> <tr><td colspan=2><input type="submit" name="Update" value="Update"> </td></tr></table>
    </form>
    <br>
    <br>
    </div>
</body>
</html>
