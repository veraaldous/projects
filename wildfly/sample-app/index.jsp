<%@ page contentType="text/html; charset=UTF-8" %>
<%
java.util.logging.Logger.getLogger("lab.wildfly").info("LAB_REQUEST: /hello/");
%>
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Aldous WildFly Lab</title></head>
<body>
<h1>Aldous WildFly Lab</h1>
<p>Java version: <%= System.getProperty("java.version") %></p>
<p>Maximum heap: <%= Runtime.getRuntime().maxMemory() / (1024 * 1024) %> MiB</p>
<p>Server time: <%= java.time.Instant.now() %></p>
</body>
</html>
