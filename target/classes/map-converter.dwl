%dw 2.0
output text/plain

ns bns http://api.platform.boomi.com/

var config = payload // <-- your Boomi XML config
var xml = config.Component.bns#object.Map
var mappings = xml.Mappings.*Mapping
var functions = xml.Functions.*FunctionStep

fun fieldName(path) = (path splitBy "/")[-1]  // take last part e.g. "Root/Object/email" -> "email"

fun functionExpr(func, inputField) =
    if (func.@"type" == "StringSplit") 
        (inputField ++ " splitBy \"" ++ func.Configuration.StringSplit.@delimiter ++ "\"")
    else
        inputField  // extend later with more function support

---
"%dw 2.0\noutput application/json\n---\n{\n" ++
((
    mappings 
    filter ((m, i) -> m.@toType != "function")
    map (m, idx) -> 
        if (m.@fromType == "profile" and m.@toType == "profile") 
            // direct mapping: payload.source -> target
            "  " ++ fieldName(m.@toNamePath) ++ ": payload." ++ fieldName(m.@fromNamePath)
        
        else if (m.@toType == "function") 
            // source → function input
            ""
        
        else if (m.@fromType == "function" and m.@toType == "profile") do {
            var func = (functions filter ((f) -> f.@key == m.@fromFunction))[0]
            var inputMap = (mappings filter ((x) -> x.@toFunction == m.@fromFunction))[0]
            var inputField = "payload." ++ fieldName(inputMap.@fromNamePath)
            var expr = functionExpr(func, inputField)
            ---
            "  " ++ fieldName(m.@toNamePath) ++ ": (" ++ expr ++ ")[" ++ ((m.@fromKey) as Number - 3) as String ++ "]"
        }
        else ""

) joinBy ",\n")
++ "\n}"

