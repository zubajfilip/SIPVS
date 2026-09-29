package sk.stuba.sipvs;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.BindException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Simple web application for filling in a boarding pass.
 * Must be started from the project root (where palubnyListok.xsd is), by default on http://localhost:8080
 */
public class App {

    private static final Path ROOT = Path.of("").toAbsolutePath();
    private static final Path WEB_DIR = ROOT.resolve("web");
    private static final Path OUTPUT_DIR = ROOT.resolve("output");

    private static final XmlService XML = new XmlService(
            ROOT.resolve("palubnyListok.xsd"),
            ROOT.resolve("palubnyListok.xsl"),
            OUTPUT_DIR.resolve("palubnyListok.xml"),
            OUTPUT_DIR.resolve("palubnyListok.html"));

    @FunctionalInterface
    interface ApiAction {
        Map<String, Object> execute(Map<String, String> form) throws Exception;
    }

    public static void main(String[] args) throws IOException {
        if (!Files.exists(ROOT.resolve("palubnyListok.xsd"))) {
            System.err.println("Aplikáciu spustite z koreňa projektu (nenašiel sa palubnyListok.xsd v " + ROOT + ").");
            System.exit(1);
        }
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8080;

        HttpServer server;
        try {
            server = HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(), port), 0);
        } catch (BindException e) {
            System.err.println("Port " + port + " je obsadený – aplikácia už pravdepodobne beží (http://localhost:" + port + ").");
            System.err.println("Zastavte ju, alebo spustite na inom porte: java -cp out sk.stuba.sipvs.App 9090");
            System.exit(1);
            return;
        }

        server.createContext("/", App::serveStatic);

        server.createContext("/api/save", api(form -> {
            XML.save(form);
            return Map.of("file", relativePath(XML.getXmlFile()), "xml", XML.readXml());
        }));

        server.createContext("/api/validate", api(form -> {
            List<XmlService.ValidationError> errors = XML.validate();
            return Map.of(
                    "valid", errors.isEmpty(),
                    "errors", errors.stream().map(e -> Map.<String, Object>of(
                            "severity", e.severity(), "line", e.line(),
                            "column", e.column(), "message", e.message())).toList(),
                    "xml", XML.readXml());
        }));

        server.createContext("/api/transform", api(form -> {
            XML.transform();
            return Map.of("file", relativePath(XML.getHtmlFile()), "url", "/output/palubnyListok.html");
        }));

        server.start();
        System.out.println("Palubný lístok beží na http://localhost:" + port);
    }

    // ===================== API =====================

    private static HttpHandler api(ApiAction action) {
        return exchange -> {
            if (!"POST".equals(exchange.getRequestMethod())) {
                send(exchange, 405, "text/plain; charset=utf-8", "Use POST");
                return;
            }
            try {
                String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
                Map<String, Object> result = new LinkedHashMap<>(action.execute(parseForm(body)));
                result.put("ok", true);
                send(exchange, 200, "application/json; charset=utf-8", Json.write(result));
            } catch (Exception e) {
                e.printStackTrace();
                String message = e.getMessage() != null ? e.getMessage() : e.toString();
                send(exchange, 200, "application/json; charset=utf-8",
                        Json.write(Map.of("ok", false, "error", message)));
            }
        };
    }

    private static Map<String, String> parseForm(String body) {
        Map<String, String> form = new LinkedHashMap<>();
        if (body.isEmpty()) {
            return form;
        }
        for (String pair : body.split("&")) {
            String[] kv = pair.split("=", 2);
            form.put(URLDecoder.decode(kv[0], StandardCharsets.UTF_8),
                    kv.length > 1 ? URLDecoder.decode(kv[1], StandardCharsets.UTF_8) : "");
        }
        return form;
    }

    // ===================== Static files =====================

    private static void serveStatic(HttpExchange exchange) throws IOException {
        String path = exchange.getRequestURI().getPath();
        Path baseDir = WEB_DIR;
        if (path.equals("/")) {
            path = "/index.html";
        } else if (path.startsWith("/output/")) {
            baseDir = OUTPUT_DIR;
            path = path.substring("/output".length());
        }

        Path file = baseDir.resolve(path.substring(1)).normalize();
        if (!file.startsWith(baseDir) || !Files.isRegularFile(file)) {
            send(exchange, 404, "text/plain; charset=utf-8", "Not found: " + path);
            return;
        }
        exchange.getResponseHeaders().set("Cache-Control", "no-store");
        send(exchange, 200, contentType(file), Files.readAllBytes(file));
    }

    private static String contentType(Path file) {
        String name = file.getFileName().toString();
        if (name.endsWith(".html")) return "text/html; charset=utf-8";
        if (name.endsWith(".css")) return "text/css; charset=utf-8";
        if (name.endsWith(".js")) return "text/javascript; charset=utf-8";
        if (name.endsWith(".xml")) return "application/xml; charset=utf-8";
        return "application/octet-stream";
    }

    private static void send(HttpExchange exchange, int status, String type, String body) throws IOException {
        send(exchange, status, type, body.getBytes(StandardCharsets.UTF_8));
    }

    private static void send(HttpExchange exchange, int status, String type, byte[] body) throws IOException {
        exchange.getResponseHeaders().set("Content-Type", type);
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(body);
        }
    }

    private static String relativePath(Path p) {
        return ROOT.relativize(p).toString().replace('\\', '/');
    }
}
