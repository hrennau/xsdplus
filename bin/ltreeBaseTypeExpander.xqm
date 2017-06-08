(:
 : -------------------------------------------------------------------------
 :
 : ltreeBaseTypeExpander.xqm - functions expanding the base type of location tree components
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.xsdplus.org/ns/xquery-functions";
 
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_nameFilter.xqm";

declare namespace z="http://www.xsdplus.org/ns/structure";

(: *** 
       e x p a n d    b a s e T y p e 
   *** :)

(:~
 : Expands type component descriptors, adding base type contents.
 : 
 : @param typeComps type component descriptors whose base types
 :    and whose contained derived types have not yet been expanded
 : @return expanded type components
 :)
declare function f:expandTypeComps($typeComps as element()*)
        as element()* {
        
    (: expand base types of type component descriptors :)        
    let $expandedTypesG:=
        let $typeDict :=
            map:merge(
                for $typeComp in $typeComps
                let $name := $typeComp/z:typeContent/@z:type/string()                                       
                return map:entry($name, $typeComp)
            )
        let $accum :=
            map{'expanded': (), 
                'typeDict': $typeDict, 
                'expandedTypeDict': map{}}
        let $foldExpandBaseType := f:foldExpandBaseType#2
        let $accumFinal := fold-left($typeComps, $accum, $foldExpandBaseType)   
        return $accumFinal?expanded
                
    (: expand type hierarchies of contained local types :)   
    let $expandedTypes :=
        let $expandedWithLocalDerivedTypes :=
            $expandedTypesG[f:containsDerivedLocalTypes(.)]
        let $expandedWithoutLocalDerivedTypes := 
            $expandedTypesG except $expandedWithLocalDerivedTypes
        return
            (: case 1: expansion not necessary :)
            if (empty($expandedWithLocalDerivedTypes)) then $expandedTypesG else

            (: case 2: expansion necessary :)
            let $typeDict := map:merge(
                for $type in $expandedTypesG[@z:name]
                return map:entry($type/@z:name/string(), $type)
            )                
            let $expandedTypeDict :=  map:merge(
                for $type in $expandedWithoutLocalDerivedTypes[@z:name]
                return map:entry($type/@z:name/string(), $type)
            )
            let $accum :=
                map{'expanded': (), 
                    'typeDict': $typeDict, 
                    'expandedTypeDict': $expandedTypeDict}
            let $foldExpandLocalBaseTypes := f:foldExpandLocalBaseTypes#2
            let $accumFinal := 
                fold-left($expandedWithLocalDerivedTypes, 
                          $accum, 
                          $foldExpandLocalBaseTypes)   
            for $type in ($expandedWithoutLocalDerivedTypes, $accumFinal?expanded)
            order by $type/@z:name, $type/@z:loc
            return $type
    return
        $expandedTypes
};

(:~
 : Expands group component descriptors, add base type contents of derived
 : local types.
 :
 : @param groups group component descriptors not yet expanded
 : @param expandedTypes type component descriptors already expanded
 : @return expanded group component descriptors
 :)
declare function f:expandGroupContainedLocalTypes(
                        $groups as element()*, 
                        $expandedTypes as element()*)
        as element()* {
    let $groupsWithLocalDerivedTypes := $groups[f:containsDerivedLocalTypes(.)]
    let $groupsWithoutLocalDerivedTypes := $groups except $groupsWithLocalDerivedTypes
    return
        (: case1: expansion not necessary :)
        if (empty($groupsWithLocalDerivedTypes)) then $groups else

        (: case2: expansion necessary :)
        let $typeDict := map:merge(
            for $type in $expandedTypes[@z:name]
            return map:entry($type/@z:name/string(), $type)
        )                
        let $expandedGroupDict := map:merge(
            for $group in $groupsWithoutLocalDerivedTypes[@z:name]
            return map:entry($group/@z:name/string(), $group)
        )
        let $accum :=
            map{'expanded': (), 
                'typeDict': $typeDict, 
                'expandedGroupDict': $expandedGroupDict}
        let $foldExpandLocalBaseTypesInGroups := f:foldExpandLocalBaseTypesInGroups#2
        let $accumFinal := 
            fold-left($groupsWithLocalDerivedTypes, 
                      $accum, 
                      $foldExpandLocalBaseTypesInGroups)
                              
        for $group in ($groupsWithoutLocalDerivedTypes, $accumFinal?expanded)
        order by $group/@z:name
        return $group
};

(:~
 : Returns the type descriptor resulting from expanding a given type
 : descriptor by adding representations of all base types.
 :
 : @param type a type descriptor
 : @param baseType the type descriptor of the base type
 : @param expandedTypeDict a map associating type names with expanded types
 : @param typeDict a map associating all type names with their unexpanded 
 :     type descriptors
 : @return the expanded type descriptor, optionally followed by further
 :     expanded type descriptors created during recursive expansion 
 :)
declare function f:expandBaseType($type as element(z:type),
                                  $expandedTypeDict as map(xs:string, element(z:type)),
                                  $typeDict as map(xs:string, element(z:type)))
        as element(z:type)+ {
    let $typeName := $type/@z:name return
    
    if ($typeName ! map:contains($expandedTypeDict, .)) then
        map:get($expandedTypeDict, $typeName)
    else if (not(f:needsTypeDescriptorBaseTypeExpansion($type))) then 
        $type
    else
        let $baseTypeName := $type/z:typeContent/@z:baseType
        return
            if (map:contains($expandedTypeDict, $baseTypeName)) then
                f:addExpandedBaseType($type, map:get($expandedTypeDict, $baseTypeName))
            else        
                let $baseType := map:get($typeDict, $baseTypeName)
                return
                    if (not($baseType)) then error() 
                    else f:expandBaseType($type, $baseType, $expandedTypeDict, $typeDict)
};

(:~
 : Returns the type descriptor resulting from expanding a given type
 : descriptor by adding representations of all base types.
 :
 : @param type a type descriptor
 : @param baseType the type descriptor of the base type
 : @param expandedTypeDict a map associating type names with expanded type descriptors
 : @param typeDict a map associating all type names with their unexpanded 
 :     type descriptors
 : @return the expanded type descriptor, optionally followed by further
 :     expanded type descriptors created during recursive expansion 
 :)
declare function f:expandBaseType($type as element(z:type),
                                  $baseType as element(z:type),
                                  $expandedTypeDict as map(xs:string, element(z:type)),
                                  $typeDict as map(xs:string, element(z:type)))
        as element(z:type)+ {  
        
    (: the base type representation to be used; if the base type itself needs
       expansion, retrieve expanded form from `expandedTypeDict`, if possible;
       otherwise create expansion by recursive call :)
    let $expandedBaseTypeEtc :=
        if (not(f:needsTypeDescriptorBaseTypeExpansion($baseType))) then
            (: base type needs no expansion :)
            $baseType
        else        
            let $baseTypeName := $baseType/z:typeContent/@z:type
            let $tryAlreadyExpanded := map:get($expandedTypeDict, $baseTypeName)
            return
                (: base type already expanded :)
                if ($tryAlreadyExpanded) then $tryAlreadyExpanded
                else
                    (: expand base type now :)
                    let $baseTypeBaseName := $baseType/z:typeContent/@z:baseType
                    let $baseTypeBase := map:get($typeDict, $baseTypeBaseName)
                    return
                        if (not($baseTypeBase)) then error() 
                        else f:expandBaseType($baseType, $baseTypeBase, $expandedTypeDict, $typeDict)
    let $expandedDuringRecursiveExpansion := 
        if ($expandedBaseTypeEtc[1] is $baseType) then ()
        else if (map:contains($expandedTypeDict, $expandedBaseTypeEtc[1]/@z:name)) then ()
        else $expandedBaseTypeEtc[@z:name]
    let $expandedBaseType := $expandedBaseTypeEtc[1]
    return(
        f:addExpandedBaseType($type, $expandedBaseType), $expandedDuringRecursiveExpansion
    )
};        

(:~
 : Returns the type descriptor resulting from expanding a given type
 : descriptor by a base type which is already expanded.
 :
 : @param type a type descriptor
 : @param expandedBaseType the expanded type descriptor of the base type
 : @return the expanded type descriptor 
 :)
declare function f:addExpandedBaseType($type as element(z:type),
                                       $expandedBaseType as element(z:type))
        as element(z:type) {  
        
    let $derivationKind := $type/z:typeContent/@z:derivationKind                            

    let $typeContent := $type/z:typeContent
    let $baseTypeContent := $expandedBaseType/z:typeContent    
    
    let $type_atts := $typeContent/z:_attributes_
    let $type_stypeTree := $typeContent/z:_stypeTree_
    let $type_anno := $typeContent/z:_annotation_    
    let $type_content := $typeContent/* except 
                                ($type_atts, $type_stypeTree, $type_anno)

    let $baseType_atts := $baseTypeContent/z:_attributes_
    let $baseType_stypeTree := $baseTypeContent/z:_stypeTree_
    let $baseType_anno := $baseTypeContent/z:_annotation_    
    let $baseType_content := $baseTypeContent/* except 
                                ($baseType_atts, $baseType_stypeTree, $baseType_anno)    
    
    let $newAtts :=
        if ($derivationKind eq 'extension') then
            if (empty($type_atts)) then $baseType_atts
            else if (empty($baseType_atts)) then $type_atts
            else
                let $type_attNames := $type_atts/*/@z:name
                return
                    <z:_attributes_>{
                        $type_atts/*,
                        $baseType_atts/*[not(@z:name = $type_attNames)]
                    }</z:_attributes_>
        else
            if (empty($type_atts)) then $baseType_atts
            else
                let $type_attNames := $type_atts/*/@z:name
                return
                    <z:_attributes_>{
                        $type_atts/*,
                        $baseType_atts/*[not(@z:name = $type_attNames)]
                    }</z:_attributes_>
        
    let $newContents :=
        if ($derivationKind eq 'extension') then 
            ($baseType_content, $type_content)
        else 
            $type_content
            
    let $expandedType :=
        element {node-name($type)} {
            $type/@*,
            <z:typeContent>{
                $typeContent/@*,
                $type_stypeTree,
                $type_anno,
                $baseType_anno,
                $newAtts,
                $newContents
            }</z:typeContent>    
        }
    return 
        $expandedType
};        


(:~
 : Expands a type by a representation of its base types.
 :
 : The accummulator is a map with three entries:
 : <ul>
 :   <li>typeDict: a map associating type names with 
 :      not expanded type definitions</li>
 :   <li>expandedTypeDict: a map associating type names with
 :      expanded type definitions</li>
 :   <li>expanded: a list of expanded type definitions 
 : </ul>
 :)
declare function f:foldExpandBaseType($accum as map(*),
                                      $item as element(z:type))
        as map(*) {
    let $typeDict := $accum?typeDict        
    let $expandedTypeDict := $accum?expandedTypeDict
    let $expanded := $accum?expanded
    let $expansion := f:expandBaseType($item, $expandedTypeDict, $typeDict)
    
    let $newExpandedTypeDict :=
        map:merge((
            $expandedTypeDict,
(:            
            if ($expansion[1] is $item) then () 
            else
:)            
                for $type in $expansion
                let $name := $type/@z:name/string()
                where $name
                return map:entry($name, $type)
            ))   
    return
        map{
            'typeDict': $typeDict,        
            'expanded': ($expanded, $expansion[1]),
            'expandedTypeDict': $newExpandedTypeDict
        }
};

(: *** 
       e x p a n d    l o c a l    b a s e T y p e s 
   *** :)

(:~
 : Expands a location tree fragment (representing a type or a group) by
 : expanding the base tree of contained local types.
 :)
declare function f:expandLocalBaseTypes($item as element(), 
                                        $expandedTypeDict as map(xs:string, element(z:type)), 
                                        $typeDict as map(xs:string, element(z:type)))
        as element()+ {
    if (empty($item/*//*[@z:type eq 'z:_LOCAL_'][f:needsTypedItemBaseTypeExpansion(.)])) then
        $item
    else    
        f:expandLocalBaseTypesRC($item, $expandedTypeDict, $typeDict)
};        

(:~
 : Recursive helper function of `expandLocalBaseTypes`.
 :)
declare function f:expandLocalBaseTypesRC($n as node(), 
                                          $expandedTypeDict as map(xs:string, element(z:type)), 
                                          $typeDict as map(xs:string, element(z:type)))
        as node()* {
    typeswitch($n)
    case element() return    
        if ($n/@z:type eq 'z:_LOCAL_' and f:needsTypedItemBaseTypeExpansion($n)) then
            let $baseTypeName := $n/@z:baseType
            let $baseTypeCached := map:get($expandedTypeDict, $baseTypeName)
            let $expandedBaseType :=
                if ($baseTypeCached) then $baseTypeCached
                else 
                    let $baseType := map:get($typeDict, $baseTypeName)
                    return
                        if (not($baseType)) then error()
                        else if (not(f:containsDerivedLocalTypes($baseType))) then $baseType
                        else f:expandLocalBaseTypes($baseType, $expandedTypeDict, $typeDict)
            let $type :=
                <z:type>{<z:typeContent>{$n/@*, $n/node()}</z:typeContent>}</z:type>      
            let $expandedType :=                  
                f:expandBaseType($type, $expandedBaseType, $expandedTypeDict, $typeDict)
            return                      
                element {node-name($n)} {
                    $n/@*,
                    $expandedType/z:typeContent/node()
                }        
        else        
            element {node-name($n)} {
                for $a in $n/@* return f:expandLocalBaseTypesRC($a, $expandedTypeDict, $typeDict),
                for $c in $n/node() return f:expandLocalBaseTypesRC($c, $expandedTypeDict, $typeDict)
            }
            
    default return $n        
};        

declare function f:foldExpandLocalBaseTypes($accum as map(*),
                                            $item as element(z:type))
        as map(*) {
    let $typeDict := $accum?typeDict        
    let $expandedTypeDict := $accum?expandedTypeDict
    let $expanded := $accum?expanded
    let $expansion := f:expandLocalBaseTypes($item, $expandedTypeDict, $typeDict)
    
    let $newExpandedTypeDict :=
        map:merge((
            $expandedTypeDict,
                for $type in $expansion
                let $name := $type/@z:name/string()
                where $name
                return map:entry($name, $type)
            ))   
    return
        map{
            'typeDict': $typeDict,        
            'expanded': ($expanded, $expansion[1]),
            'expandedTypeDict': $newExpandedTypeDict
        }
};

declare function f:foldExpandLocalBaseTypesInGroups($accum as map(*),
                                                    $item as element(z:group))
        as map(*) {
    let $typeDict := $accum?typeDict        
    let $expandedGroupDict := $accum?expandedGroupDict
    let $expanded := $accum?expanded
    let $expansion := f:expandLocalBaseTypes($item, $typeDict, map{})
    
    let $newExpandedGroupDict :=
        map:merge((
            $expandedGroupDict,
                for $type in $expansion
                let $name := $type/@z:name/string()
                where $name
                return map:entry($name, $type)
            ))   
    return
        map{
            'typeDict': $typeDict,        
            'expanded': ($expanded, $expansion[1]),
            'expandedGroupDict': $newExpandedGroupDict
        }
};

(: *** 
       b a s e T y p e    e x p a n s i o n    c h e c k s 
   *** :)

(:~
 : Returns true if a type descriptor needs expansion which adds the 
 : representations of all base types.
 :
 : @param type a type descriptor
 : @return true if the type descriptor needs expansions, false otherwise
 :)
declare function f:needsTypeDescriptorBaseTypeExpansion($type as element(z:type))
        as xs:boolean {
    let $typeContent := $type/z:typeContent
    return 
        $typeContent/not(
            empty(@z:baseType) or
            starts-with(@z:typeVariant, 's') or
            (@z:builtinBaseType eq @z:baseType)
        )
};        

declare function f:needsTypedItemBaseTypeExpansion($item as element())
        as xs:boolean {
    $item/not(
        empty(@z:baseType) or
        starts-with(@z:typeVariant, 's') or
        (@z:builtinBaseType eq @z:baseType)
    )
};        

(:~
 : Returns true if a location tree component (type or group descriptor)
 : contains derived local types.
 : 
 : @param lcomp a location tree component, either a type descriptor or
 :     a group descriptor
 : @return true if expansion is required
 :)
declare function f:containsDerivedLocalTypes($lcomp as element())
        as xs:boolean {
    exists($lcomp/*//*[@z:type eq 'z:_LOCAL_']
                      [f:needsTypedItemBaseTypeExpansion(.)])        
};
    
