%dw 2.0
output application/json

fun parseElement(element) = do {
  var children = element.*XMLElement default []
  ---
  if (!isEmpty(children))
    buildChildren(children)
  else
    getSampleValue(element.@dataType default "character")
}

fun buildChildren(children) = do {
  var grouped = children groupBy ((item) -> item.@name)
  ---
  grouped mapObject (elements, elementName) -> 
    if (sizeOf(elements) > 1)
      (elementName): [parseElement(elements[0])]
    else
      (elementName): parseElement(elements[0])
}

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
do {
  var profile = payload.Component.object.XMLProfile
  var dataElements = profile.DataElements
  var elements = dataElements.*XMLElement
  var rootElement = elements[0]
  var rootName = rootElement.@name as String
  ---
  {
    (rootName): parseElement(rootElement)
  }
}
