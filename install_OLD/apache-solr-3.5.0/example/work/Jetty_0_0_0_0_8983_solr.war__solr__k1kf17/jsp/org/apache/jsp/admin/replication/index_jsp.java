package org.apache.jsp.admin.replication;

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.jsp.*;
import java.util.Collection;
import java.util.Date;
import org.apache.solr.common.util.NamedList;
import org.apache.solr.common.util.SimpleOrderedMap;
import org.apache.solr.request.LocalSolrQueryRequest;
import org.apache.solr.response.SolrQueryResponse;
import org.apache.solr.request.SolrRequestHandler;
import java.util.Map;
import org.apache.solr.handler.ReplicationHandler;
import org.apache.solr.core.SolrConfig;
import org.apache.solr.core.SolrCore;
import org.apache.solr.schema.IndexSchema;
import java.io.File;
import java.net.InetAddress;
import java.io.StringWriter;
import org.apache.solr.core.Config;
import org.apache.solr.common.util.XML;
import org.apache.solr.common.SolrException;
import org.apache.lucene.LucenePackage;
import java.net.UnknownHostException;

public final class index_jsp extends org.apache.jasper.runtime.HttpJspBase
    implements org.apache.jasper.runtime.JspSourceDependent {


  // only try to figure out the hostname once in a static block so 
  // we don't have a potentially slow DNS lookup on every admin request
  static InetAddress addr = null;
  static String hostname = "unknown";
  static {
    try {
      addr = InetAddress.getLocalHost();
      hostname = addr.getCanonicalHostName();
    } catch (UnknownHostException e) {
      //default to unknown
    }
  }


public NamedList executeCommand(String command, SolrCore core, SolrRequestHandler rh){
    NamedList namedlist = new SimpleOrderedMap();
    namedlist.add("command", command);
    LocalSolrQueryRequest solrqreq = new LocalSolrQueryRequest(core, namedlist);
    SolrQueryResponse rsp = new SolrQueryResponse();
    core.execute(rh, solrqreq, rsp);
    namedlist = rsp.getValues();
	return namedlist;
}

  private static final JspFactory _jspxFactory = JspFactory.getDefaultFactory();

  private static java.util.Vector _jspx_dependants;

  static {
    _jspx_dependants = new java.util.Vector(2);
    _jspx_dependants.add("/admin/replication/header.jsp");
    _jspx_dependants.add("/admin/replication/../_info.jsp");
  }

  private org.apache.jasper.runtime.ResourceInjector _jspx_resourceInjector;

  public Object getDependants() {
    return _jspx_dependants;
  }

  public void _jspService(HttpServletRequest request, HttpServletResponse response)
        throws java.io.IOException, ServletException {

    PageContext pageContext = null;
    HttpSession session = null;
    ServletContext application = null;
    ServletConfig config = null;
    JspWriter out = null;
    Object page = this;
    JspWriter _jspx_out = null;
    PageContext _jspx_page_context = null;

    try {
      response.setContentType("text/html; charset=utf-8");
      pageContext = _jspxFactory.getPageContext(this, request, response,
      			null, true, 8192, true);
      _jspx_page_context = pageContext;
      application = pageContext.getServletContext();
      config = pageContext.getServletConfig();
      session = pageContext.getSession();
      out = pageContext.getOut();
      _jspx_out = out;
      _jspx_resourceInjector = (org.apache.jasper.runtime.ResourceInjector) application.getAttribute("com.sun.appserv.jsp.resource.injector");

      out.write('\n');
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write('\n');
      out.write('\n');
      out.write("\n");
      out.write("<!-- $Id: header.jsp 1151947 2011-07-28 18:07:54Z hossman $ -->\n");
      out.write("\n");
      out.write("\n");

request.setCharacterEncoding("UTF-8");

      out.write("\n");
      out.write("\n");
      out.write("<html>\n");
      out.write("<head>\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write('\n');
      out.write('\n');

  // 
  SolrCore  core = (SolrCore) request.getAttribute("org.apache.solr.SolrCore");
  if (core == null) {
    response.sendError( 404, "missing core name in path" );
    return;
  }
    
  SolrConfig solrConfig = core.getSolrConfig();
  int port = request.getServerPort();
  IndexSchema schema = core.getSchema();

  // enabled/disabled is purely from the point of a load-balancer
  // and has no effect on local server function.  If there is no healthcheck
  // configured, don't put any status on the admin pages.
  String enabledStatus = null;
  String enabledFile = solrConfig.get("admin/healthcheck/text()",null);
  boolean isEnabled = false;
  if (enabledFile!=null) {
    isEnabled = new File(enabledFile).exists();
  }

  String collectionName = schema!=null ? schema.getName():"unknown";

  String defaultSearch = "";
  { 
    StringWriter tmp = new StringWriter();
    XML.escapeCharData
      (solrConfig.get("admin/defaultQuery/text()", ""), tmp);
    defaultSearch = tmp.toString();
  }

  String solrImplVersion = "";
  String solrSpecVersion = "";
  String luceneImplVersion = "";
  String luceneSpecVersion = "";

  { 
    Package p;
    StringWriter tmp;

    p = SolrCore.class.getPackage();

    tmp = new StringWriter();
    solrImplVersion = p.getImplementationVersion();
    if (null != solrImplVersion) {
      XML.escapeCharData(solrImplVersion, tmp);
      solrImplVersion = tmp.toString();
    }
    tmp = new StringWriter();
    solrSpecVersion = p.getSpecificationVersion() ;
    if (null != solrSpecVersion) {
      XML.escapeCharData(solrSpecVersion, tmp);
      solrSpecVersion = tmp.toString();
    }
  
    p = LucenePackage.class.getPackage();

    tmp = new StringWriter();
    luceneImplVersion = p.getImplementationVersion();
    if (null != luceneImplVersion) {
      XML.escapeCharData(luceneImplVersion, tmp);
      luceneImplVersion = tmp.toString();
    }
    tmp = new StringWriter();
    luceneSpecVersion = p.getSpecificationVersion() ;
    if (null != luceneSpecVersion) {
      XML.escapeCharData(luceneSpecVersion, tmp);
      luceneSpecVersion = tmp.toString();
    }
  }
  
  String cwd=System.getProperty("user.dir");
  String solrHome= solrConfig.getInstanceDir();
  
  boolean cachingEnabled = !solrConfig.getHttpCachingConfig().isNever304(); 

      out.write('\n');
      out.write("\n");
      out.write("\n");
      out.write("<script>\n");
      out.write("var host_name=\"");
      out.print( hostname );
      out.write("\"\n");
      out.write("</script>\n");
      out.write("\n");
      out.write("<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n");
      out.write("<link rel=\"stylesheet\" type=\"text/css\" href=\"../solr-admin.css\">\n");
      out.write("<link rel=\"icon\" href=\"../favicon.ico\" type=\"image/ico\" />\n");
      out.write("<link rel=\"shortcut icon\" href=\"../favicon.ico\" type=\"image/ico\" />\n");
      out.write("<title>Solr replication admin page</title>\n");
      out.write("<script type=\"text/javascript\" src=\"../jquery-1.4.3.min.js\"></script>\n");
      out.write("\n");
      out.write('\n');
      out.write('\n');

final Map<String,SolrRequestHandler> all = core.getRequestHandlers(ReplicationHandler.class);
  if(all.isEmpty()){
    response.sendError( 404, "No ReplicationHandler registered" );
    return;
  }

// :HACK: we should be more deterministic if multiple instances
final SolrRequestHandler rh = all.values().iterator().next();

NamedList namedlist = executeCommand("details",core,rh);
NamedList detailsMap = (NamedList)namedlist.get("details");

      out.write("\n");
      out.write("</head>\n");
      out.write("\n");
      out.write("<body>\n");
      out.write("<a href=\"..\"><img border=\"0\" align=\"right\" height=\"78\" width=\"142\" src=\"../solr_small.png\" alt=\"Solr\"></a>\n");
      out.write("<h1>Solr replication (");
      out.print( collectionName );
      out.write(") \n");
      out.write("\n");

if(detailsMap != null){
  if( "true".equals(detailsMap.get("isMaster")) && "true".equals(detailsMap.get("isSlave")))
    out.println(" Master & Slave");
  else if("true".equals(detailsMap.get("isMaster")))
    out.println(" Master");
  else if("true".equals(detailsMap.get("isSlave")))
    out.println(" Slave");
}

      out.write("</h1>\n");
      out.write("\n");
      out.print( hostname );
      out.write(':');
      out.print( port );
      out.write("<br/>\n");
      out.write("cwd=");
      out.print( cwd );
      out.write("  SolrHome=");
      out.print( solrHome );
      out.write('\n');
      out.write("\n");
      out.write("\n");
      out.write("<br clear=\"all\" />\n");
      out.write("(<a href=\"http://wiki.apache.org/solr/SolrReplication\">What Is This Page?</a>)\n");
      out.write("<br clear=\"all\" />\n");
      out.write("<table>\n");
      out.write("\n");


  final SolrCore solrcore = core;


      out.write('\n');

NamedList slave = null, master = null;
if (detailsMap != null)
   if ("true".equals(detailsMap.get("isSlave")))
       if(detailsMap.get("slave") != null){
           slave = (NamedList)detailsMap.get("slave");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("    <strong>Master</strong>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");
      out.print(slave.get("masterUrl"));
      out.write("\n");
      out.write("    ");

    NamedList nl = (NamedList) slave.get("masterDetails");
    if(nl == null)
    	out.print(" - <b>Unreachable</b>");
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");

    if (nl != null) {         
      nl = (NamedList) nl.get("master");
      if(nl != null){      
  
      out.write("\n");
      out.write("<tr>  \n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>Latest Index Version:");
      out.print(nl.get("indexVersion"));
      out.write(", Generation: ");
      out.print(nl.get("generation"));
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>Replicatable Index Version:");
      out.print(nl.get("replicatableIndexVersion"));
      out.write(", Generation: ");
      out.print(nl.get("replicatableGeneration"));
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");

}
}
      out.write("\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("    <strong>Poll Interval</strong>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");
      out.print(slave.get("pollInterval"));
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
}
      out.write("\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("    <strong>Local Index</strong>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");

      if (detailsMap != null)
        out.println("Index Version: " + detailsMap.get("indexVersion") + ", Generation: " + detailsMap.get("generation"));
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");
 if (null != core.getIndexDir()) {
      File dir = new File(core.getIndexDir());
      out.println("Location: " + dir.getCanonicalPath());
    }
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>");
 if (detailsMap != null)
    out.println("Size: " + detailsMap.get("indexSize"));
  
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");

  if (detailsMap != null)
    if ("true".equals(detailsMap.get("isMaster"))) 
       if(detailsMap.get("master") != null){
           master = (NamedList) detailsMap.get("master");

      out.write("\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>\n");
      out.write("    ");
out.println("Config Files To Replicate: " + master.get("confFiles"));
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>\n");
      out.write("    ");
out.println("Trigger Replication On: " + master.get("replicateAfter")); 
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
}
      out.write('\n');
      out.write('\n');

  if ("true".equals(detailsMap.get("isSlave")))
    if (slave != null) {
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Times Replicated Since Startup: " + slave.get("timesIndexReplicated"));
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Previous Replication Done At: " + slave.get("indexReplicatedAt"));
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Config Files Replicated At: " + slave.get("confFilesReplicatedAt"));
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Config Files Replicated: " + slave.get("confFilesReplicated"));
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Times Config Files Replicated Since Startup: " + slave.get("timesConfigReplicated"));
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td>\n");
      out.write("  </td>\n");
      out.write("  <td>\n");
      out.write("    ");

      if (slave.get("nextExecutionAt") != null)
        if (slave.get("nextExecutionAt") != "")
          out.println("Next Replication Cycle At: " + slave.get("nextExecutionAt"));
        else if ("true".equals(slave.get("isPollingDisabled")))
          out.println("Next Replication Cycle At: Polling disabled.");
        else {
          NamedList nl1 = (NamedList) slave.get("masterDetails");
          if(nl1 != null){
          	NamedList nl2 = (NamedList) nl1.get("master");
          	if(nl2 != null)
          		out.println("Next Replication Cycle At: After " + nl2.get("replicateAfter") + " on master.");
          }
        }
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");

  if ("true".equals(slave.get("isReplicating"))) {

      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td><strong>Current Replication Status</strong>\n");
      out.write("\n");
      out.write("  <td>\n");
      out.write("    ");
out.println("Start Time: " + slave.get("replicationStartTime"));
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Files Downloaded: " + slave.get("numFilesDownloaded") + " / " + slave.get("numFilesToDownload"));
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Downloaded: " + slave.get("bytesDownloaded") + " / " + slave.get("bytesToDownload") + " [" + slave.get("totalPercent") + "%]");
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Downloading File: " + slave.get("currentFile") + ", Downloaded: " + slave.get("currentFileSizeDownloaded") + " / " + slave.get("currentFileSize") + " [" + slave.get("currentFileSizePercent") + "%]");
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>\n");
      out.write("    ");

      out.println("Time Elapsed: " + slave.get("timeElapsed") + ", Estimated Time Remaining: " + slave.get("timeRemaining") + ", Speed: " + slave.get("downloadSpeed") + "/s");
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
}
      out.write("\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td><strong>Controls</strong>\n");
      out.write("  </td>\n");
      out.write("  <td>");

    String pollVal = request.getParameter("poll");
    if (pollVal != null)
      if (pollVal.equals("disable"))
        executeCommand("disablepoll", core, rh);
      else if (pollVal.equals("enable"))
        executeCommand("enablepoll", core, rh);
    if(slave != null)
    	if ("false".equals(slave.get("isPollingDisabled"))) {
  
      out.write("\n");
      out.write("\n");
      out.write("    <form name=polling method=\"POST\" action=\"./index.jsp\" accept-charset=\"UTF-8\">\n");
      out.write("      <input name=\"poll\" type=\"hidden\" value=\"disable\">\n");
      out.write("      <input class=\"stdbutton\" type=\"submit\" value=\"Disable Poll\">\n");
      out.write("    </form>\n");
      out.write("\n");
      out.write("    ");
}
      out.write("\n");
      out.write("    ");

      if(slave != null)
      	if ("true".equals(slave.get("isPollingDisabled"))) {
    
      out.write("\n");
      out.write("\n");
      out.write("    <form name=polling method=\"POST\" action=\"./index.jsp\" accept-charset=\"UTF-8\">\n");
      out.write("      <input name=\"poll\" type=\"hidden\" value=\"enable\">\n");
      out.write("      <input class=\"stdbutton\" type=\"submit\" value=\"Enable Poll\">\n");
      out.write("    </form>\n");
      out.write("    ");

      }
    
      out.write("\n");
      out.write("\n");
      out.write("  </td>\n");
      out.write("</tr>\n");
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td></td>\n");
      out.write("  <td>\n");
      out.write("    <form name=replicate method=\"POST\" action=\"./index.jsp\" accept-charset=\"UTF-8\">\n");
      out.write("      <input name=\"replicate\" type=\"hidden\" value=\"now\">\n");
      out.write("      <input name=\"replicateButton\" class=\"stdbutton\" type=\"submit\" value=\"Replicate Now\">\n");
      out.write("    </form>\n");
      out.write("    ");

      if(slave != null)
      	if ("true".equals(slave.get("isReplicating"))) {
    
      out.write("\n");
      out.write("    <script type=\"text/javascript\">\n");
      out.write("      document[\"replicate\"].replicateButton.disabled = true;\n");
      out.write("      document[\"replicate\"].replicateButton.className = 'stdbuttondis';\n");
      out.write("    </script>\n");
      out.write("    <form name=abort method=\"POST\" action=\"./index.jsp\" accept-charset=\"UTF-8\">\n");
      out.write("      <input name=\"abort\" type=\"hidden\" value=\"stop\">\n");
      out.write("      <input name=\"abortButton\" class=\"stdbutton\" type=\"submit\" value=\"Abort\">\n");
      out.write("    </form>\n");
      out.write("\n");
      out.write("    ");
} else {
      out.write("\n");
      out.write("    <script type=\"text/javascript\">\n");
      out.write("      document[\"replicate\"].replicateButton.disabled = false;\n");
      out.write("      document[\"replicate\"].replicateButton.className = 'stdbutton';\n");
      out.write("    </script>\n");
      out.write("    ");

      }
      String replicateParam = request.getParameter("replicate");
      String abortParam = request.getParameter("abort");
      if (replicateParam != null)
        if (replicateParam.equals("now")) {
          executeCommand("fetchindex", solrcore, rh);
        }
      if (abortParam != null)
        if (abortParam.equals("stop")) {
          executeCommand("abortfetch", solrcore, rh);
        }
    
      out.write("\n");
      out.write("  </td>\n");
      out.write("\n");
      out.write("</tr>\n");
      out.write("\n");
}
      out.write('\n');
      out.write('\n');
      out.write('\n');
 org.apache.solr.core.CoreContainer cores = (org.apache.solr.core.CoreContainer) request.getAttribute("org.apache.solr.CoreContainer");
  if (cores != null) {
    Collection<String> names = cores.getCoreNames();
    if (names.size() > 1) {
      out.write("\n");
      out.write("<tr>\n");
      out.write("  <td><strong>Cores:</strong><br></td>\n");
      out.write("  <td>");

    for (String name : names) {
  
      out.write("[<a href=\"../../../");
      out.print(name);
      out.write("/admin/index.jsp\">");
      out.print(name);
      out.write("\n");
      out.write("  </a>]");

    }
      out.write("</td>\n");
      out.write("</tr>\n");

    }
  }
      out.write("\n");
      out.write("\n");
      out.write("\n");
      out.write("</table>\n");
      out.write("<P>\n");
      out.write("\n");
      out.write("<p>\n");
      out.write("\n");
      out.write("<table>\n");
      out.write("  <tr>\n");
      out.write("    <td>\n");
      out.write("    </td>\n");
      out.write("    <td>\n");
      out.write("      Current Time: ");
      out.print( new Date() );
      out.write("\n");
      out.write("    </td>\n");
      out.write("  </tr>\n");
      out.write("  <tr>\n");
      out.write("    <td>\n");
      out.write("    </td>\n");
      out.write("    <td>\n");
      out.write("      Server Start At: ");
      out.print( new Date(core.getStartTime()) );
      out.write("\n");
      out.write("    </td>\n");
      out.write("  </tr>\n");
      out.write("</table>\n");
      out.write("\n");
      out.write("<br>\n");
      out.write("<a href=\"..\">Return to Admin Page</a>\n");
      out.write("</body>\n");
      out.write("</html>\n");
    } catch (Throwable t) {
      if (!(t instanceof SkipPageException)){
        out = _jspx_out;
        if (out != null && out.getBufferSize() != 0)
          out.clearBuffer();
        if (_jspx_page_context != null) _jspx_page_context.handlePageException(t);
      }
    } finally {
      _jspxFactory.releasePageContext(_jspx_page_context);
    }
  }
}
