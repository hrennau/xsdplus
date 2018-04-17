(:
 : -------------------------------------------------------------------------
 :
 : componentFinder.xqm - functions for finding schema components.
 :
 : -------------------------------------------------------------------------
 :)

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm";    

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at 
    "treeNavigator.xqm";    

declare namespace i="http://www.xsdplus.org/ns/xquery-functions";
declare namespace z="http://www.xsdplus.org/ns/structure";

 (:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(: 
 :    f i n d    t o p - l e v e l    c o m p o n e n t s
 :)

(:~
 : Finds a top-level attribute declaration identified by name.
 :
 : @param name the attribute declaration name
 : @param schemas the schema elements currently considered
 : @return the attribute declaration, or the empty sequence
 :)
declare function f:findAtt($name as xs:QName, 
                           $schemas as element(xs:schema)+) 
        as element(xs:attribute)? {
    let $uri := namespace-uri-from-QName($name)
    let $lname := local-name-from-QName($name)
    let $actSchemas := if ($uri) then $schemas[@targetNamespace eq $uri] 
                       else $schemas[not(@targetNamespace)]
    return $actSchemas/xs:attribute[@name eq $lname]
};

(:~
 : Finds all attribute declarations describing attributes with a 
 : given name. Note that for a given attribute declaration, the names
 : of attributes described by it depend on @attributeForm and
 : @defaultAttributeForm attributes.
 :
 : @param name an attribute name
 : @param schemas the schema elements currently considered 
 : @return matching attribute declarations 
 :)
declare function f:findAtts(
                        $name as xs:QName, 
                        $schemas as element(xs:schema)+) 
        as element(xs:attribute)* {
        
    let $uri := namespace-uri-from-QName($name)
    let $lname := local-name-from-QName($name)    
    return
        if ($uri) then
            $schemas[@targetNamespace eq $uri]/(
                xs:attribute[@name eq $lname],
                *//xs:attribute[@name eq $lname]['qualified' = 
                (@attributeForm, ancestor::xs:schema/@attributeFormDefault)[1]]
            )
        else (   
            $schemas[not(@targetNamespace)]//xs:attribute[@name eq $lname],
            $schemas[@targetNamespace]/*//xs:attribute[@name eq $lname][not('qualified' =
                   (@attributeForm, ancestor::xs:schema/@attributeFormDefault)[1])]
        )
};

(:~
 : Finds an attribute group definition identified by name.
 :
 : @param name the attribute group name
 : @param schemas the schema elements currently considered
 : @return the attribute group definition, or the empty sequence
 :)
declare function f:findAttGroup(
                        $name as xs:QName, 
                        $schemas as element(xs:schema)+) 
        as element(xs:attributeGroup)? {        
    let $uri := namespace-uri-from-QName($name)
    let $lname := local-name-from-QName($name)
    let $actSchemas := if ($uri) then $schemas[@targetNamespace eq $uri] 
                       else $schemas[not(@targetNamespace)]
    let $result := $actSchemas/xs:attributeGroup[@name eq $lname]
    return 
        if (count($result) le 1) then $result
        else i:resolveDuplicateComponents($result)
};

(:~
 : Finds a top-level element declaration identified by name.
 :
 : @param name the element name
 : @param schemas the schema elements currently considered
 : @return the element declaration, or the empty sequence
 :)
declare function f:findElem($name as xs:QName, $schemas as element(xs:schema)+) 
        as element(xs:element)? {
    let $uri := namespace-uri-from-QName($name)
    let $lname := local-name-from-QName($name)
    let $actSchemas := 
        if ($uri) then $schemas[@targetNamespace eq $uri] 
        else $schemas[not(@targetNamespace)]
    let $result := $actSchemas/xs:element[@name eq $lname]
    return
        if (count($result) le 1) then $result
        else i:resolveDuplicateComponents($result)
};

(:~
 : Finds all element declarations describing elements with a 
 : given name. Note that for a given element declaration, the 
 : names of elements described by it depend on @elementForm and
 : @defaultElementForm attributes.
 :
 : @param name an element name
 : @param schemas the schema elements currently considered 
 : @return matching element declarations 
 :)
declare function f:findElems(
                        $name as xs:QName, 
                        $schemas as element(xs:schema)+) 
        as element(xs:element)* {        
    let $uri := namespace-uri-from-QName($name)
    let $lname := local-name-from-QName($name)    
    return
        if ($uri) then
            $schemas[@targetNamespace eq $uri]/(
                xs:element[@name eq $lname],
                *//xs:element[@name eq $lname]
                ['qualified' = 
                    (@elementForm, ancestor::xs:schema/@elementFormDefault)[1]]
            )
        else (   
            $schemas[not(@targetNamespace)]//xs:element[@name eq $lname],
            $schemas[@targetNamespace]/*//xs:element[@name eq $lname]
            [not('qualified' =
                (@elementForm, ancestor::xs:schema/@elementFormDefault)[1])]
        )
};

(:~
 : Finds a group definition identified by name.
 :
 : @param name the group name
 : @param schemas the schema elements currently considered
 : @return the group definition, or the empty sequence
 :)
declare function f:findGroup($name as xs:QName, $schemas as element(xs:schema)+) 
        as element(xs:group)? {
    let $uri := namespace-uri-from-QName($name)
    let $lname := local-name-from-QName($name)
    let $actSchemas := if ($uri) then $schemas[@targetNamespace eq $uri] 
                       else $schemas[not(@targetNamespace)]
    let $result := $actSchemas/xs:group[@name eq $lname]                       
    return 
        if (count($result) le 1) then $result
        else i:resolveDuplicateComponents($result)
};

(:~
 : Finds a type definition identified by name. If the type is
 : builtin, the empty sequence is returned.
 :
 : @param name the type name
 : @param schemas the schema elements currently considered
 : @return the type definition, or the empty sequence
 :)
declare function f:findType($name as xs:QName, 
                            $schemas as element(xs:schema)+) 
        as element()? {
    let $uri := namespace-uri-from-QName($name)
    return if ($uri eq $tt:URI_XSD) then () else
   
    let $lname := local-name-from-QName($name)
    let $actSchemas := if ($uri) then $schemas[@targetNamespace eq $uri] 
                       else $schemas[not(@targetNamespace)]
    let $result := 
        $actSchemas/(xs:simpleType|xs:complexType)[@name eq $lname]
    return 
        if (count($result) gt 1) then i:resolveDuplicateComponents($result)
        else $result
};

(:
(: 
 :    f i n d    b a s e    t y p e s
 :)
 
(:~
 : Returns the base type definition of a given type definition. 
 : The type definition is specified by name.
 :
 : Note. When the base type is a built-in type, the empty 
 : sequence is returned.
 :
 : @param typeName a type name
 : @param schemas the schema elements currently considered
 : @return the base type definition
 :)
declare function f:findTypeBaseType($typeName as xs:QName, 
                                    $schemas as element(xs:schema)+) 
      as element()? {
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeBaseType($type, $schemas)   
};

(:~
 : Finds the base type definition of a given type definition. If the
 : base type is built-in, the empty sequence is returned.
 :
 : Note. If in case of a built-in base type the base type name is desired,
 : use function 'tfindTypeBaseTypeOrTypeName'.
 :
 : @param type a type definition
 : @param schemas the schema elements currently considered.
 : @return the base type definition, or the empty sequence if the given
 :    type has no user-defined base type
 :)
declare function f:tfindTypeBaseType($type as element()?, 
                                     $schemas as element(xs:schema)+) 
      as element()? {
   if (empty($type)) then() else
      f:tfindTypeBaseTypeOrTypeName($type, $schemas)[. instance of node()]
};

(:~
 : Returns all base type definitions of a given type, identified by name. 
 : The type definitions are ordered by derivation depth. Note that in 
 : case of a type derived from a builtin base type, the base type name 
 : is not added to the result sequence. Also note that the given type 
 : definition ($type) is not added to the result sequence neither - only 
 : "real" base type definitions are returned.
 :
 : @param type the type definition
 : @param schemas the schema elements currently considered
 : @return the base type definitions
 :)
declare function f:findTypeBaseTypes($typeName as xs:QName, 
                                     $schemas as element(xs:schema)+) 
        as element()* {
    let $type := f:findType($typeName, $schemas)
    return f:tfindTypeBaseTypes($type, $schemas)   
};

(:~
 : Returns all base type definitions of a given type definition, 
 : ordered by derivation depth. Note that in case of a type derived
 : from a builtin base type, the base type name is not added to the 
 : result sequence. Also note that the given type definition ($type) 
 : is not added to the result sequence neither - only "real" base type 
 : definitions are returned.
 :
 : @param type the type definition
 : @param schemas the schema elements currently considered
 : @return the base type definitions
 :)
declare function f:tfindTypeBaseTypes(
                        $type as element()?, 
                        $schemas as element(xs:schema)+) 
        as element()* {
   if (empty($type)) then() else

   let $btype as element()? := f:tfindTypeBaseType($type, $schemas) 
   return
      if (empty($btype)) then () else
         (f:tfindTypeBaseTypes($btype, $schemas), $btype)
};

(:~
 : Returns the base type name of a given type definition. 
 : The type definition is specified by name.
 :
 : @param typeName a type name
 : @param schemas the schema elements currently considered
 : @return the name of the base type
 :)
declare function f:findTypeBaseTypeName($typeName as xs:QName, $schemas as element(xs:schema)+) 
      as xs:QName? {
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeBaseTypeName($type, $schemas)   
};

(:~
 : Returns the base type name of a given type definition. 
 :
 : @param type a type definition
 : @param schemas the schema elements currently considered
 : @return the name of the base type
 :)
declare function f:tfindTypeBaseTypeName($type as element()?, $schemas as element(xs:schema)+) 
      as xs:QName? {
    if (empty($type)) then() else
    let $baseTypeOrTypeName as item()? := 
        f:tfindTypeBaseTypeOrTypeName($type, $schemas)
    return
        if ($baseTypeOrTypeName instance of node()) then 
            $baseTypeOrTypeName/@name/resolve-QName(., ..)
        else 
            $baseTypeOrTypeName
};

(:~
 : Returns all base type names of a given type definition, 
 : ordered by derivation depth. The type definition is specified
 : by name.
 :
 : @param typeName a type name
 : @param schemas the schema elements currently considered
 : @return the base type names
 :)
declare function f:findTypeBaseTypeNames($typeName as xs:QName, 
                                         $schemas as element(xs:schema)+) 
        as xs:QName* {
    let $type := f:findType($typeName, $schemas)
    return f:tfindTypeBaseTypeNames($type, $schemas)   
};

(:~
 : Returns all base type names of a given type definition, 
 : ordered by derivation depth.
 :
 : @param type a type definition
 : @param schemas the schema elements currently considered
 : @return the base type names
 :)
declare function f:tfindTypeBaseTypeNames($type as element()?, 
                                          $schemas as element(xs:schema)+) 
        as xs:QName* {
    if (empty($type)) then() else

    let $btype as element()? := f:tfindTypeBaseType($type, $schemas) 
    let $btypes :=
        if (empty($btype)) then () else        
            (f:tfindTypeBaseTypes($btype, $schemas), $btype)
    let $nsmap := if (empty($btypes)) then () else app:getTnsPrefixMap($schemas)            
    return
        for $btype in $btypes
        let $name := $btype/@name/app:normalizeQName(QName(ancestor::xs:schema/@targetNamespace, .), $nsmap)
        let $name := if (exists($name)) then $name else QName((), '_LOCAL_')
        return
            $name 
};

(:~
 : Returns the base type definition of a given type identified
 : by name, or the base type name, if it is a built-in type.
 :
 : @param typeName a type name
 : @param schemas the schema elements currently considered
 : @return the base type definition, or the name of the built-in
 :    base type
 :)
declare function f:findTypeBaseTypeOrTypeName(
                       $typeName as xs:QName, 
                       $schemas as element(xs:schema)+) 
      as item()? {
   let $type := f:findType($typeName, $schemas)
   return f:tfindTypeBaseTypeOrTypeName($type, $schemas)   
};

(:~
 : Returns the base type definition of a given type definition, or the
 : base type name, if it is a built-in type. 
 :
 : @param type a type definition
 : @param schemas the schema elements currently considered.
 : @return the base type definition, or the name of the built-in
 :    base type
 :)
declare function f:tfindTypeBaseTypeOrTypeName(
                        $type as element()?, 
                        $schemas as element(xs:schema)+) 
      as item()? {
    if (empty($type)) then() else
    let $btypeAtt as attribute(base)? :=
        if ($type/self::xs:simpleType) then $type/xs:restriction/@base
        else $type/(xs:simpleContent, xs:complexContent)/
                   (xs:extension, xs:restriction)/@base
    let $btypeName as xs:QName? := $btypeAtt/resolve-QName(., ..)
    return
        if (empty($btypeName)) then () 
        else if (namespace-uri-from-QName($btypeName) eq $tt:URI_XSD) then $btypeName
        else
            f:findType($btypeName, $schemas)
};

(:~
 : Returns the built-in base type name of a given type definition 
 : specified by name.
 :
 : @param typeName a type name
 : @param schemas the schema elements currently considered
 : @return the built-in base type name
 :)
declare function f:findTypeBuiltinBaseTypeName($typeName as xs:QName?, 
                                               $schemas as element(xs:schema)+) 
        as xs:QName? {
    if (empty($typeName)) then () else
    
    if (namespace-uri-from-QName($typeName) eq $tt:URI_XSD) then
        if (not(local-name-from-QName($typeName) = 'anyType')) then $typeName else ()
        
    else        
        let $type := f:findType($typeName, $schemas)
        return f:tfindTypeBuiltinBaseTypeName($type, $schemas)   
};

(:~
 : Returns the built-in base type name of a given type definition.
 :
 : @param type a type definition
 : @param schemas the schema elements currently considered
 : @return the built-in base type name
 :)
declare function f:tfindTypeBuiltinBaseTypeName($type as element()?, 
                                                $schemas as element(xs:schema)+) 
        as xs:QName? {
    let $firstUdefBaseType := (f:tfindTypeBaseTypes($type, $schemas)[1], $type)[1]
    let $builtin := f:tfindTypeBaseTypeOrTypeName($firstUdefBaseType, $schemas)
    return
        if (empty($builtin)) then ()
        else
            let $ns := namespace-uri-from-QName($builtin)
            let $lname := local-name-from-QName($builtin)
            return
                if ($ns eq $tt:URI_XSD and not($lname = 'anyType')) then $builtin
                else ()
};
:)

(: 
 :    f i n d    s u b s t i t u t i o n    g r o u p    m e m b e r s
 :)

(:~
 : Finds the members of a substitution group specified by
 : the head element name.
 :
 : @param headName the name of the group head element
 : @param schemas the schema elements currently considered
 : @return the element declarations belonging to the substitution
 :     group
 :)
declare function f:findSubstitutionGroupMembers(
                        $headName as xs:QName, 
                        $schemas as element(xs:schema)+)
        as element(xs:element)* {
    $schemas/xs:element
        [@substitutionGroup]
        [some $g in tokenize(normalize-space(@substitutionGroup), ' ') satisfies 
            resolve-QName($g, ..) eq $headName]        
};        

(:~
 : Finds the members of a substitution group specifed by
 : head element declaration.
 :
 : @param headElem the element declaration of the group head element
 : @param schemas the schema elements currently considered
 : @return the element declarations belonging to the substitution
 :     group
 :)
declare function f:findSubstitutionGroup(
                        $elem as element(xs:element), 
                        $schemas as element(xs:schema)+)
        as element(xs:element)* {
    if (not($elem/@ref)) then ()
    else
        let $headName := resolve-QName($elem/@ref, $elem)
        return
            f:findSubstitutionGroupMembers($headName, $schemas)
};   
