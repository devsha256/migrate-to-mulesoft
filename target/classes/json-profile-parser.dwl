%dw 2.0
output application/json

fun processRootValue(rootValue) = 
  if (!isEmpty(rootValue.JSONArray))
    processArray(rootValue.JSONArray)
  else if (!isEmpty(rootValue.JSONObject))
    processObject(rootValue.JSONObject)
  else
    getSampleValue(rootValue.@dataType)

fun processArray(arrayNode) = 
  if (!isEmpty(arrayNode.JSONArrayElement))
    [processArrayElement(arrayNode.JSONArrayElement)]
  else
    []

fun processArrayElement(arrayElement) = 
  if (!isEmpty(arrayElement.JSONObject))
    processObject(arrayElement.JSONObject)
  else if (!isEmpty(arrayElement.JSONArray))
    processArray(arrayElement.JSONArray)
  else
    getSampleValue(arrayElement.@dataType)

fun processObject(objectNode) = 
  if (!isEmpty(objectNode.JSONObjectEntry))
    (objectNode.*JSONObjectEntry map (entry) -> {
      (entry.@name): 
        if (!isEmpty(entry.JSONArray))
          processArray(entry.JSONArray)
        else if (!isEmpty(entry.JSONObject))
          processObject(entry.JSONObject)
        else
          getSampleValue(entry.@dataType)
    }) reduce ((item, acc = {}) -> acc ++ item)
  else
    {}

fun getSampleValue(dataType) = 
  dataType match {
    case "character" -> ""
    case "number" -> 0
    case "boolean" -> true
    case "date" -> ""
    case "datetime" -> ""
    else -> ""
  }

---
processRootValue(payload.Component.object.JSONProfile.DataElements.JSONRootValue)
