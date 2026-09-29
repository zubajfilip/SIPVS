package sk.stuba.sipvs;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.xml.sax.ErrorHandler;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Saves the form as XML, validates it against the XSD and transforms it with the XSL.
 * Element names come from the XSD (palubnyListok.xsd), so they stay in Slovak.
 */
public class XmlService {

    public static final String NAMESPACE = "http://www.stuba.sk/sipvs/palubny-listok";

    public record ValidationError(String severity, int line, int column, String message) {}

    private final Path schemaFile;
    private final Path stylesheetFile;
    private final Path xmlFile;
    private final Path htmlFile;

    public XmlService(Path schemaFile, Path stylesheetFile, Path xmlFile, Path htmlFile) {
        this.schemaFile = schemaFile;
        this.stylesheetFile = stylesheetFile;
        this.xmlFile = xmlFile;
        this.htmlFile = htmlFile;
    }

    public Path getXmlFile() { return xmlFile; }
    public Path getHtmlFile() { return htmlFile; }

    // ===================== Save XML =====================

    /**
     * Builds the XML document from the form values and writes it to a file.
     * Values are deliberately not checked here – that is what the "validate against XSD" button is for.
     * Form keys are the XML element names, e.g. "odlet.letisko" or "p.0.meno" for the first passenger.
     */
    public void save(Map<String, String> form) throws Exception {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        Document doc = dbf.newDocumentBuilder().newDocument();

        Element root = doc.createElementNS(NAMESPACE, "palubneListky");
        root.setAttribute("rezervacia", value(form, "rezervacia"));
        doc.appendChild(root);

        Element flight = append(root, "let", null);
        append(flight, "cisloLetu", value(form, "cisloLetu"));
        append(flight, "dopravca", value(form, "dopravca"));
        appendPlace(flight, "odlet", form);
        appendPlace(flight, "prilet", form);
        append(flight, "dlzkaLetu", value(form, "dlzkaLetu"));
        append(flight, "gate", value(form, "gate"));
        append(flight, "nastup", value(form, "nastup"));

        Element passengers = append(root, "pasazieri", null);
        for (int i = 0; form.containsKey("p." + i + ".meno"); i++) {
            String prefix = "p." + i + ".";
            Element passenger = append(passengers, "pasazier", null);
            passenger.setAttribute("trieda", value(form, prefix + "trieda"));
            append(passenger, "titul", value(form, prefix + "titul"));
            append(passenger, "meno", value(form, prefix + "meno"));
            append(passenger, "priezvisko", value(form, prefix + "priezvisko"));
            append(passenger, "datumNarodenia", value(form, prefix + "datumNarodenia"));
            append(passenger, "sedadlo", value(form, prefix + "sedadlo"));
            append(passenger, "batozinaKg", value(form, prefix + "batozinaKg"));
            append(passenger, "prednostnyNastup", value(form, prefix + "prednostnyNastup"));
        }

        Transformer serializer = TransformerFactory.newInstance().newTransformer();
        serializer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "yes");
        serializer.setOutputProperty(OutputKeys.INDENT, "yes");
        serializer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
        serializer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "4");

        Files.createDirectories(xmlFile.getParent());
        try (Writer writer = Files.newBufferedWriter(xmlFile, StandardCharsets.UTF_8)) {
            // the header is written by hand – the JDK serializer would put it on the same line as the root element
            writer.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
            writer.write("<?xml-stylesheet type=\"text/xsl\" href=\"../palubnyListok.xsl\"?>\n");
            serializer.transform(new DOMSource(doc), new StreamResult(writer));
        }
    }

    private void appendPlace(Element flight, String name, Map<String, String> form) {
        Element place = append(flight, name, null);
        append(place, "letisko", value(form, name + ".letisko"));
        append(place, "mesto", value(form, name + ".mesto"));
        append(place, "cas", value(form, name + ".cas"));
        String terminal = value(form, name + ".terminal");
        if (!terminal.isEmpty()) {
            append(place, "terminal", terminal);
        }
    }

    private static Element append(Element parent, String name, String text) {
        Element element = parent.getOwnerDocument().createElementNS(NAMESPACE, name);
        if (text != null) {
            element.setTextContent(text);
        }
        parent.appendChild(element);
        return element;
    }

    private static String value(Map<String, String> form, String key) {
        return form.getOrDefault(key, "").trim();
    }

    // ===================== Validate XML against XSD =====================

    /** Validates the saved XML against the XSD and returns every error found (empty list = valid). */
    public List<ValidationError> validate() throws Exception {
        requireSavedXml();

        SchemaFactory schemaFactory = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
        Validator validator = schemaFactory.newSchema(schemaFile.toFile()).newValidator();
        validator.setProperty(XMLConstants.ACCESS_EXTERNAL_DTD, "");

        List<ValidationError> errors = new ArrayList<>();
        validator.setErrorHandler(new ErrorHandler() {
            @Override public void warning(SAXParseException e) { errors.add(toError("warning", e)); }
            @Override public void error(SAXParseException e) { errors.add(toError("error", e)); }
            @Override public void fatalError(SAXParseException e) throws SAXException {
                errors.add(toError("fatal", e));
                throw e;
            }
        });

        try {
            validator.validate(new StreamSource(xmlFile.toFile()));
        } catch (SAXParseException e) {
            // already recorded in fatalError – the XML is not even well-formed, validation cannot continue
        }
        return errors;
    }

    private static ValidationError toError(String severity, SAXParseException e) {
        return new ValidationError(severity, e.getLineNumber(), e.getColumnNumber(), e.getMessage());
    }

    // ===================== Transform XML to HTML =====================

    /** Transforms the saved XML with the XSL and writes the result to the HTML file. */
    public void transform() throws Exception {
        requireSavedXml();

        Transformer transformer = TransformerFactory.newInstance().newTransformer(new StreamSource(stylesheetFile.toFile()));
        Files.createDirectories(htmlFile.getParent());
        transformer.transform(new StreamSource(xmlFile.toFile()), new StreamResult(htmlFile.toFile()));
    }

    public String readXml() throws Exception {
        return Files.readString(xmlFile, StandardCharsets.UTF_8);
    }

    private void requireSavedXml() {
        if (!Files.exists(xmlFile)) {
            // shown to the user on the page
            throw new IllegalStateException("XML ešte nebolo uložené – najprv použite tlačidlo „Ulož XML“.");
        }
    }
}
