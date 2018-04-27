(:
 : -------------------------------------------------------------------------
 :
 : simpleTypeInfo.xqm - functions creating descriptions of simple type definitions
 :
 : -------------------------------------------------------------------------
 :)

(:~@operations
   <operations>   
      <operation name="stypeTree" type="node()" func="opStypeTree">
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="anames" type="nameFilter?" pgroup="comps"/>         
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="false"/>        
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <pgroup name="in" minOccurs="1"/>    
         <pgroup name="comps" maxOccurs="1"/>         
      </operation>
      <operation name="stypeDesc" type="node()" func="opStypeDesc">
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="anames" type="nameFilter?" pgroup="comps"/>         
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="false"/>        
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <pgroup name="in" minOccurs="1"/>    
         <pgroup name="comps" maxOccurs="1"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.xsdplus.org/ns/xquery-functions"; 

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";
    
import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at
    "componentFinder.xqm",
    "componentNavigator.xqm",
    "constants.xqm";

declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";
declare namespace xs="http://www.w3.org/2001/XMLSchema";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `stypeTree`.
 :
 : @param request the operation request
 : @return a report containing location tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:opStypeTree($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $tnames := tt:getParams($request, 'tnames')    
    let $enames := tt:getParams($request, 'enames')    
    let $anames := tt:getParams($request, 'anames')    
    let $global := tt:getParams($request, 'global')    
    let $format := tt:getParams($request, 'format')
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $stypeTrees := 
        f:stypeTrees($tnames, $enames, $anames, $global, $format, $nsmap, $schemas)
    return            
        <z:_stypeTrees_ count="{count($stypeTrees)}" xmlns:xs="http://www.w3.org/2001/XMLSchema">{
            $stypeTrees
        }</z:_stypeTrees_>
};     

(:~
 : Implements operation `stypeTree`.
 :
 : @param request the operation request
 : @return a report containing location tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:opStypeDesc($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $tnames := tt:getParams($request, 'tnames')    
    let $enames := tt:getParams($request, 'enames')    
    let $anames := tt:getParams($request, 'anames')    
    let $global := tt:getParams($request, 'global')    
    let $format := tt:getParams($request, 'format')
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $stypeTrees :=
        f:stypeTrees($tnames, $enames, $anames, $global, $format, $nsmap, $schemas)
    let $stypeTreesReport :=        
        <z:_stypeTrees_ count="{count($stypeTrees)}" xmlns:xs="http://www.w3.org/2001/XMLSchema">{
            $stypeTrees
        }</z:_stypeTrees_>        
    let $stypeDescs :=
        copy $copy := $stypeTreesReport
        modify
            for $stypeTree in $copy//z:_stypeTree_
            return
                replace node $stypeTree with
                    <z:_stypeDesc_>{
                        $stypeTree/@*,
                        f:stypeTree2StypeDesc($stypeTree, ())
                    }</z:_stypeDesc_>
        return $copy                    
    return            
        $stypeDescs
(:        
        <z:_stypeDescs_ count="{count($stypeTrees)}" xmlns:xs="http://www.w3.org/2001/XMLSchema">{
            for $stypeTree in $stypeTrees
            return
                <z:_stypeDesc_>{
                    $stypeTree/@*,
                    f:stypeTree2StypeDesc($stypeTree, ())
                }</z:_stypeDesc_>
        }</z:_stypeDescs_>
:)        
};     


(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Maps names of type definitions, element declarations and/or attribute 
 : declarations to a sequence of simple type trees.
 :
 : @param request the operation request
 : @return a report containing location tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:stypeTrees($tnames as element(nameFilter)?,
                              $enames as element(nameFilter)?,
                              $anames as element(nameFilter)?,                              
                              $global as xs:boolean?,
                              $format as xs:string?,
                              $nsmap as element(zz:nsMap)?,
                              $schemas as element(xs:schema)+)
        as element()* {
    let $nsmap :=
        if ($nsmap) then $nsmap
        else app:getTnsPrefixMap($schemas)
    let $components := app:getComponents($enames, $anames, $tnames, (), (), $global, $schemas)
    
    let $stypes := $components/self::xs:simpleType    
    let $ctypes := $components/self::xs:complexType    
    let $atts := $components/self::xs:attribute
    let $elems := $components/self::xs:element   
    
    let $reportSimpleTypes :=
        if (not($stypes)) then () else
        
        let $stypeTrees := $stypes/f:stypeTree(., $nsmap, $schemas)
        return
            <z:_stypes count="{count($stypeTrees)}">{$stypeTrees}</z:_stypes>

    let $reportComplexTypes :=
        if (not($ctypes)) then () else
        
        let $ctypeTrees := $ctypes/f:stypeTree(., $nsmap, $schemas)
        where $ctypeTrees
        return
            <z:_ctypes count="{count($ctypeTrees)}">{$ctypeTrees}</z:_ctypes>

    let $reportAttsAndElems :=
        if (not(($atts, $elems))) then () else
        
        for $item in ($atts, $elems)
        group by $itemKind := $item/local-name()
        return
            let $itemKindElemName :=
                if ($itemKind eq 'attribute') then 'z:att'
                else 'z:elem'
            let $itemReports :=
                for $attOrElem in $item        
                group by $itemName := app:getNormalizedComponentName($attOrElem, $nsmap)
                order by local-name-from-QName($itemName), 
                         namespace-uri-from-QName($itemName)        
                return
                    let $stypeTrees :=
                        for $itemWithType in $attOrElem
                        group by $typeName := 
                            app:getNormalizedComponentTypeName($itemWithType, $nsmap)
                        return
                            if ($typeName eq QName($app:URI_LTREE, 'z:_LOCAL_'))
                            then
                                let $localStypeTrees :=
                                    for $itemDecl in $itemWithType
                                    let $typeDef := $itemDecl/(xs:simpleType, xs:complexType)
                                    return
                                        f:stypeTree($typeDef, $nsmap, $schemas)
                                return
                                    <z:localTypes count="{count($localStypeTrees)}">{
                                        $localStypeTrees
                                    }</z:localTypes>
                            else if (not(string($typeName))) then ()
                            else f:stypeTreeForTypeName($typeName, $nsmap, $schemas)
                    where $stypeTrees
                    return
                        element {$itemKindElemName} {
                            attribute z:name {$itemName},
                            $stypeTrees
                        }
            return
                element {$itemKindElemName || 's'} {
                    attribute count {count($itemReports)},
                    $itemReports
                }
    return (
        $reportSimpleTypes,
        $reportComplexTypes,
        $reportAttsAndElems
    )
        
(:        
    let $stypeTrees := $components/f:stypeTree(., $nsmap, $schemas)
    return
        $stypeTrees
:)        
};     

(:~
 : Transforms a schema component into a simple type tree. The component can be
 : a type definition, an element declaration or an attribute declaration.
 :
 : @param component a schema component
 : @param nsmap namespace bindings to be used for name normalization
 : @param schemas the schema elements currently considered
 : @return a simple type tree
 :)
declare function f:stypeTree($component as element()?,
                             $nsmap as element(zz:nsMap)?,                             
                             $schemas as element(xs:schema)+)
        as element(z:_stypeTree_)? {
    let $typeDefOrName :=
        typeswitch($component)
        case element(xs:element) return f:efindElemTypeOrTypeName($component, $schemas)
        case element(xs:attribute) return f:afindAttTypeOrTypeName($component, $schemas)
        case element(xs:simpleType) return $component
        case element(xs:complexType) return 
            $component[app:tgetTypeHasSimpleContent(., $schemas)]
        default return ()
    return
        if (empty($typeDefOrName)) then ()
        else if ($typeDefOrName instance of node()) then
            let $treeContent := f:stypeTreeRC($typeDefOrName, $nsmap, $schemas)
            return
                <z:_stypeTree_>{
                    f:stypeTreeNameAtts($typeDefOrName, $nsmap),
                    $treeContent
                }</z:_stypeTree_>
        else if (exists($typeDefOrName)) then
            f:stypeTreeForBuiltinType($typeDefOrName, $nsmap, $schemas)
        else ()
};

(:~
 : Maps a builtin type name to a simple type tree.
 :
 : @param typeName the type name
 : @param nsmap namespace bindings to be used for name normalization
 : @param schemas the schema elements currently considered
 : @return a simple type tree representing the builtin type name
 :)
declare function f:stypeTreeForBuiltinType($typeName as xs:QName,
                                           $nsmap as element(zz:nsMap)?,
                                           $schemas as element(xs:schema)+)
        as element(z:_stypeTree_)? {
    if (namespace-uri-from-QName($typeName) eq $app:URI_XSD) then   
        <z:_stypeTree_>{
            f:stypeTreeBuiltinTypeNameAtts($typeName, $nsmap)
        }</z:_stypeTree_>
    else ()        
};

(:~
 : Maps a type name to a simple type tree.
 :
 : @param typeName the type name
 : @param nsmap namespace bindings to be used for name normalization
 : @param schemas the schema elements currently considered
 : @return a simple type tree representing the type name
 :)
declare function f:stypeTreeForTypeName($typeName as xs:QName?,
                                        $nsmap as element(zz:nsMap)?,
                                        $schemas as element(xs:schema)+)
        as element(z:_stypeTree_)? {
    if (empty($typeName)) then () else
    
    let $typeDef := app:findType($typeName, $schemas)
    return
        if ($typeDef) then 
            f:stypeTree($typeDef, $nsmap, $schemas)
        else if (namespace-uri-from-QName($typeName) eq $app:URI_XSD) then   
            f:stypeTreeForBuiltinType($typeName, $nsmap, $schemas)
        else ()
};

(:~
 : Reports the details of a simple type or the simple content type of a 
 : complex type. The type is either supplied as type definition element, 
 : or identified by its qualified name. If $format is 'xml', an XML 
 : a simple type tree is returned, otherwise a textual type descriptor.
 :
 : @param typeDefOrName type definition element, or qualified type name
 : @param format the format ('xml' or 'text')
 : @param nsmap namespace bindings to be used for name normalization
 : @param schemas the schema elements currently considered
 :)
declare function f:stypeTreeForTypeNameOrDef(
                        $typeDefOrName as item(),
                        $nsmap as element(zz:nsMap)?,
                        $schemas as element(xs:schema)+)
        as element(z:_stypeTree_)? {
        
    if ($typeDefOrName instance of element()) then 
        f:stypeTree($typeDefOrName, $nsmap, $schemas)
    else if ($typeDefOrName instance of xs:QName) then 
        f:stypeTreeForTypeName($typeDefOrName, $nsmap, $schemas)
   else 
      error(QName($app:URI_ERROR, "INVALID_INPUT"), concat( 
         'Unexpected parameter type: $typeDefOrName must be xs:QName, ', 
         'an xs:complexType element or an xs:simpleType element.'))
};

(:~
 : Reports the details of a simple type or the simple content type of a 
 : complex type. The type is supplied as a type definition element.
 : If $format is 'xml', a simple type tree is returned, otherwise a simple
 : type descriptor.
 :
 : @param typeDef the type definition
 : @param format the descriptor format (xml or txt)
 : @param schemas the schema elements currently considered 
 : @return a simple type descriptor
 :)
declare function f:stypeInfo($typeDef as element()?,
                             $format as xs:string?,
                             $nsmap as element(zz:nsMap)?,                             
                             $schemas as element(xs:schema)+)
   as item()? {
   let $stypeTree := f:stypeTree($typeDef, $nsmap, $schemas)
   return
      if ($format eq 'xml') then $stypeTree
      else if ($format eq 'text') then f:stypeTree2StypeDesc($stypeTree, $format)
      else error()
(:      
      else if ($format eq 'features') then f:stypeSteps2Features($stepInfo)      
      else f:stypeSteps2Text($stepInfo, $format, $request)
:)      
};

(:~
 : Transforms a simple type tree into a simple type descriptor.
 :
 : Implementation note: recursive function.
 :
 : @param stypeTree a simple type tree 
 : @return a simple type descriptor representing the contents of the simple type tree
 :)
declare function f:stypeTree2StypeDesc($stypeTree as element(), 
                                       $format as xs:string?) 
        as xs:string {
    let $child1 := $stypeTree/*[1] return
 
    if (empty($child1)) then $stypeTree/(@z:name, @name)[1]/string() else
        
    string-join((

    typeswitch ($child1)
    case element(z:_list_) return
        concat('List(', f:stypeTree2StypeDesc($child1, $format), ')')
    case element(z:_union_) return
        concat('Union(', 
            string-join(
                for $member in $child1/* 
                    return concat('{', f:stypeTree2StypeDesc($member, $format), '}')
            , ', '), ')')
    case element(z:_builtinType_) return
        string($child1/(@z:name, @name)[1])
    case element(z:_empty_) return
        'empty'
    default return 
        error(QName($app:URI_ERROR, "SYSTEM_ERROR"), 
            concat('Unexpected element in stype tree element: ', $child1/local-name()))
    ,
    f:getRestrictionInfo($stypeTree/*[position() gt 1], $format)
    )

   , '')
};

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Write a 'builtinTypeStep' used by a simple type tree.
 :
 : @param typeName the type name
 : @param nsmap namespace bindings to be used for name normalization
 : @param schemas the schema elements currently considered
 : @return a simple type tree representing the builtin type name
 :)
declare function f:stypeTreeBuiltinTypeStep($typeName as xs:QName,
                                            $nsmap as element(zz:nsMap)?,
                                            $schemas as element(xs:schema)+)
        as element(z:_builtinType_)? {
    if (namespace-uri-from-QName($typeName) eq $app:URI_XSD) then   
        <z:_builtinType_>{
            f:stypeTreeBuiltinTypeNameAtts($typeName, $nsmap)
        }</z:_builtinType_>
    else ()        
};

(:~
 : Recursive helper function of `stypeTree`.
 :
 : @param typeDef the type definition
 : @param schemas the schema elements currently considered
 : @return a fraction of a simple type tree
 :)
declare function f:stypeTreeRC($typeDef as element(), 
                               $nsmap as element(zz:nsMap)?,
                               $schemas as element(xs:schema)+)
      as element()+ {
    let $extension := 
        $typeDef/self::xs:complexType/app:tfindTypeSimpleContent(., $schemas)
        /xs:extension
         
    return
        (: case extension: content type is specified by @base :)
        if ($extension) then 
            let $baseName := resolve-QName($extension/@base, $extension)
            return
                if (namespace-uri-from-QName($baseName) eq $app:URI_XSD) then
                    f:stypeTreeBuiltinTypeStep($baseName, $nsmap, $schemas)
                else
                    app:findType($baseName, $schemas)/
                        f:stypeTreeRC(., $nsmap, $schemas)
        else

    let $restriction := 
        ($typeDef/xs:restriction, $typeDef/xs:simpleContent/xs:restriction)
    let $list := $typeDef/xs:list
    let $union := $typeDef/xs:union
    return
        if ($restriction) then
            let $baseInfo :=
                if ($restriction/xs:simpleType) then
                    f:stypeTreeRC($restriction/xs:simpleType, $nsmap, $schemas)
                else if ($restriction/@base) then
                    let $baseName as xs:QName := 
                        resolve-QName($restriction/@base, $restriction)
                    return
                        if (namespace-uri-from-QName($baseName) eq $app:URI_XSD) then
                            f:stypeTreeBuiltinTypeStep($baseName, $nsmap, $schemas)
                        else
                            app:findType($baseName, $schemas)/f:stypeTreeRC(., $nsmap, $schemas)
                else error() (: should never be executed :)

            let $restrictionInfo :=
                <z:_restriction_>{
                    f:stypeInfoNameAtts(app:getComponentName($typeDef), $nsmap),
                    for $r in $restriction/(* except (xs:simpleType, xs:annotation)) 
                    let $elemName := concat('z:_', local-name($r), '_')
                    return 
                        element {$elemName} {$r/@*}
                }</z:_restriction_>
            return
                ($baseInfo, $restrictionInfo)                      

        else if ($list) then
            let $itemInfo :=
                if ($list/@itemType) then
                    let $itemName as xs:QName := resolve-QName($list/@itemType, $list)
                    return
                        if (namespace-uri-from-QName($itemName) eq $app:URI_XSD) then
                            f:stypeTreeBuiltinTypeStep($itemName, $nsmap, $schemas)
                        else
                            app:findType($itemName, $schemas)/
                                f:stypeTreeRC(., $nsmap, $schemas)
                else
                    f:stypeTreeRC($list/xs:simpleType, $nsmap, $schemas)
            return
                <z:_list_>{$itemInfo}</z:_list_>

        else if ($union) then
            let $memberTypes :=
                for $t in $union/@memberTypes/tokenize(normalize-space(.), '\s') 
                return resolve-QName($t, $union)
            let $memberInfos := (
                for $memberType in $memberTypes
                let $nameAtts := f:stypeInfoNameAtts($memberType, $nsmap)
                return
                    <z:_member_>{
                        $nameAtts,
                        if (namespace-uri-from-QName($memberType) eq $app:URI_XSD) then ()
                        else
                            app:findType($memberType, $schemas)/
                                f:stypeTreeRC(., $nsmap, $schemas)
                    }</z:_member_>,
                    
                for $child in $union/xs:simpleType 
                return 
                    <z:_member_>{
                        f:stypeTreeRC($child, $nsmap, $schemas)
                    }</z:_member_>
            )
         return
            <z:_union_>{$memberInfos}</z:_union_>
  
      else 
            <z:_empty_/>
};

(:~
 : Transforms a list of restrictions into a concise text representation.
 :)
declare function f:getRestrictionInfo
                    ($restrictions as element(z:_restriction_)*,
                     $format as xs:string?) as xs:string? {
   if (empty($restrictions)) then () else

   let $length := for $f in $restrictions/z:_length_ return concat('len=', $f/@value)
   let $minLength := max($restrictions/z:_minLength_/@value/xs:int(.))
   let $maxLength := min($restrictions/z:_maxLength_/@value/xs:int(.))

   let $minInclusive := max($restrictions/z:_minInclusive_/@value/f:castToComparable(.))
   let $minExclusive := max($restrictions/z:_minExclusive_/@value/f:castToComparable(.))
   let $maxInclusive := max($restrictions/z:_maxInclusive_/@value/f:castToComparable(.))
   let $maxExclusive := max($restrictions/z:_maxExclusive_/@value/f:castToComparable(.))

   let $totalDigits := $restrictions/z:_totalDigits_/@value/xs:int(.)
   let $totalDigits := if (not(exists($totalDigits))) then () 
                       else concat('totalDigits=', string-join(for $t in $totalDigits return string($t), ','))

   let $fractionDigits := $restrictions/z:_fractionDigits_/@value/xs:int(.)
   let $fractionDigits := if (not(exists($fractionDigits))) then () 
                          else concat('fractionDigits=', string-join(for $t in $fractionDigits return string($t), ','))
   let $minMax :=
      if ((exists($minInclusive) or exists($minExclusive)) and
          (exists($maxInclusive) or exists($maxExclusive)))
      then
         let $lhs := if (exists($minInclusive) and not($minInclusive lt $minExclusive))
                        then concat('[', $minInclusive)
                     else concat('(', $minExclusive)
         let $rhs := if (exists($maxInclusive) and not($maxInclusive gt $maxExclusive))
                        then concat($maxInclusive, ']')
                     else concat($maxExclusive, ')')
         return concat('range=', $lhs, ',', $rhs)
      else if (exists($minInclusive) or exists($minExclusive)) then
         if (exists($minInclusive) and not($minInclusive lt $minExclusive))
            then concat('value>=', $minInclusive)
         else concat('value>', $minExclusive)
      else if (exists($maxInclusive) or exists($maxExclusive)) then
         if (exists($maxInclusive) and not($maxInclusive gt $maxExclusive))
            then concat('value<=', $maxInclusive)
         else concat('value<', $maxExclusive)
      else ()
   let $enums := string-join(
                    for $r in $restrictions[z:_enumeration_][last()]/z:_enumeration_
                    order by lower-case($r/@value)
                    return $r/@value
                 , '|')
   let $enums := if (not($enums)) then () else concat('enum=(', $enums, ')')
   let $patterns :=      
      string-join(
         for $r in $restrictions[z:_pattern_]
         return
            string-join($r/z:_pattern_/@value, ' OR ')
      , ' AND ')
   let $patterns := if (not($patterns)) then () else concat('pattern=#', $patterns, '#')
   let $minMaxLength :=
      if (exists($minLength) and exists($maxLength)) then concat('len=', $minLength, '-', $maxLength)
      else if (exists($minLength)) then concat('minLen=', $minLength)
      else if (exists($maxLength)) then concat('maxLen=', $maxLength)
      else ()
   return
      concat(': ', string-join(($length, $minMaxLength, $minMax, $totalDigits, $fractionDigits, $enums, $patterns), '; '))   
};

(:~
 : Casts a string to a value comparable per < and >.
 :)
declare function f:castToComparable($s as xs:string?)
      as item()? {
    if ($s castable as xs:date) then xs:date($s) 
    else if ($s castable as xs:dateTime) then xs:dateTime($s) 
    else if ($s castable as xs:time) then xs:time($s)      
    else if ($s castable as xs:double) then number($s)
    else $s    
};

(:~
 : Returns attributes identifying the source of a simple type tree. 
 : If $nsmap is set, a @z:name attribute with the normalized name is 
 : returned, otherwise two attributes @name and @namespace conveying 
 : local name and namespace URI, respectively.
 :
 : @param component a schema component
 : @return attribute(s) conveying the component name
 :) 
declare function f:stypeTreeNameAtts($typeDef as element(),
                                     $nsmap as element(zz:nsMap)?)
        as attribute()+ {
    if ($nsmap) then
        let $nname := app:getNormalizedComponentName($typeDef, $nsmap)
        return attribute z:name {$nname}
    else if (not($typeDef/@name)) then (
        attribute name {'z:_LOCAL_'},
        
        let $parent := $typeDef/..
        let $attNames :=
            if ($parent/self::xs:element) then ('elemName', 'elemNamespace')
            else if ($parent/self::xs:attribute) then ('attName', 'attNamespace')
            else error()
        let $qname := app:getComponentName($parent)
        return (
            attribute {$attNames[1]} {local-name-from-QName($qname)},
            attribute {$attNames[2]} {namespace-uri-from-QName($qname)}
        ) 
    ) else
        let $qname := app:getComponentName($typeDef)
        return (
            attribute name {local-name-from-QName($qname)},
            attribute namespace {namespace-uri-from-QName($qname)}
        )            
};        

(:~
 : Returns attributes identifying the source of a simple type tree. 
 : If $nsmap is set, a @z:name attribute with the normalized name is 
 : returned, otherwise two attributes @name and @namespace conveying 
 : local name and namespace URI, respectively.
 :
 : @param component a schema component
 : @return attribute(s) conveying the component name
 :) 
declare function f:stypeTreeBuiltinTypeNameAtts($typeName as xs:QName,
                                                $nsmap as element(zz:nsMap)?)
        as attribute()+ {
    if ($nsmap) then
        let $nname := app:normalizeQName($typeName, $nsmap)
        return attribute z:name {$nname}
    else (
        attribute name {local-name-from-QName($typeName)},
        attribute namespace {namespace-uri-from-QName($typeName)}            
    )        
};        

(:~
 : Returns attributes conveying a component name. If $nsmap is set, a
 : @z:name attribute with the normalized name is returned, otherwise
 : two attributes @name and @namespace conveying local name and
 : namespace URI, respectively.
 :
 : @param component a schema component
 : @return attribute(s) conveying the component name
 :) 
declare function f:stypeInfoNameAtts($qname as xs:QName,
                                     $nsmap as element(zz:nsMap)?)
        as attribute()+ {
    if ($nsmap) then
        let $nname := app:normalizeQName($qname, $nsmap)
        return attribute z:name {$nname}
    else (
        attribute name {local-name-from-QName($qname)},
        attribute namespace {namespace-uri-from-QName($qname)}
    )        
};        


(:

(: 
------------------------------
public / simpleTypeInfo
------------------------------ :)

(: 
------------------------------
private / simpleTypeInfo
------------------------------ :)

s(:~
 : Transforms a step representation of a type into a feature representation.
 :)
declare function m:stypeSteps2Features($steps as element())
        as element() {
    m:stypeSteps2FeaturesRC($steps)        
};

declare function m:stypeSteps2FeaturesRC($n as node())
        as node()* {
    typeswitch($n)
    case element() return
        if (local-name($n) = ('list', 'union')) then
            element {node-name($n)} {
                for $a in $n/@* return m:stypeSteps2FeaturesRC($a),        
                if ($n/sbType) then m:stypeSteps2Features_restriction($n/*)
                else
                    for $c in $n/node() return m:stypeSteps2FeaturesRC($c)
            }
        else if ($n/sbType) then m:stypeSteps2Features_restriction($n/*)            
        else
            element {node-name($n)} {
                for $a in $n/@* return m:stypeSteps2FeaturesRC($a),
                for $c in $n/node() return m:stypeSteps2FeaturesRC($c)                
            }
    default return $n            
};

declare function m:stypeSteps2Features_restriction($steps as element()+)
        as element() {
    let $sbtype := $steps/self::sbType/@name
    let $enums := $steps[xs:enumeration][last()]/xs:enumeration/@value/string()
    let $pattern := $steps[xs:pattern][last()]/xs:pattern/@value/string()
    let $minInclusive := $steps[xs:minInclusive][last()]/xs:minInclusive/@value/string()    
    let $minExclusive := $steps[xs:minExclusive][last()]/xs:minExclusive/@value/string()    
    let $maxInclusive := $steps[xs:maxInclusive][last()]/xs:maxInclusive/@value/string()    
    let $maxExclusive := $steps[xs:maxExclusive][last()]/xs:maxExclusive/@value/string()
    let $minLength := $steps[xs:minLength][last()]/xs:minLength/@value/string()    
    let $maxLength := $steps[xs:maxLength][last()]/xs:maxLength/@value/string()    
    let $length := $steps[xs:length][last()]/xs:length/@value/string()    
    let $totalDigits := $steps[xs:totalDigits][last()]/xs:totalDigits/@value/string()    
    let $fractionDigits := $steps[xs:fractionDigits][last()]/xs:fractionDigits/@value/string()    
    return
        <type base="{$sbtype}">{
            if (empty($enums)) then () else
                <enum>{
                    for $e in $enums order by lower-case($e) return <value>{$e}</value>
                }</enum>,
            if (empty($pattern)) then () else
                <pattern value="{$pattern[1]}"/>,
            if (empty($minInclusive)) then () else
                <minInclusive value="{$minInclusive[1]}"/>,
            if (empty($minExclusive)) then () else
                <minExclusive value="{$minExclusive[1]}"/>,
            if (empty($maxInclusive)) then () else
                <maxInclusive value="{$maxInclusive[1]}"/>,
            if (empty($maxExclusive)) then () else
                <maxExclusive value="{$maxExclusive[1]}"/>,
            if (empty($minLength)) then () else
                <minLength value="{$minLength[1]}"/>,
            if (empty($maxLength)) then () else
                <maxLength value="{$maxLength[1]}"/>,
            if (empty($length)) then () else
                <length value="{$length[1]}"/>,
            if (empty($totalDigits)) then () else
                <totalDigits value="{$totalDigits[1]}"/>,
            if (empty($fractionDigits)) then () else
                <fractionDigits value="{$fractionDigits[1]}"/>,
            ()
        }</type>        
};

(:~
 : Checks if one simple type is fully included by another type so that every
 : instance matching the included type also matches the including type.
 :
 : @param includedType the type to be checked for being included
 : @param includingType the type to be checked for being including
 : @returns true if the included type is indeed included by the including type
 :) 
declare function m:isSimpleTypeIncluded($includedType as element(stypeInfo),
                                        $includingType as element(stypeInfo))
        as xs:boolean {
    if ($includedType/empty and $includingType/empty) then true()
    else if ($includingType/empty) then false()
    else if ($includedType/empty) then false() else
    
    let $typeSystem :=
        <types>
            <type name="string">
                <type name="normalizedString">
                    <type name="token">
                        <type name="language"/>
                        <type name="NMTOKEN"/>
                        <type name="name">
                            <type name="NCName">
                                <type name="ID"/>
                                <type name="IDREF"/>
                                <type name="ENTITY"/>
                            </type>
                        </type>
                    </type>
                </type>
            </type>
            <type name="dateTime">
                <type name="dateTimeStampe"/>
            </type>
            <type name="date"/>
            <type name="time"/>
            <type name="duration">
                <type name="yearMonthDuration"/>
                <type name="dayTimeDuration"/>
            </type>
            <type name="integer">
                <type name="decimal"/>
                <type name="nonPositiveInteger">
                    <type name="negativeInteger"/>
                </type>
                <type name="long">
                    <type name="int">
                        <type name="short">
                            <type name="byte"/>
                        </type>
                    </type>
                </type>
                <type name="nonNegativeInteger">
                    <type name="unsignedLong">
                        <type name="unsignedInt">
                            <type name="unsignedShort">
                                <type name="unsignedByte"/>
                            </type>
                        </type>
                    </type>
                </type>
                <type name="positiveInteger"/>
            </type>
            <type>
                <subType>normalizedString</subType>                
            </type>
            <type name="float"/>
            <type name="double"/>
            <type name="gYearMonth"/>
            <type name="gYear"/>
            <type name="gMonthDay"/>
            <type name="gMonth"/>
            <type name="gDay"/>
            <type name="base64Binary"/>            
            <type name="hexBinary"/>
            <type name="anyURI"/>
            <type name="QName"/>
            <type name="NOTATION"/>            
        </types>
        
    let $baseType1 := ($includedType/sbType/@name, $includedType/@name)[1]
    let $baseType2 := ($includingType/sbType/@name, $includingType/@name)[1]
    let $restrictions1 := $includedType//restriction[not(xs:enumeration)]/*
    let $restrictions2 := $includingType//restriction[not(xs:enumeration)]/*
    (: enumerations are handled separately :)
    
    let $baseTypeRel :=
        if ($baseType1 eq $baseType2) then 'match'  
        else 
            let $typeNode1 := $typeSystem//type[@name eq $baseType1]
            let $typeNode2 := $typeSystem//type[@name eq $baseType2]            
            return
                if (empty($typeNode1)) then
                    error(QName((), 'UNEXPECTED_TYPE'), concat('Unknown base type: ', $baseType1))
                else if (empty($typeNode2)) then
                    error(QName((), 'UNEXPECTED_TYPE'), concat('Unknown base type: ', $baseType2))                   
                else
                    if ($typeNode2//* intersect $typeNode1) then 'broadened'
                    else if ($baseType1 eq 'ID') then
                        if ($baseType2 eq 'NCName') then 'match'
                        else if ($baseType2 eq 'NMTOKEN') then 'broadened'
                        else 'nomatch'
                    else 'nomatch'
    let $baseTypeResult := not($baseTypeRel eq 'nomatch')                
    let $facetResult1 :=    
        if (empty($restrictions2)) then true()
        else (: t r a c e( :)
            every $r in $restrictions1 satisfies (
                if ($r/self::xs:minLength) then not(max($restrictions2/self::xs:minLength/@value/xs:integer(.)) gt xs:integer($r/@value))               
                else if ($r/self::xs:maxLength) then not(min($restrictions2/self::xs:maxLength/@value/xs:integer(.)) lt xs:integer($r/@value))             
                    else if ($r/self::xs:length) then empty($restrictions2/self::xs:length/@value[xs:integer(.) ne xs:integer($r/@value)])
                
                else if ($r/self::xs:pattern) then empty($restrictions2/self::xs:pattern[@value ne $r/@value])                
              
                else if ($r/self::xs:enumeration) then () (: enumerations are handled separately, see below :)
                (: else if ($r/self::xs:enumeration) then empty($restrictions2[self::xs:enumeration]) or $restrictions2/self::xs:enumeration/@value = $r/@value :)
                
                else if ($r/self::xs:minInclusive) then not(max($restrictions2/self::xs:minInclusive/@value/number(.)) gt $r/@value/number(.))                
                else if ($r/self::xs:maxInclusive) then not(min($restrictions2/self::xs:maxInclusive/@value/number(.)) lt $r/@value/number(.))                
                else if ($r/self::xs:minExclusive) then not(max($restrictions2/self::xs:minExclusive/@value/number(.)) gt $r/@value/number(.))                
                else if ($r/self::xs:maxExclusive) then not(min($restrictions2/self::xs:maxExclusive/@value/number(.)) lt $r/@value/number(.))
                
                else ()
            ) (:  , concat('MARK#1; R1=', string-join($restrictions1/concat(local-name(.), '=', @value), ', '),
                             '; R2=', string-join($restrictions2/concat(local-name(.), '=', @value), ' , '))) :)
    let $facetResult2 :=    
        if (empty($restrictions1) and $restrictions2) then false()
        else
            every $r in $restrictions2 satisfies (
                if ($r/self::xs:minLength) then max($restrictions1/self::xs:minLength/@value/xs:integer(.)) ge $r/@value/xs:integer(.)               
                else if ($r/self::xs:maxLength) then max($restrictions1/self::xs:maxLength/@value/xs:integer(.)) le $r/@value/xs:integer(.)             
                else if ($r/self::xs:length) then $restrictions1/self::xs:length/@value/xs:integer(.) = $r/@value/xs:integer(.)
                
                else if ($r/self::xs:pattern) then $restrictions1/self::xs:pattern/@value eq $r/@value                
              
                else if ($r/self::xs:enumeration) then () (: enumerations are handled separately, see below :)              
                (: else if ($r/self::xs:enumeration) then $restrictions1/self::xs:enumeration/@value = $r/@value :)
                    
                else if ($r/self::xs:minInclusive) then max($restrictions1/self::xs:minInclusive/@value/number(.)) ge $r/@value/number(.)                
                else if ($r/self::xs:maxInclusive) then min($restrictions1/self::xs:maxInclusive/@value/number(.)) le $r/@value/number(.)                
                else if ($r/self::xs:minExclusive) then max($restrictions1/self::xs:minExclusive/@value/number(.)) ge $r/@value/number(.)                
                else if ($r/self::xs:maxExclusive) then min($restrictions1/self::xs:maxExclusive/@value/number(.)) le $r/@value/number(.)
                
                else ()
            ) (:  , concat('MARK#1; R1=', string-join($restrictions1/concat(local-name(.), '=', @value), ', '),
                             '; R2=', string-join($restrictions2/concat(local-name(.), '=', @value), ' , '))) :)
                             
    let $facetResultEnum :=
        every $restrictionEnum in $includingType//restriction[xs:enumeration]
        satisfies
            $includedType//restriction[xs:enumeration]
                [every $v in xs:enumeration/@value satisfies $v = $restrictionEnum/xs:enumeration/@value]
    return
        if (not($facetResult1) or not($facetResult2) or not($facetResultEnum)) then false()
        else if ($baseType2 eq 'string') then true()
        else $baseTypeResult
};        

declare function m:pretty($n as node()) as node()? {
   typeswitch($n)
   case document-node() return
      document {for $c in $n/node() return m:pretty($c)}
   case element(xs:annotation) return ()
   case element() return
      element {node-name($n)} {
         for $a in $n/@* return m:pretty($a),
         for $c in $n/node() return m:pretty($c)
      }
   case text() return
      if ($n/../* and not(matches($n, '\S'))) then () else $n
   default return $n
};

:)