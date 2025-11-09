%dw 2.0
output application/java
import * from dw::core::Objects

// Helper: Normalize Boomi dataType to XSD type
fun normalizeXSDType(dataType: String): String =
    dataType match {
        case "character" -> "string"
        case "boolean" -> "boolean"
        case "number" -> "decimal"
        case "integer" -> "integer"
        case "date" -> "date"
        case "datetime" -> "dateTime"
        else -> "string"
    }

// Helper: Normalize Boomi dataType to JSON Schema type
fun normalizeJSONSchemaType(dataType: String): String =
    dataType match {
        case "character" -> "string"
        case "boolean" -> "boolean"
        case "number" -> "number"
        case "integer" -> "integer"
        case "date" -> "string"
        case "datetime" -> "string"
        else -> "string"
    }

// Helper: Extract XML profile from Boomi Component structure
fun extractXMLProfile(xmlDoc: Any): Any =
    if (xmlDoc.Component? and xmlDoc.Component.object? and xmlDoc.Component.object.XMLProfile?) 
        xmlDoc.Component.object.XMLProfile
    else
        null

// Helper: Extract JSON profile from Boomi Component structure
fun extractJSONProfile(xmlDoc: Any): Any =
    if (xmlDoc.Component? and xmlDoc.Component.object? and xmlDoc.Component.object.JSONProfile?) 
        xmlDoc.Component.object.JSONProfile
    else
        null

// Recursive function to process XML elements and generate XSD
fun processXMLElement(element: Any, indent: String) = do {
    var elementName = element.@name as String default "Unknown"
    var dataType = normalizeXSDType(element.@dataType as String default "character")
    var minOccurs = element.@minOccurs as String default "0"
    var maxOccurs = element.@maxOccurs as String default "1"
    var childElements = element.*XMLElement default []
    var attributes = element.*XMLAttribute default []
    
    var hasComplexContent = !isEmpty(childElements)
    
    ---
    if (hasComplexContent) 
        indent ++ "<xs:element name=\"$(elementName)\" minOccurs=\"$(minOccurs)\" maxOccurs=\"$(maxOccurs)\">\n" ++
        indent ++ "  <xs:complexType>\n" ++
        indent ++ "    <xs:sequence>\n" ++
        ((childElements map (child) -> processXMLElement(child, indent ++ "      ")) joinBy "") ++
        indent ++ "    </xs:sequence>\n" ++
        ((attributes map (attr) -> 
            indent ++ "    <xs:attribute name=\"$(attr.@name as String)\" type=\"xs:$(normalizeXSDType(attr.@dataType as String default "character"))\"" ++
            (if ((attr.@required as String default "false") == "true") " use=\"required\"" else "") ++ "/>\n"
        ) joinBy "") ++
        indent ++ "  </xs:complexType>\n" ++
        indent ++ "</xs:element>\n"
    else
        indent ++ "<xs:element name=\"$(elementName)\" type=\"xs:$(dataType)\" minOccurs=\"$(minOccurs)\" maxOccurs=\"$(maxOccurs)\"" ++
        (if (!isEmpty(attributes)) 
            ">\n" ++
            indent ++ "  <xs:complexType>\n" ++
            indent ++ "    <xs:simpleContent>\n" ++
            indent ++ "      <xs:extension base=\"xs:$(dataType)\">\n" ++
            ((attributes map (attr) -> 
                indent ++ "        <xs:attribute name=\"$(attr.@name as String)\" type=\"xs:$(normalizeXSDType(attr.@dataType as String default "character"))\"" ++
                (if ((attr.@required as String default "false") == "true") " use=\"required\"" else "") ++ "/>\n"
            ) joinBy "") ++
            indent ++ "      </xs:extension>\n" ++
            indent ++ "    </xs:simpleContent>\n" ++
            indent ++ "  </xs:complexType>\n" ++
            indent ++ "</xs:element>\n"
        else
            "/>\n"
        )
}

// Function: Convert Boomi XML Profile to XSD
fun convertXMLProfileToXSD(profile: Any) = do {
    var rootElement = profile.DataElements.*XMLElement[0]
    var rootName = rootElement.@name as String default "Root"
    var targetNamespace = "http://example.com/schema"
    ---
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++
    "<xs:schema xmlns:xs=\"http://www.w3.org/2001/XMLSchema\"\n" ++
    "           targetNamespace=\"$(targetNamespace)\"\n" ++
    "           xmlns:tns=\"$(targetNamespace)\"\n" ++
    "           elementFormDefault=\"qualified\">\n\n" ++
    processXMLElement(rootElement, "  ") ++
    "</xs:schema>"
}

// Recursive function to process JSON elements and build schema properties
fun processJSONElement(element: Any): Any = do {
    var elementName = element.@name as String default "Unknown"
    var dataType = element.@dataType as String default "character"
    
    var jsonObject = element.JSONObject
    var jsonArray = element.JSONArray
    
    ---
    if (jsonObject != null) do {
        var objectEntries = jsonObject.*JSONObjectEntry default []
        ---
        {
            "type": "object",
            "properties": objectEntries reduce (entry, acc = {}) -> do {
                var entryName = entry.@name as String
                var entryDataType = normalizeJSONSchemaType(entry.@dataType as String default "character")
                var nestedArray = entry.JSONArray
                var nestedObject = entry.JSONObject
                ---
                acc ++ {
                    (entryName): 
                        if (nestedArray != null) 
                            processJSONElement(entry)
                        else if (nestedObject != null)
                            processJSONElement(entry)
                        else
                            { "type": entryDataType }
                }
            }
        }
    }
    else if (jsonArray != null) do {
        var arrayElement = jsonArray.JSONArrayElement
        ---
        {
            "type": "array",
            "items": if (arrayElement != null) processJSONElement(arrayElement) else { "type": "object" }
        }
    }
    else
        { "type": normalizeJSONSchemaType(dataType) }
}

// Function: Convert Boomi JSON Profile to JSON Schema
fun convertJSONProfileToJSONSchema(profile: Any) = do {
    var rootValue = profile.DataElements.JSONRootValue
    var rootArray = rootValue.JSONArray
    var schemaTitle = "GeneratedSchema"
    
    ---
    if (rootArray != null) do {
        var arrayElement = rootArray.JSONArrayElement
        var schemaObj = {
            "\$schema": "http://json-schema.org/draft-07/schema#",
            "title": schemaTitle,
            "type": "array",
            "items": if (arrayElement != null) processJSONElement(arrayElement) else { "type": "object" }
        }
        ---
        write(schemaObj, "application/json")
    }
    else do {
        var schemaObj = {
            "\$schema": "http://json-schema.org/draft-07/schema#",
            "title": schemaTitle,
            "type": "object"
        }
        ---
        write(schemaObj, "application/json")
    }
}

// Main: Parse XML content and convert to output format
fun convertProfile(xmlContent: String, outputFormat: String) = do {
    var xmlDoc = read(xmlContent, "application/xml")
    var xmlProfile = extractXMLProfile(xmlDoc)
    var jsonProfile = extractJSONProfile(xmlDoc)
    ---
    if (xmlProfile != null and outputFormat == "xsd") 
        convertXMLProfileToXSD(xmlProfile)
    else if (jsonProfile != null and outputFormat == "jsonschema") 
        convertJSONProfileToJSONSchema(jsonProfile)
    else if (xmlProfile == null and jsonProfile == null)
        "No valid Boomi profile found in document."
    else 
        "Unsupported output format or profile type mismatch. Use 'xsd' for XML profiles or 'jsonschema' for JSON profiles."
}

---
// Example usage:
// convertProfile(payload, "xsd")
// convertProfile(payload, "jsonschema")