(:
 : -------------------------------------------------------------------------
 :
 : componentNavigator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at    
    "componentFinder.xqm",
    "targetNamespaceTools.xqm",
    "typeInspector.xqm",
    "utilities.xqm";    

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_errorAssistent.xqm";    

declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace z="http://www.xsdplus.org/ns/structure";

(:
 : =======================================
 : r f i n d . . . 
 : =======================================
 : Functions resolving a component reference provided by
 : an attribute.
 :
 : - rfindComp
 : - rfindElem
 : - rfindAtt
 : - rfindGroup
 : - rfindAttGroup
 : - rfindType
 : - rfindTypeOrTypeName
 :)

(:~
 : Finds a component. The component is identified by an attribute 
 : containing its QName.
 :
 : @param ref - an attribute referencing the element
 : @param schemas - the schema elements currently considered
 : @return the element declaration
 :)
declare function f:rfindComp($ref as attribute()?, $schemas as element(xs:schema)+)
      as element()? {
    let $parent := $ref/.. return

    if (empty($parent)) then () 
    else if ($parent/self::xs:element) then f:rfindElem($ref, $schemas)
    else if ($parent/self::xs:attribute) then f:rfindAtt($ref, $schemas)
    else if ($parent/self::xs:group) then f:rfindGroup($ref, $schemas)
    else if ($parent/self::xs:attributeGroup) then f:rfindAttGroup($ref, $schemas)
    else tt:createError('INVALID_CALL', concat('rfindComp must be called ',
        'with a @ref attribute owned by one of these: xs:element, xs:attribute, xs:group, xs:attributeGroup; ',
        'found owner name: ', local-name($parent)), ())
};

(:~
 : Finds an element declaration. The element is identified
 : by an attribute containing its QName.
 :
 : @param ref - an attribute referencing the element
 : @param schemas - the schema elements currently considered
 : @return the element declaration
 :)
declare function f:rfindElem($ref as attribute()?, $schemas as element(xs:schema)+)
      as element()? {
   if (empty($ref/..)) then () else

   let $compName as xs:QName := resolve-QName($ref, $ref/..)
   return
      f:findElem($compName, $schemas)
};

(:~
 : Finds an attribute declaration. The attribute is identified
 : by an attribute containing its QName.
 :
 : @param ref - an attribute referencing the attribute
 : @param schemas - the schema elements currently considered
 : @return the attribute declaration
 :)
declare function f:rfindAtt($ref as attribute()?, $schemas as element(xs:schema)+)
      as element()? {
   if (empty($ref/..)) then () else

   let $compName as xs:QName := resolve-QName($ref, $ref/..)
   return
      f:findAtt($compName, $schemas)
};

(:~
 : Finds a group definition. The group is identified by an
 : attribute containing its QName.
 :
 : @param referenceAtt - an attribute referencing the group definition
 : @param the schema elements current considered
 : @return the group definition 
 :)
declare function f:rfindGroup($ref as attribute()?, $schemas as element(xs:schema)+)
        as element()? {
    if (empty($ref/..)) then () else

    let $compName as xs:QName := resolve-QName($ref, $ref/..)
    return
        f:findGroup($compName, $schemas)
};

(:~
 : Finds an attribute group definition. The attribute group is identified
 : by an attribute containing its QName.
 :
 : @param referenceAtt - an attribute referencing the attribte group definition
 : @param the schema elements of the current schema
 : @return the attribute group definition 
 :)
declare function f:rfindAttGroup($ref as attribute()?, $schemas as element(xs:schema)+)
        as element()? {
    if (empty($ref/..)) then () else

    let $compName as xs:QName := resolve-QName($ref, $ref/..)
    let $comp := f:findAttGroup($compName, $schemas)
    return
        if (count($comp) gt 1) then app:resolveDuplicateComponents($comp)
        else $comp
};

(:~
 : Finds a type definition. The type is identified by an
 : attribute containing its QName. If the type is builtin (that is,
 : its URI is the XSD namespace URI), the empty sequence is returned,
 : otherwise the type definition identified by the type name.
 :
 : @param referenceAtt - an attribute referencing the type definition
 : @param the schema elements of the current schema
 : @return the type definition, or the empty sequence in case of a builtin type 
 :)
declare function f:rfindType($referenceAtt as attribute()?, $schemas as element(xs:schema)+)
      as item()? {
   let $typeOrTypeName := f:rfindTypeOrTypeName($referenceAtt, $schemas)
   return
      if ($typeOrTypeName instance of xs:anyAtomicType) then ()
      else $typeOrTypeName
};

(:~
 : Finds a type definition or type name. The type is identified by an
 : attribute containing its QName. If the type is builtin (that is,
 : its URI is the XSD namespace URI), the type name is returned, otherwise
 : the type definition identified by the type name.
 :
 : @param referenceAtt - an attribute referencing the type definition
 : @param the schema elements of the current schema
 : @return the type definition, or the type name in case of a builtin type 
 :)
declare function f:rfindTypeOrTypeName($referenceAtt as attribute()?, $schemas as element(xs:schema)+)
      as item()? {         
   if (empty($referenceAtt/..)) then () else

   let $typeName as xs:QName := resolve-QName($referenceAtt, $referenceAtt/..)
   return
      if (f:isTypeBuiltin($typeName)) then $typeName else f:findType($typeName, $schemas)
};

(:
 : =======================================
 : g e t x x x N a m e . . . 
 : =======================================
 :
 : - getAttName
 : - getElemName
 : - getTypeName
 :)

(:~
 : Returns the name of an attribute declaration.
 :)
declare function f:getAttName($att as element(xs:attribute)?) as xs:QName? {
   if (empty($att)) then () else
   if ($att/@ref) then $att/@ref/resolve-QName(., ..) else

   let $tns := $att/ancestor::xs:schema/@targetNamespace
   let $useLocalName as xs:boolean? := 
      if (empty($tns)) then true()
      else if ($att/parent::xs:schema) then false()
      else
         let $attributeForm := (
            $att/ancestor-or-self::*/@attributeForm[1], 
            $att/ancestor::xs:schema/@attributeFormDefault)[1]
         return not($attributeForm eq 'qualified')
   return
      if (not($useLocalName)) then $att/@name/QName($tns, .)
      else QName('', $att/@name)
};

(:~
 : Returns the name of an element declaration.
 :)
declare function f:getElemName($elem as element(xs:element)?) as xs:QName? {
   if (empty($elem)) then () else
   if ($elem/@ref) then $elem/@ref/resolve-QName(., ..) else

   let $tns := $elem/ancestor::xs:schema/@targetNamespace
   let $useLocalName as xs:boolean? := 
      if (empty($tns)) then true()
      else if ($elem/parent::xs:schema) then false()
      else
         let $elementForm := (
            $elem/@elementForm, 
            $elem/ancestor::xs:schema/@elementFormDefault)[1]
         return not($elementForm eq 'qualified')
   return
      if (not($useLocalName)) then $elem/@name/QName($tns, .)
      else QName('', $elem/@name)
};

(:~
 : Returns the name of a type definition. If the type definition is
 : local, the empty sequence is returned. 
 :
 : @param type the type definition element (xs:simpleType or xs:complexType)
 : @return the qualified type name
 :)
declare function f:getTypeName($type as element()?) as xs:QName? {
   let $typeName := $type/@name
   return
      if (empty($typeName)) then () else
         QName($type/ancestor::xs:schema/@targetNamespace/string(), $typeName)
};

(:
 : =============================================
 : e g e t E l e m ...
 : =============================================
 : - egetElemPaths
 : - egetElemTypeName
 : - egetElemLocalTypeName
 :)
 
(:~
 : Returns the type name of an element declaration. If the
 : element has a local type, the name '_LOCAL_' is returned
 : (in no namespace). If the element declaration has no type,
 : the empty sequence is returned.
 :
 : @param elem the element declaration
 : @schemas the schemas
 : @return the type name
 :)
declare function f:egetElemTypeName($elem as element(xs:element)?, 
                                    $schemas as element(xs:schema)+) 
      as xs:QName? {
   if (empty($elem)) then () else

   let $elemD := if (not($elem/@ref)) then $elem else f:rfindElem($elem/@ref, $schemas)
   let $typeName := $elemD/@type/resolve-QName(., ..)
   return
      if (exists($typeName)) then $typeName 
      else if ($elemD/(xs:simpleType, xs:complexType)) then QName('', '_LOCAL_') 
      else ()
};

(:~
 : Returns the local part of the type name of an element declaration. If the
 : element has a local type, the empty string is returned. If the element 
 : declaration has no type, the empty sequence is returned.
 :
 : @param elem the element declaration
 : @schemas the schemas
 : @return the type name
 :)
declare function f:egetElemLocalTypeName($elem as element(xs:element)?, 
                                        $schemas as element(xs:schema)+) 
      as xs:string? {
   if (empty($elem)) then () else

   let $elemD := if (not($elem/@ref)) then $elem else f:rfindElem($elem/@ref, $schemas)
   let $typeName := $elemD/@type/replace(., '.*:', '')
   return 
      if (exists($typeName)) then $typeName 
      else if ($elemD/(xs:simpleType, xs:complexType)) then '' 
      else ()
};

(:
 : =============================================
 : f i n d T y p e ...
 : =============================================
 :)

(:    f i n d T y p e A t t F o r A t t N a m e    :)

declare function f:findTypeAttForAttName($typeName as xs:QName, 
                                          $attName as xs:QName,  
                                          $alsoInherited as xs:boolean?, 
                                          $schemas as element(xs:schema)+) 
      as element(xs:attribute)* {
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeAttForAttName($type, $attName, $alsoInherited, $schemas)
};

(:    
    f i n d T y p e A t t s    
:)

(:~
 : Finds the attribute declarations contained or referenced by a type definition,
 : including the contents of referenced attribute groups, recursively resolved.
 : The type is identified by its name. Base types are ignored unless "alsoInherited" 
 : is true.
 :
 : Only top level attribute declarations are considered, that is, attribute
 : declarations corresponding to attributes of the type owning element itself.
 :
 : @param typeName the type name
 : @param alsoInherited if true, attributes of base types are also returned
 : @param schemas the schema elements currently considered
 : @return attribute declarations and/or attribute wildcards
 :)
declare function f:findTypeAtts($typeName as xs:QName, 
                                $alsoInherited as xs:boolean?, 
                                $schemas as element(xs:schema)+) 
        as element(xs:attribute)* {
    let $type := f:findType($typeName, $schemas)
    return f:tfindTypeAtts($type, $alsoInherited, $schemas)
};

(:    f i n d T y p e C o n t e n t T y p e O r T y p e N a m e    :)

(:~
 : Returns the content type of a complex type with simple content. If the content
 : type is built-in, the content type name is returned, otherwise the content
 : type definition element.
 :
 : @param typeName the type name
 : @param schemas the schemas considered
 :)
declare function f:findTypeContentTypeOrTypeName($typeName as xs:QName, 
                                                 $schemas as element(xs:schema)+) 
      as element()? {
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeContentTypeOrTypeName($type, $schemas)   
};


(:    f i n d T y p e D e r i v a t i o n S t e p s    :)

(:~
 : Returns for each base type a concatenation of derivation kind flag and
 : normalized type name. The derivation kind flag is 'e' for extension
 : and 'r' for restriction.
 :)
declare function f:findTypeDerivationSteps($typeName as xs:QName, $schemas as element(xs:schema)+) 
        as xs:string* {
    let $type := f:findType($typeName, $schemas)
    return f:tfindTypeDerivationSteps($type, $schemas)   
};

(:    f i n d T y p e C o n t a i n e r E l e m   :)

(:~
 : Finds the content container element of a type definition identified by name. 
 : The content container element is the element which may contain attribute,
 : attributeGroup and anyAtribute elements, as well as - in the case of
 : complex content - a sequence, choice, all or group element.
 :)
declare function f:findTypeContainerElem($name as xs:QName, $schemas as element(xs:schema)+) 
      as element()? {
   let $type := f:findType($name, $schemas)
   return
      if (not($type)) then () else f:tfindTypeContainerElem($type, $schemas)
};

(:    f i n d T y p e S i m p l e C o n e n t   :)

(:~
 : Returns the xs:simpleContent of a type definition identified by name, or of its nearest ancestor
 : type containing such an element. 
 : 
 : @param name the name of the type definition
 : @schemas the schema elements
 : @return true if the type definition has a variety 'empty', false otherwise
 :)
declare function f:findTypeSimpleContent($name as xs:QName, $schemas as element(xs:schema)+) {
   let $type := f:findType($name, $schemas)
   return
      if (not($type)) then () else f:tfindTypeSimpleContent($type, $schemas)
};


(:    f i n d T y p e S u b T y p e s    :)

(:~
 : Returns derived types of a given type definition. The type definition is
 : specified by name. If $alsoIndirect is true, also indirectly derived
 : types are returned, otherwise only direct derivations. If $devKind is
 : 'extension' or 'restriction', only types derived by extension or 
 : restriction, respectively, are returned.
 :)
declare function f:findTypeSubTypes(
                      $typeName as xs:QName,
                      $alsoIndirect as xs:boolean?,
                      $devKind as xs:string?,
                      $schemas as element(xs:schema)+) 
   as element()* {
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeSubTypes($type, $alsoIndirect, $devKind, $schemas)   
};

(:    f i n d T y p e E l e m s    :)

(:~
 : Finds the element declarations contained or referenced by a type definition.
 : The type is identified by its name.
 : Extended base types are ignored unless 
 : "alsoInherited" is true. Any group references are recursively resolved. 
 . Only top level element declarations are considered, that is, element
 : declarations corresponding to immediate children of the type owning
 : element itself.
 :)
declare function f:findTypeElems(
                      $typeName as xs:QName, 
                      $alsoInherited as xs:boolean?, 
                      $schemas as element(xs:schema)+)                      
      as element(xs:element)* {
      
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeElems($type, $alsoInherited, $schemas)
};

(:    f i n d T y p e E l e m s F o r E l e m N a m e    :)

declare function f:findTypeElemsForElemName(
                      $typeName as xs:QName, 
                      $elemName as xs:QName,  
                      $alsoInherited as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element(xs:element)* {
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeElemsForElemName($type, $elemName, $alsoInherited, $schemas)
};

(:    f i n d T y p e D e c l s F o r X P a t h    :)

declare function f:findTypeDeclsForXPath(
                      $typeName as xs:QName, 
                      $xpath as xs:string,  
                      $namespaceContext as element()?,
                      $alsoInherited as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element()* {
      
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeDeclsForXPath($type, $xpath, $namespaceContext, $alsoInherited, $schemas)
};

(:    f i n d T y p e U s i n g A t t s    :)

declare function f:findTypeUsingAtts(
                      $typeName as xs:QName, 
                      $alsoDerived as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element(xs:attribute)* {
      
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeUsingAtts($type, $alsoDerived, $schemas)
};

(:    f i n d T y p e U s i n g E l e m s    :)

declare function f:findTypeUsingElems(
                      $typeName as xs:QName, 
                      $alsoDerived as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element(xs:element)* {
      
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeUsingElems($type, $alsoDerived, $schemas)
};

(:    f i n d T y p e U s i n g I t e m s    :)

declare function f:findTypeUsingItems(
                      $typeName as xs:QName, 
                      $alsoDerived as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element()* {
      
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeUsingItems($type, $alsoDerived, $schemas)
};


(:
 : =============================================
 : f i n d E l e m ...
 : =============================================
 :)

(:    f i n d E l e m T y p e    :)
(:~
 : Finds the type definition of an element. The element is 
 : identified by name. If the type is builtin, 
 : the empty sequence is returned.
 :)
declare function f:findElemType($elemName as xs:QName, 
                                $schemas as element(xs:schema)+) 
      as item()? {
   let $elem := f:findElem($elemName, $schemas)
   return f:efindElemType($elem, $schemas)
};

(:    f i n d E l e m T y p e Or T y p e N a m e    :)
(:~
 : Finds the type definition or name of an element.
 : The element is identified by name. If the type
 : is builtin, the type name is returned, otherwise
 : the type definition.
 :)
declare function f:findElemTypeOrTypeName($elemName as xs:QName, 
                                          $schemas as element(xs:schema)+) 
      as item()? {
   let $elem := f:findElem($elemName, $schemas)
   return f:efindElemTypeOrTypeName($elem, $schemas)
};

(:    f i n d E l e m T y p e s Or T y p e N a m e s   :)
(:~
 : Finds the type definitions and/or names of all element
 : declarations with a given name. For each element 
 : declaration, the type name is returned if the type
 : is builtin, and the type definition if the type
 : is user-defined. The result sequence does not
 : contain duplicate names or type definition nodes.
 :
 : @param elemName the element name
 : @schemas the schemas
 :)
declare function f:findElemTypesOrTypeNames($elemName as xs:QName, 
                                            $schemas as element(xs:schema)+) 
      as item()* {
   let $elems := f:findElems($elemName, $schemas)
   let $items := for $elem in $elems return f:efindElemTypeOrTypeName($elem, $schemas)
   let $names := distinct-values($items[. instance of xs:QName])
   let $defs := $items[. instance of node()]/.
   return ($names, $defs)
};

(:
 : =============================================
 : f i n d A t t ...
 : =============================================
 :)

(:~
 : Finds for all attribute declarations with a given name 
 : the element declarations of possible parent elements.
 :
 : @param name the element name
 : @schemas the schemas elements
 : @return the element declarations of elements that may have a child
 :    element with name equal $name
 :)
declare function f:findAttParents(
                        $name as xs:QName, 
                        $schemas as element(xs:schema)+) 
        as element()* {
        
    let $comps := f:findAtts($name, $schemas)
    return
       f:afindAttParents($comps, $schemas)
};

(:
 : =============================================
 : f i n d G r o u p ...
 : =============================================
 :)

(:~
 : Finds the element declarations directly or indirectly contained 
 : by a group definition. The group definition is identified by
 : name. Group references are recursively resolved.
 :)
declare function f:findGroupElems(
                      $groupName as xs:QName, 
                      $schemas as element(xs:schema)+) as element()* {
                    
   let $group := f:findGroup($groupName, $schemas)
   return f:gfindGroupElems($group, $schemas)
};

(:~
 : Finds the type definitions using a group definition. 
 : The group is identified by name. 
 :
 : @param groupName the group name
 : @param alsoDerived if true, also extensions of types 
 :    using the group are returned
 : @param schemas the schema elements
 : @return the type definitions using the group
 :    definition identified by $groupName
 :) 
declare function f:findGroupUsingTypes(
                        $groupName as xs:QName, 
                        $alsoDerived as xs:boolean?,
                        $schemas as element(xs:schema)+) 
        as element()* {
                      
   let $group := f:findGroup($groupName, $schemas)
   return f:gfindGroupUsingTypes($group, $alsoDerived, $schemas)
};

(:
 : =============================================
 : f i n d A t t G r o u p ...
 : =============================================
 :)

(:~
 : Finds the attribute declarations directly or indirectly 
 : contained by an attribute group definition. The 
 : attribute group is identifed by name. Attribute group 
 : references are recursively resolved.
 :
 : @param attGroupName the attribute group name
 : @schemas the schema elements
 : @return the attribute declarations directly or
 :    indirectly contained by the attribute group
 :    identified by $attGroupName
 :)
declare function f:findAttGroupAtts(
                        $attGroupName as xs:QName, 
                        $schemas as element(xs:schema)+) 
        as element()* {
        
    let $attGroup := f:findAttGroup($attGroupName, $schemas)
    return 
        f:hfindAttGroupAtts($attGroup, $schemas)
};

(:~
 : Finds the type definitions using an attribute group 
 : definition. The attribute group is identified by name. 
 :
 : @param attGroupName the attribute group name
 : @param alsoDerived if true, also extensions of types 
 :    using the group are returned
 : @param schemas the schema elements
 : @return the type definitions using the attribute
 :    group definition identified by $attGroupName
 :) 
declare function f:findAttGroupUsingTypes(
                        $attGroupName as xs:QName, 
                        $alsoDerived as xs:boolean?,
                        $schemas as element(xs:schema)+) 
        as element()* {
                      
    let $attGroup := f:findAttGroup($attGroupName, $schemas)
    return 
        f:hfindAttGroupUsingTypes($attGroup, $alsoDerived, $schemas)
};


(:
 : =======================================
 : t f i n d T y p e ...
 : =======================================
 :)

(:    t f i n d T y p e A t t F o r A t t N a m e    :)

declare function f:tfindTypeAttForAttName($type as element(xs:complexType)?, 
                                           $attName as xs:QName,
                                           $alsoInherited as xs:boolean?, 
                                           $schemas as element(xs:schema)+) 
      as element(xs:attribute)? {
   let $typeAtts := f:tfindTypeAtts($type, $alsoInherited, $schemas)
   let $matches := $typeAtts[f:getAttName(.) eq $attName][last()]
   return
      $matches
};

(:    
    t f i n d T y p e A t t s    
:)
(:~
 : Finds the attribute declarations contained or referenced by a type definition,
 : including the contents of referenced attribute groups, recursively resolved.
 : Base types are ignored unless "alsoInherited" is true.
 :
 : Only top level attribute declarations are considered, that is, attribute
 : declarations corresponding to attributes of the type owning element itself.
 :
 : @param type the type definition
 : @param alsoInherited if true, attributes of base types are also returned
 : @param schemas the schema elements currently considered
 : @return attribute declarations and/or attribute wildcards
 :)
declare function f:tfindTypeAtts($type as element(xs:complexType)?, 
                                 $schemas as element(xs:schema)+) 
      as element()* {
   if (empty($type)) then () else

   let $container := (
      $type/(xs:complexContent, xs:simpleContent)/(xs:extension, xs:restriction), 
      $type)[1]

   let $atts := $container/xs:attribute[not(@use eq 'prohibited')]
   let $anyAtt := $container/xs:anyAttribute[not(@use eq 'prohibited')]   
   let $groupAtts :=
      for $attGroupRef in $container/xs:attributeGroup
      let $attGroupName := $attGroupRef/@ref/resolve-QName(., ..)
      return
         f:findAttGroupAtts($attGroupName, $schemas)
   return
      ($atts, $anyAtt, $groupAtts)
};

(:    
    t f i n d T y p e A t t s    
:)
(:~
 : Finds the attribute declarations contained or referenced by a complex
 : type definition. Base types are ignored unless $alsoInherited is true. 
 . Only top level element declarations are considered, that is, attribute
 : declarations corresponding to attributes of the type owning
 : element itself.
 :)
declare function f:tfindTypeAtts($type as element(xs:complexType)?, 
                                 $alsoInherited as xs:boolean?, 
                                 $schemas as element(xs:schema)+) 
        as element(xs:attribute)* {
    if (empty($type)) then () else

    let $baseTypes := if (not($alsoInherited)) then () else f:tfindTypeBaseTypes($type, $schemas)
    let $allAtts := ($baseTypes, $type)[self::xs:complexType]/f:tfindTypeAtts(., $schemas)
    let $prohibitedNames := $allAtts[@use eq 'prohibited']/f:getAttName(.)
    return
        if (empty($prohibitedNames)) then $allAtts
        else $allAtts[not(f:getAttName(.) = $prohibitedNames) ]
};

(:    
    t f i n d T y p e C o n t e n t T y p e O r T y p e N a m e    
:)
(:~
 : Returns the content type of a complex type with simple content. If the
 : content type is built-in, the content type name is returned instead.
 :)
declare function f:tfindTypeContentTypeOrTypeName(
                        $type as element()?, 
                        $schemas as element(xs:schema)+) 
      as item()? {
   if (empty($type)) then() 
   else f:_tfindTypeContentTypeOrTypeNameRC($type, $schemas)
};

(:~
 : Recursive helper function of `tfindTypeContentTypeOrTypeName`.
 :)
declare function f:_tfindTypeContentTypeOrTypeNameRC(
                        $type as element()?, 
                        $schemas as element(xs:schema)+) 
      as item()? {
    let $explicit := $type/xs:simpleContent/*/xs:simpleType
    return
        if ($explicit) then $explicit else
        
    let $base := f:tfindTypeBaseTypeOrTypeName($type, $schemas)
    return
        if ($base instance of xs:QName) then $base
        else if ($base/self::xs:simpleType) then $base
        else f:_tfindTypeContentTypeOrTypeNameRC($base, $schemas)   
};


(:    
    t f i n d T y p e S u b T y p e T r e e    
:)
(:~
 : Returns all types derived from a given type definition, 
 : ordered by derivation depth.
 :)
declare function f:tfindTypeSubTypeTree($type as element()?, $schemas as element(xs:schema)+) 
        as element()? {
    if (empty($type)) then () else

    let $nsmap := app:getTnsPrefixMap($schemas)
    let $allTypes := $schemas//(xs:simpleType, xs:complexType)
    let $derived := f:_tfindTypeSubTypeTreeRC($type, $allTypes, $nsmap)    
    return
        <z:subTypeTree>{
            $derived/@*,
            $derived/*
        }</z:subTypeTree>            
};

declare function f:_tfindTypeSubTypeTreeRC($type as element(),
                                           $allTypes as element()*,
                                           $nsmap as element(z:nsMap)) 
        as element()* {        
    if (not($type/@name)) then <z:type name="z:_LOCAL_"/> else
    
    let $typeName := app:normalizeQName($type/QName(ancestor::xs:schema/@targetNamespace, @name), $nsmap)
    let $derivationKind := f:tgetTypeDerivationKind($type)
    let $derived := $allTypes[(xs:restriction, xs:extension, */(xs:restriction, xs:extension))/resolve-QName(@base, .) eq $typeName]
    return
        <z:type name="{$typeName}" derivation="{$derivationKind}">{
            for $dtype in $derived return f:_tfindTypeSubTypeTreeRC($dtype, $allTypes, $nsmap)
        }</z:type>
};

(:    
    t f i n d T y p e D e r i v a t i o n S t e p s    
:)
(:~
 : Returns for each base type a concatenation of derivation kind flag and
 : normalized type name. The derivation kind flag is 'e' for extension
 : and 'r' for restriction.
 :)
declare function f:tfindTypeDerivationSteps($type as element()?, 
                                            $schemas as element(xs:schema)+) 
        as xs:string* {

    if (empty($type)) then() else

    let $btype as element()? := f:tfindTypeBaseType($type, $schemas) 
    let $btypes :=
        if (empty($btype)) then () else
            (f:tfindTypeBaseTypes($btype, $schemas), $btype)
    let $nsmap := if (empty($btypes)) then () else app:getTnsPrefixMap($schemas)            
    for $type at $pos in $btypes
    let $kind := f:tgetTypeDerivationKind($type)
    let $flag := if (not($kind)) then 'r' else substring($kind, 1, 1)
    return
        concat($flag, '~', app:normalizeQName($type/QName(ancestor::xs:schema/@targetNamespace, @name), $nsmap))
};

(:    t f i n d T y p e C o n t a i n e r E l e m   :)

(:~
 : Finds the content container element of a type definition. 
 : The content container element is the element which may contain attribute,
 : attributeGroup and anyAtribute elements, as well as - in the case of
 : complex content - a sequence, choice, all or group element.
 :)
declare function f:tfindTypeContainerElem($type as element(), $schemas as element(xs:schema)+) 
      as element()? {
   let $cont := $type/(xs:simpleContent, xs:complexContent)/(xs:restriction, xs:extension)
   return
      ($cont, $type)[1]
};

(:~
 : Returns the xs:simpleContent of the given type definition or of the 
 : nearest ancestor type containing such an element. 
 : 
 : @param name the name of the type definition
 : @param schemas the schema elements currently considered
 : @return true if the type definition has a variety 'empty', false otherwise
 :)
declare function f:tfindTypeSimpleContent($type as element()?, 
                                          $schemas as element(xs:schema)+)
        as element(xs:simpleContent)? {                                          
    if ($type/xs:simpleType) then ()
    else f:tfindTypeSimpleContentRC($type, $schemas)
};

(:~
 : Recursive helper function of `tfindTypeSimpleContent`.
 :
 : @param type a type definition element
 : @param schemas the schemas currently considered
 : @return the xs:simpleContent contained by the given type or the 
 :     nearest ancestor type containing such an element
 :)
declare function f:tfindTypeSimpleContentRC($type as element()?, 
                                            $schemas as element(xs:schema)+)
        as element(xs:simpleContent)? {                                            
    if ($type/xs:simpleContent) then $type/xs:simpleContent
    else f:tfindTypeBaseType($type, $schemas)/f:tfindTypeSimpleContentRC(., $schemas) 
};

(:    t f i n d T y p e E l e m s    :)
(:~
 : Finds the element declarations contained or referenced by a type definition.
 : Extended base types are ignored. Any group references are recursively resolved. 
 . Only top level element declarations are considered, that is, element
 : declarations corresponding to immediate children of a type owner element.
 :)
declare function f:tfindTypeElems($type as element(xs:complexType)?, 
                                   $schemas as element(xs:schema)+) 
      as element(xs:element)* {
   if (empty($type)) then () else

   let $compositor := 
      ($type/(xs:complexContent, xs:simpleContent)/(xs:extension, xs:restriction), $type)[1]
         /(xs:group, xs:sequence, xs:choice, xs:all)
   return
      if ($compositor/self::xs:group) then 
         f:findGroupElems($compositor/@ref/resolve-QName(., ..), $schemas)
      else
         f:visitCompositorElems($compositor, $schemas)
};

(:    t f i n d T y p e E l e m s    :)
(:~
 : Finds the element declarations contained or referenced by a complex
 : type definition. Extended base types are ignored unless "alsoInherited" is true. 
 : Any group references are recursively resolved. 
 . Only top level element declarations are considered, that is, element
 : declarations corresponding to immediate children of the type owning
 : element itself.
 :)
declare function f:tfindTypeElems($type as element(xs:complexType)?, 
                                  $alsoInherited as xs:boolean?, 
                                  $schemas as element(xs:schema)+) 
      as element(xs:element)* {
   if (empty($type)) then () else

   let $baseTypes := if (not($alsoInherited)) then () else f:tfindTypeBaseTypes($type, $schemas)
   let $extendedTypes :=
      if (not($alsoInherited)) then () else
      let $lastRestrictionPos := 
         (
            for $baseType at $pos in $baseTypes
            where $baseType/(xs:simpleContent, xs:complexContent)/xs:restriction
            return $pos
         )[last()]
      return
         if (empty($lastRestrictionPos)) then $baseTypes else $baseTypes[position() ge $lastRestrictionPos]
   for $curType in ($extendedTypes, $type)
   where $curType/self::xs:complexType
   return
      f:tfindTypeElems($curType, $schemas)
};

(:    t f i n d T y p e E l e m s F o r E l e m N a m e    :)
(:~
 : Finds element declarations with a given name and contained or referenced 
 : by a given complex type definition. Extended base types are ignored 
 : unless "alsoInherited" is true. Any group references are recursively resolved. 
 . Only top level element declarations are considered, that is, element
 : declarations corresponding to immediate children of the type owning
 : element itself.
 :)
declare function f:tfindTypeElemsForElemName($type as element(xs:complexType)?, 
                                              $elemName as xs:QName,
                                              $alsoInherited as xs:boolean?, 
                                              $schemas as element(xs:schema)+) 
      as element(xs:element)* {
   let $typeElems := f:tfindTypeElems($type, $alsoInherited, $schemas)
   return
      $typeElems[f:getElemName(.) eq $elemName]
};

(:    t f i n d T y p e D e c l s F o r X P a t h    :)

(:~
 : Finds the element or attribute declarations directly or indirectly
 : contained by a type declaration, located by an XPath expression.
 : A declaration is located by the XPath if in an instance document
 : the instances of that declaration would be located by applying 
 : the XPath to an element governed by the type definition.
 :)
declare function f:tfindTypeDeclsForXPath($type as element(xs:complexType)?, 
                                           $xpath as xs:string,
                                           $namespaceContext as element()?,
                                           $alsoInherited as xs:boolean?, 
                                           $schemas as element(xs:schema)+) 
      as element()* {
   let $split := replace($xpath, "(/+)?([^/]+)(.*)?", "$1#$2#$3")
   let $parts := tokenize($split, '#')
   let $operator := ($parts[1][string()], "/")[1]
   let $nodeTest := $parts[2][string()]
   let $next := $parts[3][string()]

   return
      if (starts-with($nodeTest, '@'))
      then
         let $attName :=
            let $text := substring($nodeTest, 2)
            return
               if (empty($namespaceContext) or not(contains($text, ':'))) then QName((), $text)
               else resolve-QName($text, $namespaceContext)
         return
            if ($operator eq '/') then f:tfindTypeAttForAttName($type, $attName, $alsoInherited, $schemas)
            else
               tt:createError("NOT_YET_IMPL", 
                  "tfindTypeDeclsForXPath: not yet implemented: operators other than a single /", ())
      else
         let $elemName := 
            if (empty($namespaceContext)) then QName((), $nodeTest)
            else resolve-QName($nodeTest, $namespaceContext)

         let $elems := 
            if ($operator eq '/') then
               f:tfindTypeElemsForElemName($type, $elemName, $alsoInherited, $schemas)
            else
               tt:createError("NOT_YET_IMPL", 
                  "tfindTypeDeclsForXPath: not yet implemented: operators other than a single /", ())
         return
            if (empty($elems)) then ()
            else if (empty($next)) then $elems
            else
               let $elemTypes := $elems/f:efindElemTypeOrTypeName(., $schemas)[. instance of node()]
               return
                  $elemTypes/f:tfindTypeDeclsForXPath(., $next, $namespaceContext, true(), $schemas)
};

(:    t f i n d T y p e S u b T y p e s    :)

(:~
 : Returns sub types of a given type definition. The type definition is
 : supplied as a schema element (xs:simpleType or xs:complexType). 
 : If $alsoIndirect is true, also indirectly derived
 : types are returned, otherwise only direct sub types. If $devKind is
 : 'extension' or 'restriction', only types derived by extension or 
 : restriction, respectively, are returned.
 :
 : @param types the type definitions
 : @param alsoIndirect if true, also directly derived sub types are returned
 : @param devKind if set to 'restriction' or 'extension', only sub types
 :   derived by restriction or extension, respectively, are returned
 : @param schemas the currently considered schema elements
 : @return the sub types
 :)
declare function f:tfindTypeSubTypes(
                       $types as element()*,
                       $alsoIndirect as xs:boolean?,
                       $devKind as xs:string?,
                       $schemas as element(xs:schema)+) 
        as element()* {

    let $names := $types/@name/QName(ancestor::xs:schema/@targetNamespace, .)
    let $refs := $schemas//(xs:restriction, xs:extension)/@base[resolve-QName(., ..) = $names]
    let $refs := 
        if ($devKind eq 'extension') then $refs[parent::xs:extension]
        else if ($devKind eq 'restriction') then $refs[parent::xs:restriction]
        else $refs
    let $directSubTypes := $refs/ancestor::*[local-name() = ('simpleType', 'complexType')][1]
    return (
        $directSubTypes,
        if (empty($directSubTypes)) then () else
            f:tfindTypeSubTypes($directSubTypes[@name], true(), $devKind, $schemas)
    )                        
};


(:    t f i n d T y p e U s i n g A t t s    :)

declare function f:tfindTypeUsingAtts(
                      $types as element()*, 
                      $alsoDerived as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element(xs:attribute)* {
      
   if (empty($types)) then () else
   
   let $useTypes :=
      if (not($alsoDerived)) then $types else
         $types | f:tfindTypeSubTypes($types, true(), 'extension', $schemas)
   let $names as xs:QName* := 
      distinct-values($useTypes/@name/QName(ancestor::xs:schema/@targetNamespace, .))
         
   let $anoItems := $useTypes[not(@name)]/..[self::xs:attribute]
   let $namedItems := $schemas//xs:attribute[resolve-QName(@type, .) = $names]
   return 
      ($anoItems | $namedItems)         
};

(:    t f i n d T y p e U s i n g E l e m s    :)
(:~
 : Finds all element declarations referencing given
 : type definitions. If $alsoDerived is true, also the
 : element declarations referencing a type derived from
 : one of the given types are returned.
 :
 : @param types the type definitions
 : @param alsoDerived if true, also elements referencing
 :    derived types are considered
 : @param schemas the schema elements currently considered
 : @return the element declarations referencing the given
 :    type definitions
 :)
declare function f:tfindTypeUsingElems(
                      $types as element()*, 
                      $alsoDerived as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element(xs:element)* {
   
   if (empty($types)) then () else
   
   let $useTypes :=
      if (not($alsoDerived)) then $types else
         $types | f:tfindTypeSubTypes($types, true(), 'extension', $schemas)
   let $names as xs:QName* := 
      distinct-values($useTypes[@name]/app:getTypeComponentName(.))
         
   let $elems4ano := $useTypes[not(@name)]/parent::xs:element
   let $elems4names := $schemas//xs:element[resolve-QName(@type, .) = $names]
   return 
      ($elems4ano | $elems4names)         
};

(:    t f i n d T y p e U s i n g I t e m s    :)

declare function f:tfindTypeUsingItems(
                      $types as element()*, 
                      $alsoDerived as xs:boolean?, 
                      $schemas as element(xs:schema)+) 
      as element()* {
      
   if (empty($types)) then () else
   
   let $useTypes :=
      if (not($alsoDerived)) then $types else
         $types | f:tfindTypeSubTypes($types, true(), 'extension', $schemas)
   let $names as xs:QName* := 
      distinct-values($useTypes/@name/QName(ancestor::xs:schema/@targetNamespace, .))
         
   let $anoItems := $useTypes[not(@name)]/..[self::xs:element, self::xs:attribute]
   let $namedItems := $schemas//(xs:element, xs:attribute)[resolve-QName(@type, .) = $names]
   return 
      ($anoItems | $namedItems)         
};



(:
 : =======================================
 : a f i n d A t t ...
 : =======================================
 :)

(:    
    a f i n d A t t T y p e O r T y p e N a m e    
:)
(:~
 : Returns for a given attribute declaration the type
 : definition or type name. If the type is built-in, the
 : type name is returned, otherwise the type definition.
 :
 : @param att the attribute declaration
 : @param schemas the schema elements currently considered
 : @return the type definition or type name
 :) 
declare function f:afindAttTypeOrTypeName(
                        $att as element(xs:attribute)?, 
                        $schemas as element(xs:schema)+) 
        as item()* {
        
    if (empty($att)) then () else

    let $att := if ($att/@ref) then f:rfindAtt($att/@ref, $schemas) else $att        
    let $typeOrTypeName :=
        let $try := f:rfindTypeOrTypeName($att/@type, $schemas)
        return
            if (empty($try)) then $att/xs:simpleType
            else $try
    return
        $typeOrTypeName
(:        
    let $typeNames := 
        for $n in distinct-values($typesOrTypeNames[. instance of xs:anyAtomicType])
        order by lower-case(string($n))
        return $n
    let $typeDefs := $typesOrTypeNames[. instance of node()]/.        
    return
        ($typeNames, $typeDefs)
:)        
};

(:~
 : Finds for given attribute declarations the element declarations
 : of possible parent elements.
 :
 : @param elems element declarations
 : @schemas the schema elements
 : @return the element declarations of elements which may have a child
 :    element governed by one of the declarations given
 :    by elems 
 :)
declare function f:afindAttParents(
                        $comps as element(xs:attribute)*, 
                        $schemas as element(xs:schema)+) 
        as element(xs:element)* {
        
   if (empty($comps)) then () else

   let $parentTypes :=
      let $ancestors := $comps/ancestor::*[local-name() = ('complexType', 'attributeGroup')][1]
      return (
         $ancestors[self::xs:complexType],
         f:hfindAttGroupUsingTypes($ancestors[self::xs:attributeGroup], false(), $schemas)
      )
   return
      f:tfindTypeUsingElems($parentTypes, true(), $schemas)            
};

(:
 : =======================================
 : e f i n d E l e m ...
 : =======================================
 :)

(:    e f i n d E l e m T y p e    :)
(:~
 : Finds for a given element declaration the type definition.
 :
 : @param elem the element declaration
 : @param schemas the schema elements currently considered
 :)
declare function f:efindElemType($elem as element(xs:element)?, 
                                 $schemas as element(xs:schema)+) 
        as item()? {
    if (empty($elem)) then () else

    let $useElem := 
        if (not($elem/@ref)) then $elem else f:rfindElem($elem/@ref, $schemas)
    return
        if (not($useElem/@type)) then $useElem/(xs:simpleType, xs:complexType)
        else f:rfindType($useElem/@type, $schemas)
};

(:    e f i n d E l e m T y p e O r T y p e N a m e    :)

(:~
 : Returns for a given element declaration the type
 : definition or type name. If the type is built-in, the
 : type name is returned, otherwise the type definition.
 :
 : @param elem the element declaration
 : @param schemas the schema elements currently considered
 : @return the type definition or type name
 :) 
declare function f:efindElemTypeOrTypeName($elem as element(xs:element)?, 
                                           $schemas as element(xs:schema)+) 
      as item()? {
   if (empty($elem)) then () else

   let $elemD := if (not($elem/@ref)) then $elem else f:rfindElem($elem/@ref, $schemas)

   return
      if (not($elemD/@type)) then $elemD/(xs:simpleType, xs:complexType)
      else f:rfindTypeOrTypeName($elemD/@type, $schemas)
};

(:
 : =======================================
 : d f i n d D e c l ...
 : =======================================
 : Supply information related to an item which may be an element or attribute declaration.
 :)

(:    i f i n d I t e m T y p e Or T y p e N a m e    :)

declare function f:dfindDeclTypeOrTypeName($decl as element()?, 
                                            $schemas as element(xs:schema)+) 
      as item()? {
   if (empty($decl)) then ()
   else if ($decl/self::xs:element) then f:efindElemTypeOrTypeName($decl, $schemas)
   else if ($decl/self::xs:attribute) then f:afindAttTypeOrTypeName($decl, $schemas)
   else ()
};

(:
 : =======================================
 : g f i n d G r o u p ...
 : =======================================
 :)

declare function f:gfindGroupElems($group as element(xs:group)?, 
                                   $schemas as element(xs:schema)+) 
      as element(xs:element)* {
   if (empty($group)) then () else

   let $compositor :=
      $group/(xs:sequence, xs:choice, xs:all)
   return
      f:visitCompositorElems($compositor, $schemas)
};

(:~
 : Finds the type definitions using given group definitions. 
 :
 : @param groups the group definitions
 : @param alsoDerived if true, also extensions of types 
 :    using the group are returned
 : @param schemas the schema elemets
 : @return the type definitions using a group definition
 :    given by $groups
 :)
declare function f:gfindGroupUsingTypes(
                        $groups as element(xs:group)*,
                        $alsoDerived as xs:boolean?,
                        $schemas as element(xs:schema)+) 
        as element()* {
                      
   if (not($groups/@name)) then () else
   
   let $names := $groups/@name/QName(ancestor::xs:schema/@targetNamespace, .)
   let $refs := $schemas//xs:group[@ref/resolve-QName(., ..) = $names]
   let $types := 
      for $ref in $refs
      let $anc := $ref/ancestor::*[local-name() = ('complexType', 'group')][1]
      return
         if ($anc/self::xs:complexType) then $anc
         else f:gfindGroupUsingTypes($anc, $alsoDerived, $schemas)
   let $types :=
      if (not($alsoDerived)) then $types/.
      else
         $types | f:tfindTypeSubTypes($types, true(), 'extension', $schemas)
   return
      $types
};

(:
 : =======================================
 : h f i n d A t t G r o u p ...
 : =======================================
 :)

(:~ 
 : Finds the attribute declarations directly or indirectly 
 : contained by given attribute group definitions. Attribute 
 : group references are recursively resolved.
 :
 : If the groups contain xs:anyAttribute wildcards,
 : their declarations are returned, even if there
 : are several - integration of wildcards into
 : a single wildcard is not performed.
 :
 : @param attGroups attribute group definitions
 : @schemas the schema elements
 : @return the attribute declarations directly or
 :    indirectly contained by the attribute group
 :    definitions supplied by $attGroups
 :)
declare function f:hfindAttGroupAtts(
                        $attGroups as element(xs:attributeGroup)*, 
                        $schemas as element(xs:schema)+) 
        as element()* {
    if (empty($attGroups)) then () else

    let $useAttGroup := 
        for $attGroup in $attGroups return
            if ($attGroup/@name) then $attGroup 
            else if ($attGroup/@ref) then f:rfindAttGroup($attGroup/@ref, $schemas)
            else
                tt:createError("INVALID_INPUT", 
                    "xs:attributeGroup element must have either 'name' or 'ref' attribute", ())

    let $atts := $useAttGroup/xs:attribute
    let $anyAtts := $useAttGroup/xs:anyAttribute    
    let $attGroupAtts := 
        for $agRef in $useAttGroup/xs:attributeGroup/@ref
        let $agName := resolve-QName($agRef, $agRef/..)
        return
            f:findAttGroupAtts($agName, $schemas)
    return
        ($atts, $anyAtts, $attGroupAtts)/.
};

(:~
 : Finds the type definitions using given attribute group 
 : definitions.
 :
 : @param attGroups the attribute group definitions
 : @param alsoDerived if true, also extensions of types 
 :    using the group are returned
 : @param schemas the schema elemets
 : @return the type definitions using a group definition
 :    given by $groups
 :)
declare function f:hfindAttGroupUsingTypes(
                        $attGroups as element(xs:attributeGroup)*,
                        $alsoDerived as xs:boolean?,
                        $schemas as element(xs:schema)+) 
        as element()* {
                      
   if (not($attGroups/@name)) then () else
   
   let $names := $attGroups/@name/QName(ancestor::xs:schema/@targetNamespace, .)
   let $refs := $schemas//xs:attributeGroup[@ref/resolve-QName(., ..) = $names]
   let $types := 
      for $ref in $refs
      let $anc := $ref/ancestor::*[local-name() = ('complexType', 'attributeGroup')][1]
      return
         if ($anc/self::xs:complexType) then $anc
         else f:hfindAttGroupUsingTypes($anc, $alsoDerived, $schemas)
   let $types :=
      if (not($alsoDerived)) then $types/.
      else
         $types | f:tfindTypeSubTypes($types, true(), 'extension', $schemas)
   return
      $types
};
(:
 : =============================================
 : o t h e r    n a v i g a t i o n s
 : =============================================
 :)
(: Returns all element declarations directly or indirectly contained
 : by a compositor. The compositor can be either an xs:sequence, xs:choice or
 : xs:all element.
 :)
declare function f:visitCompositorElems($compositor as element()?, 
                                         $schemas as element(xs:schema)+) as element(xs:element)* {
   if (empty($compositor)) then () else

   (: check input :)
   if (not($compositor/self::xs:sequence or $compositor/self::xs:choice or $compositor/self::xs:all)) then
      tt:createError("INVALID_INPUT", concat("visitCopositorElems: ",
            "parameter $compositor must be a compositor element (",
            "one of: xs:sequence, xs:choice, xs:all)"), ()) else

   (: process :)
   for $c in $compositor/(* except xs:annotation) return
      if ($c/self::xs:element) then $c
      else if ($c/self::xs:sequence or $c/self::xs:choice or $c/self::xs:all) then
         f:visitCompositorElems($c, $schemas)
      else if ($c/self::xs:group) then
         let $groupName := $c/@ref/resolve-QName(., ..)
         return
            f:findGroupElems($groupName, $schemas)
      else if ($c/self::xs:any) then ()
      else 
         tt:createError("UNEXPECTED_INPUT", concat("visitCopositorElems: ",
            "$compositor has unexpected child element, name: ", name($c)), ())
};

