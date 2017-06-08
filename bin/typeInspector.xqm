(:
 : -------------------------------------------------------------------------
 :
 : typeInspector.xqm - functions providing information about type definitions
 :
 : - getTypeDerivationKind
 : - getTypeVariant
 : - getTypeHasSimpleContent
 : - getTypeIsEmpty
 : - getTypeIsBuiltin
 : 
 : -------------------------------------------------------------------------
 :)

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at    
    "componentFinder.xqm",
    "targetNamespaceTools.xqm",
    "utilities.xqm";    

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_errorAssistent.xqm";    

declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace z="http://www.xsdplus.org/ns/structure";

(:~
 : Returns true if a type name identifies a built-in type. 
 : Built-in types are identified by their namespace URI.
 : 
 : @param name the type name
 : @return true if the name identifies a built-in type
 :)
declare function f:isTypeBuiltin($name as xs:QName) {
   namespace-uri-from-QName($name) eq $tt:URI_XSD
};

(:~
 : Returns the derivation kind of a type. The type is identified by name.
 : 
 : If the type is not derived, the empty sequence is returned.
 : If the type is derived, the derivation kind is identified by 
 : a string which is one of these: 'extension', 'restriction'.
 : 
 : @param name the name of the type definition
 : @param schemas the schema elements currently considered
 : @return 'extension', 'restriction' or the empty sequence
 :)
declare function f:getTypeDerivationKind($name as xs:QName, 
                                         $schemas as element(xs:schema)+) {
   let $type := f:findType($name, $schemas)
   return $type/f:tgetTypeDerivationKind(.)
};

(:~
 : Returns the derivation kind of a type. The type is supplied as type 
 : definition element.
 :
 : If the type is not derived, the empty sequence is returned.
 : If the type is derived, the derivation kind is identified by 
 : a string which is one of these: 'extension', 'restriction'.
 : 
 : @param type the type declaration
 : @return 'extension', 'restriction' or the empty sequence
 :)
declare function f:tgetTypeDerivationKind($type as element()?) {
   if (empty($type)) then ()
   else if ($type/*/xs:extension) then "extension"
   else if ($type/xs:restriction, $type/*/xs:restriction) then "restriction"
   else ()
};

(:~
 : Returns the variant of a type definition, expressed by a two-letter code. 
 : The variant identifies simple vs. complex type, plus the derivation kind in 
 : case of a simple type and simple/complex/empty content in case of a complex type. 
 : The codes are:
 :    sr - simple type, restriction
 :    sl - simple type, list
 :    su - simple type, union
 :    cs - complex type, simple content
 :    cc - complex type, complex content
 :    ce - complex type, empty content
 : 
 : @param type the type definition
 : @param schemas the schema documents currently considered
 : @return a two-letter code identifying the type variant
 :)
declare function f:getTypeVariant($name as xs:QName, 
                                  $schemas as element(xs:schema)+) 
        as xs:string {
    if (f:isTypeBuiltin($name)) then 'sb' else
   
    let $type := f:findType($name, $schemas)
    return
        if (empty($type)) then () else f:tgetTypeVariant($type, $schemas)
};

(:~
 : Returns the variant of a type definition, expressed by a two-letter code. 
 : The variant identifies simple vs. complex type, plus the derivation kind in 
 : case of a simple type and simple/complex/empty content in case of a complex type. 
 : The codes are:
 :    sr - simple type, restriction
 :    sl - simple type, list
 :    su - simple type, union
 :    cs - complex type, simple content
 :    cc - complex type, complex content
 :    ce - complex type, empty content
 : 
 : @param type the type definition
 : @param schemas the schema documents currently considered
 : @return a two-letter code identifying the type variant
 :)
declare function f:tgetTypeVariant($type as element()?, 
                                   $schemas as element(xs:schema)+)
        as xs:string? {
    if (not($type)) then () else
    
    if ($type/self::xs:simpleType) then
        if ($type/xs:restriction) then 'sr'
        else if ($type/xs:list) then 'sl'
        else if ($type/xs:union) then 'su'
        else error()
    else
        if (f:tgetTypeHasSimpleContent($type, $schemas)) then 'cs'
        else if (f:tgetTypeIsEmpty($type, $schemas)) then 'ce'
        else 'cc'
};

(:~
 : Returns true if a given type definition has empty content. 
 : Simple types are considered non-empty, regardless of any type details. 
 : A complex type is considered empty if it cannot have child elements.
 : 
 : @param name the name of the type definition
 : @schemas the schema elements
 : @return true if the type definition has a variety 'empty', false otherwise
 :)
declare function f:getTypeIsEmpty($name as xs:QName, 
                                  $schemas as element(xs:schema)+) {
   let $type := f:findType($name, $schemas)
   return
      if (empty($type)) then ()
      else f:tgetTypeIsEmpty($type, $schemas)
};

(:~
 : Returns true if a given type definition has empty content. 
 : Simple types are considered non-empty, regardless of any type details. 
 : etc. A complex type is considered empty if it cannot have child elements.
 : 
 : @param type the type definition
 : @schemas the schema elements currently considered
 : @return true if the type definition has a variety 'empty', false otherwise
 :)
declare function f:tgetTypeIsEmpty($type as element()?, 
                                   $schemas as element(xs:schema)+)
      as xs:boolean? {
    if (empty($type)) then  ()
    else if (f:tgetTypeHasSimpleContent($type, $schemas)) then false()
    else if (not($type/self::xs:complexType)) then ()   (: invalid 'type' parameter :)    
(:    
    else if ($type/self::xs:simpleType) then false()
    else if ($type/xs:simpleContent) then false()
:)    
    else
       let $elems := f:tfindTypeElems($type, true(), $schemas)
       return
          not($elems)
};

(:~
 : Returns true if a given type definition is simple or complex with simple content. 
 : 
 : @param name the name of the type definition
 : @schemas the schema elements
 : @return true if the type definition has a variety 'empty', false otherwise
 :)
declare function f:getTypeHasSimpleContent($name as xs:QName, 
                                           $schemas as element(xs:schema)+) {
   let $type := f:findType($name, $schemas)
   return
      if (empty($type)) then ()
      else f:tgetTypeHasSimpleContent($type, $schemas)
};

(:~
 : Returns true if a given type definition is simple or complex with simple content.
 : The type is supplied as type definition element. 
 : 
 : @param name the name of the type definition
 : @schemas the schema elements
 : @return true if the type definition has a variety 'empty', false otherwise
 :)
declare function f:tgetTypeHasSimpleContent($type as element()?, 
                                            $schemas as element(xs:schema)+) {
    if ($type/xs:simpleType) then true()
    else if ($type/xs:simpleContent) then true()
    else 
        boolean(f:tfindTypeBaseTypes($type, $schemas)/xs:simpleContent)
};

