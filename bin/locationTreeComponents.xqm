(:
 : -------------------------------------------------------------------------
 :
 : locationTreeComponents.xqm - operations and functions creating location tree components
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="lcomps" type="node()" func="lcompsOp">
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="gnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="true"/>        
         <param name="expandBaseType" type="xs:boolean?" default="true"/>
         <param name="expandGroups" type="xs:boolean?" default="true"/>         
         <param name="stypeTrees" type="xs:boolean?" default="true"/>         
         <param name="annos" type="xs:boolean?" default="true"/>         
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
    "baseTypeFinder.xqm",
    "componentDependencies.xqm",
    "componentFinder.xqm",
    "componentLocator.xqm",
    "constants.xqm",
    "occUtilities.xqm",
    "ltreeBaseTypeExpander.xqm",
    "ltreeGroupExpander.xqm",    
    "simpleTypeInfo.xqm",
    "targetNamespaceTools.xqm",
    "typeInspector.xqm",
    "utilities.xqm";
    
declare namespace zz="http://www.xsdr.org/ns/structure";
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace c="http://www.xsdplus.org/ns/xquery-functions";

declare variable $f:DEBUG external := 'NO_EXPANSIONXXX';

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `lcomps`.
 :
 : @param request the operation request
 : @return a report containing location tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:lcompsOp($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $enames := tt:getParams($request, 'enames')
    let $tnames := tt:getParams($request, 'tnames')    
    let $gnames := tt:getParams($request, 'gnames')  
    let $global := tt:getParams($request, 'global')
    let $withStypeTrees := tt:getParams($request, 'stypeTrees')
    let $withAnnos := tt:getParams($request, 'annos')    
    let $expandBaseType := tt:getParams($request, 'expandBaseType')
    let $expandGroups := tt:getParams($request, 'expandGroups')
    let $nsmap := app:getTnsPrefixMap($schemas)
    
    let $options :=
        <options withStypeTrees="{$withStypeTrees}"
                 withAnnos="{$withAnnos}"/>
    return
        f:lcomps($enames, $tnames, $gnames, $global, $options, 
            $expandBaseType, $expandGroups, $nsmap, $schemas)
};     

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns the location tree components of which a set of schema components 
 : is composed. The schema components are either element declarations, or type 
 : definitions, or group definitions. They are selected by a name filter.
 :
 : @param enames a name filter selecting element declarations
 : @param tnames a name filter selecting type declarations
 : @param gnames a name filter selecting group declarations
 : @param global if true, element names are matched only against top-level
 :     element declarations 
 : @param expandBaseType if true, base type references are expanded, so that
 :     full type content is represented
 : @param expandGroups if true, group components are expanded by resolving
 :     group references
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return for each schema component all location tree components of
 :     which they are composed
 :)
declare function f:lcomps($enames as element(nameFilter)*,
                          $tnames as element(nameFilter)*,
                          $gnames as element(nameFilter)*,
                          $global as xs:boolean?,
                          $options as element(options),
                          $expandBaseType as xs:boolean?,
                          $expandGroups as xs:boolean?,
                          $nsmap as element(),
                          $schemas as element(xs:schema)+)
        as element() {
        
    (: schema components to be described :)
    let $comps :=
        if (empty(($enames, $tnames, $gnames))) then $schemas/xs:element
        else (
            if (not($enames)) then () else (
                if ($global) then $schemas/xs:element
                else $schemas/descendant::xs:element
                )[tt:matchesNameFilter(@name, $enames)],
            if (not($tnames)) then () else 
                $schemas/(descendant::xs:simpleType, descendant::xs:complexType)
                [tt:matchesNameFilter(@name, $tnames)],
            if (not($gnames)) then () else 
                $schemas/descendant::xs:group
                [tt:matchesNameFilter(@name, $gnames)]
        )  
        
    let $compKindLabel :=
        switch($comps[1]/local-name())
        case 'element' return 'elem'
        case 'simpleType' return 'type'
        case 'complexType' return 'type'
        case 'group' return 'group'
        default return ()
        
    let $report :=
        for $comp in $comps
        let $name := trace($comp/@name , 'COMPONENT NAME: ')
        let $loc := app:getComponentLocator($comp, $nsmap, $schemas)
        let $namespace := $comp/ancestor::xs:schema/@targetNamespace  
        let $normalizedName := tt:normalizeQName(QName($namespace, $name), $nsmap)
        let $deps := app:deps($comp, $schemas)
        
        let $compNameIfTypeComp := 
            $comp[self::xs:simpleType, self::xs:complexType]/$normalizedName
        let $compNameIfGroupComp := $comp[self::xs:group]/$normalizedName
            
        (: if comp is an element: set @z:type, @z:typeLoc 
           ============================================== :)         
        (: if elem with @type attribute: construct @z:type :)
        let $elemType :=
            $comp/self::xs:element/@type/resolve-QName(., ..) 
            ! tt:normalizeQName(., $nsmap) ! attribute z:type {.}
            
        (: construct @z:typeLoc :)
        let $elemTypeLoc :=
            if (not($comp/self::xs:element())) then () else
            let $typeLoc :=
                if ($comp/@type) then
                    let $type := app:rfindType($comp/@type, $schemas)       
                    return
                        if (not($type instance of node())) then ()
                        else $type/app:getComponentLocator(., $nsmap, $schemas)            
                else
                    $comp/xs:complexType/app:getComponentLocator(., $nsmap, $schemas)
            return attribute z:typeLoc {$typeLoc}                    
        
        (: type components 
           ===============:)
        (: 0. anonymous type 
                 if comp is element with a local type, the local type
                 must be considered) :)
        let $anomTypeComp := 
            $comp/self::xs:element/(xs:simpleType, xs:complexType)
            /f:lcomp_anomType(., $options, $nsmap, $schemas)
            
        (: 1. explicit types :)
        let $typeNames := distinct-values(($deps?types, $compNameIfTypeComp))
        let $typeComps := (
            $anomTypeComp,
            for $typeName in $typeNames
            order by local-name-from-QName($typeName), prefix-from-QName($typeName)
            return
                f:lcomp_type($typeName, $options, map{}, $nsmap, $schemas)
        )
        (: 2. expand base types :)        
        let $expandedTypes := 
            if (not($expandBaseType)) then $typeComps else
                f:expandTypeComps($typeComps)
                
        (: group components 
           ================:)
        (: 1. explicit groups :)           
        let $groupNames := distinct-values(($deps?groups, $compNameIfGroupComp))
        let $groupComps :=
            for $groupName in $groupNames
            order by local-name-from-QName($groupName), prefix-from-QName($groupName)            
            return f:lcomp_group($groupName, $options, $nsmap, $schemas)

        (: 2. expand group references :)
        let $expandedGroups := 
            if (not($expandGroups)) then $groupComps else
                app:expandGroupComps($groupComps)
                
        (: 3. expand base types of contained local types :)   
        let $fullyExpandedGroups := 
            app:expandGroupContainedLocalTypes($expandedGroups, $expandedTypes)
        return
        
            element {$compKindLabel} {
                attribute z:name {$normalizedName},     
                attribute z:loc {$loc},
                $elemType,
                $elemTypeLoc,
                <z:types count="{count($typeNames)}">{$expandedTypes}</z:types>,
                <z:groups count="{count($groupNames)}">{$fullyExpandedGroups}</z:groups>
            }  
    return
        app:addNSBs(
            <z:lcomps countXsds="{count($schemas)}" 
                          xmlns:xs="http://www.w3.org/2001/XMLSchema">{
                $report
            }</z:lcomps>, $nsmap)
};     

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(: *** 
       c o n s t r u c t i o n    o f    t y p e    d e s c r i p t o r s 
   *** :)

(:~
 : Returns a location tree component representing a named type definition.
 :
 : @param typeName the type name
 : @param options an element representing processing options; 
 :     not evaluated by this function
 : @expandedTypeDict a dictionary of location type components,
 :     enabling lookup by type name 
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a 'type' element representing the location tree component
 :)
declare function f:lcomp_type($typeName as xs:QName, 
                              $options as element(options),
                              $expandedTypeDict as map(xs:string, element(z:type)),
                              $nsmap as element(),
                              $schemas as element(xs:schema)+)
        as element(z:type) {
    let $tname := local-name-from-QName($typeName)
    let $tns := namespace-uri-from-QName($typeName)
    let $normalizedName := app:normalizeQName(QName($tns, $tname), $nsmap)
    let $type := app:findType($typeName, $schemas)    
    let $typeContent := f:lcomp_typeContent($type, $options, $nsmap, $schemas)
    return
        <z:type z:name="{$normalizedName}">{$typeContent}</z:type>
};        

(:~
 : Returns a location tree component representing an anonymous type definition.
 :
 : @param typeName the type name
 : @param options an element representing processing options; 
 :     not evaluated by this function
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a 'z:type' element representing the location tree component
 :)
declare function f:lcomp_anomType($type as element(), 
                                  $options as element(options),
                                  $nsmap as element(),
                                  $schemas as element(xs:schema)+)
        as element(z:type) {
    let $loc := app:getComponentLocator($type, $nsmap, $schemas)
    let $typeContent := f:lcomp_typeContent($type, $options, $nsmap, $schemas)
    return
        <z:type z:loc="{$loc}">{$typeContent}</z:type>
};        

(:~
 : Returns the core part ('z:typeContent' element) of a location tree 
 : component representing a type definition.
 :
 : The root element of the component is a z:typeContent element. When
 : constructing the location tree, its attributes and child elements
 : are transferred to an element representing an element declaration.
 :
 : Note. The complete location tree component consists of a
 : 'z:typeContent' element representing the information content of
 : the type definition, wrapped in a 'z:type' element announcing type
 : name (if the type is global) or type location (otherwise).
 : 
 : @param typeName the type name
 : @param options an element representing processing options; 
 :     not evaluated by this function
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a 'z:typeContent' element representing the information content 
 :     of the type definition
 :)
declare function f:lcomp_typeContent($type as element(), 
                                     $options as element(options),
                                     $nsmap as element(),
                                     $schemas as element(xs:schema)+)
        as element(z:typeContent) {
    let $withStypeTrees := $options/@withStypeTrees/xs:boolean(.)
    let $typePropertyItems := f:lcomp_typePropertyItems($type, $withStypeTrees, $nsmap, $schemas)
    let $typePropertyAtts := $typePropertyItems[self::attribute()]
    let $typePropertyElems := $typePropertyItems[self::element()]    
    let $atts := $type[self::xs:complexType]/f:lcomp_type_atts(., $options, $nsmap, $schemas)
    let $elems := $type[self::xs:complexType]/f:lcomp_type_elems(., $options, $nsmap, $schemas)
    let $annos := $type/xs:annotation/f:lcomp_type_anno(., $options, $nsmap, $schemas)
    let $typeContent :=
        <z:typeContent>{
            $typePropertyAtts, 
            $typePropertyElems,
            $annos,
            $atts, 
            $elems
        }</z:typeContent>
    return
        $typeContent    
};        

(:~
 : Returns location tree elements representing the attribute declarations 
 : contained by a complex type definition. The attribute descriptors 
 : are represented by elements which are wrapped in a 'z:_attributes_' 
 : element.
 :
 : @param type the type definition
 : @param options an element representing processing options; 
 :     not evaluated by this function
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a z:_attributes_ element containing attribute locations,
 :     or the empty sequence if the type does not have attributes
 :) 
declare function f:lcomp_type_atts(
                        $type as element(xs:complexType),
                        $options as element(options),
                        $nsmap as element(),
                        $schemas as element(xs:schema)+)
        as element(z:_attributes_)? {    
    let $atts :=  f:tfindTypeAtts($type, $schemas)
    let $wildCard := $atts/self::xs:anyAttribute
    let $wildCardDescriptor :=
        $wildCard/f:lcomp_type_anyAtt(., $options, $nsmap, $schemas)
    return if (empty($atts)) then () else
    
    <z:_attributes_>{
        let $withStypeTrees := $options/@withStypeTrees/xs:boolean(.)
        let $withStypeTrees := ()   (: 20170605, hjr :)
        for $att in $atts[not(self::xs:anyAttribute)]
        let $typeOrTypeName := app:afindAttTypeOrTypeName($att, $schemas)
        let $name := f:getComponentName($att)
        let $loc := f:getComponentLocator($att, $nsmap, $schemas)
        let $nname := app:normalizeQName($name, $nsmap)
        let $occAtt := app:getAttributeOccAtt($att)
        let $typePropertyItems := 
            f:lcomp_typePropertyItems($typeOrTypeName, $withStypeTrees, $nsmap, $schemas)
        let $typePropertyAtts := $typePropertyItems[self::attribute()]
        let $typePropertyElems := $typePropertyItems[self::element()]    
        let $annoElem := $att/xs:annotation/f:lcomp_type_anno(., $options, $nsmap, $schemas)     
        return
            element {$nname} {
                attribute z:name {$nname},
                $occAtt,
                $typePropertyAtts,
                attribute z:loc {$loc},                
                $att/@*,
                $typePropertyElems,
                $annoElem
            },
            
        $wildCardDescriptor
    }</z:_attributes_>
};        

(:~
 : Returns a location tree element representing an attribute wildcard.
 :
 : @param anyAtt an attribute wildcard schema component
 : @param options an element representing processing options; 
 :     not evaluated by this function
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 :) 
declare function f:lcomp_type_anyAtt(
                        $anyAtt as element(xs:anyAttribute),
                        $options as element(options),
                        $nsmap as element(),
                        $schemas as element(xs:schema)+)
        as element(z:_anyAttribute_)? {
        <z:_anyAttribute_>{
            $anyAtt/@namespace/attribute z:namespace {.},
            $anyAtt/@processContents/attribute z:processContents {.},
            $anyAtt/@*,            
            for $c in $anyAtt/node() return f:lcomp_type_elemsRC($c, $options, $nsmap, $schemas)            
        }</z:_anyAttribute_>
};

(:~
 : Returns location tree elements representing the element declarations and 
 : compositors contained by a complex type definition.
 : 
 : Compositors are represented by z:_sequence_, z:_choice_ and z:_all_ 
 : elements. Element descriptors are represented by elements with a node 
 : name equal to the normalized name of the element declaration.
 :
 : @param type the type definition
 : @param options an element representing processing options; 
 :     not evaluated by this function
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a z:_attributes_ element describing the attributes, or
 :     the empty sequence if the type does not have attributes
 :) 
declare function f:lcomp_type_elems($type as element(),
                                    $options as element(options),
                                    $nsmap as element(),
                                    $schemas as element(xs:schema)+)
        as node()* {
    $type/*/f:lcomp_type_elemsRC(., $options, $nsmap, $schemas)        
};        

(:~
 : Recursive helper function of `lcomp_type_elems`. Maps the items
 : of an element content model to location descriptor items.
 :
 : @param n the node to be processed recursively
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return elements representing the contents of a complex type
 :     definition
 :)
declare function f:lcomp_type_elemsRC($n as node(),
                                      $options as element(options),
                                      $nsmap as element(),
                                      $schemas as element(xs:schema)+)
        as node()* {
    typeswitch($n)  

    case element(xs:attribute) return ()    
    case element(xs:anyAttribute) return ()    
    case element(xs:attributeGroup) return ()    
    case element(xs:simpleContent) return ()    
    case comment() return ()    
    case processing-instruction() return ()
    
    case element(xs:annotation) return 
        f:lcomp_type_anno($n, $options, $nsmap, $schemas)
        
    case element(xs:any) return
        <z:_any_>{
            for $a in $n/@* return f:lcomp_type_elemsRC($a, $options, $nsmap, $schemas),
            for $c in $n/node() return f:lcomp_type_elemsRC($c, $options, $nsmap, $schemas)            
        }</z:_any_>
        
    case element(xs:sequence) | element(xs:choice) | element(xs:all) return
        let $elemName := 'z:_' || local-name($n) || '_'
        let $occAtt := app:getOccAtt($n)        
        let $atts :=    
            for $a in $n/@* return f:lcomp_type_elemsRC($a, $options, $nsmap, $schemas) 
        let $content :=
            for $c in $n/node() return f:lcomp_type_elemsRC($c, $options, $nsmap, $schemas)
        return            
            element {$elemName} {
                $occAtt,
                $atts,
                $content
            }
            
    case element(xs:group) return 
        let $occAtt := app:getOccAtt($n) 
        return
            <z:_group_>{
                $occAtt,
                for $a in $n/@* return f:lcomp_type_elemsRC($a, $options, $nsmap, $schemas)
            }</z:_group_>
        
    case element(xs:complexContent) return (
        for $c in $n/(xs:restriction, xs:extension)/* return 
            f:lcomp_type_elemsRC($c, $options, $nsmap, $schemas)
    )
    
    (: an element declaration :)
    case element(xs:element) return
        let $withStypeTrees := $options/@withStypeTrees/xs:boolean(.)
        let $withStypeTrees := () (: 20170605, hjr :)
        let $name := app:getNormalizedComponentName($n, $nsmap)
        let $typeName := $n/@type/resolve-QName(., ..)
        let $anomType := $n/(xs:simpleType, xs:complexType)
        let $anno := $n/xs:annotation
        
        (: type anonymous or builtin: preserve all type property atts; 
           otherwise, just keep only @z:type :)
        let $typePropertyItems :=           
            if ($anomType) then 
                $anomType/f:lcomp_typePropertyItems(., $withStypeTrees, $nsmap, $schemas)
            else if (namespace-uri-from-QName($typeName) eq $c:URI_XSD) then 
                f:lcomp_typePropertyItems($typeName, $withStypeTrees, $nsmap, $schemas)
            else f:getTypeAtt($n, $nsmap)
        let $typePropertyAtts := $typePropertyItems[self::attribute()]
        let $typePropertyElems := $typePropertyItems[self::element()]
        
        (: info atts :)
        let $infoAtts := 
            let $nameAtt := attribute z:name {$name}
            let $occAtt := app:getOccAtt($n)  
            let $locAtt := attribute z:loc {app:getComponentLocator($n, $nsmap, $schemas)}
            let $xsAtts := for $a in $n/@* return f:lcomp_type_elemsRC($a, $options, $nsmap, $schemas)
            return (
                $nameAtt,
                $occAtt,
                $typePropertyAtts,
                $locAtt,            
                $xsAtts
            )
        
        (: contents of anonymous type :)
        let $typeContent := $anomType/f:lcomp_typeContent(., $options, $nsmap, $schemas)/node()
        
        (: annotation :)
        let $annoElem := $anno/f:lcomp_type_anno(., $options, $nsmap, $schemas)
        
        (: compose content :)
        let $content_atts := 
            let $raw := ($infoAtts, ($typeContent, $annoElem)[self::attribute()])
            return 
                for $a in $raw group by $name := node-name($a) return $a[1]
        let $content_elems := ($annoElem, $typeContent)[self::element()]
        
        (: construct element descriptor :)
        return         
            element {$name} {
                $content_atts,
                $content_elems
            }

    case attribute(name) return
        let $name := app:getNormalizedComponentName($n/.., $nsmap)
        return ($n, attribute z:name {$name})

    case attribute(ref) return
        let $name := app:getNormalizedComponentName($n/.., $nsmap)
        return attribute ref {$name}

    default return $n        
};        

(:~
 : Returns a location tree component representing schema annotations.
 :
 : @param anno a 'xs:annotation' element
 : @param options an element representing processing options 
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a z:_annotation_ element containing attribute locations,
 :     or the empty sequence if the type does not have attributes
 :) 
declare function f:lcomp_type_anno(
                        $anno as element(xs:annotation),
                        $options as element(options),
                        $nsmap as element(),
                        $schemas as element(xs:schema)+)
        as element(z:_annotation_)? {
    if (not($options/@withAnnos/xs:boolean(.))) then () else        
    f:lcomp_type_annoRC($anno, $options, $nsmap, $schemas)
};        

(:~
 : Recursive helper function of `f:lcomp_type_anno`.
 :
 : @param anno a 'xs:annotation' element
 : @param options an element representing processing options; 
 :     not evaluated by this function
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a z:_annotation_ element containing attribute locations,
 :     or the empty sequence if the type does not have attributes
 :) 
declare function f:lcomp_type_annoRC(
                        $n as node(),
                        $options as element(options),
                        $nsmap as element(),
                        $schemas as element(xs:schema)+)
        as node()? {    
    typeswitch($n)
    case element(xs:annotation) return 
        <z:_annotation_>{
            $n/@*,
            for $c in $n/node() return f:lcomp_type_annoRC($c, $options, $nsmap, $schemas)
        }</z:_annotation_>    

    case element(xs:documentation) return 
        <z:_documentation_>{
            $n/@*,
            for $c in $n/node() return f:lcomp_type_annoRC($c, $options, $nsmap, $schemas)
        }</z:_documentation_>    
    case element(xs:appinfo) return 
        <z:_appinfo_>{
            $n/@*,
            for $c in $n/node() return f:lcomp_type_annoRC($c, $options, $nsmap, $schemas)
        }</z:_appinfo_>    
    case element() return 
        element {node-name($n)}{
            for $a in $n/node() return f:lcomp_type_annoRC($a, $options, $nsmap, $schemas),
            for $c in $n/node() return f:lcomp_type_annoRC($c, $options, $nsmap, $schemas)
        }
    default return $n
};        


(:~
 : Returns nodes used by a location tree in order to describe the properties 
 : of a type. The nodes are attributes and, optionally, an 'z:_stypeTree_'
 : element describing the simple contents of the type
 :
 : The attributes are: 
 :      z:type, z:typeVariant, z:typeLoc?, z:isEmpty?,
 :      z:builtinBaseType, z:baseType (only if type anonymous),
 :      z:contentType, z:contentTypeVariant
 :
 : @param typeOrTypeName a type definition or, in the case of a built-in type,
 :     the type name
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return attributes describing the type
 :)
declare function f:lcomp_typePropertyItems(
                         $typeOrTypeName as item()?,
                         $withStypeTrees as xs:boolean?,
                         $nsmap as element(),
                         $schemas as element(xs:schema)+)
        as node()* {
    if (empty($typeOrTypeName)) then (
        attribute z:noType {'true'}
    ) else
    
    let $type :=        
        if ($typeOrTypeName instance of xs:anyAtomicType) then ()
        else $typeOrTypeName        
    let $typeName := 
        if (not($type)) then $typeOrTypeName
        else app:getComponentName($type)
    let $nname := app:normalizeQName($typeName, $nsmap)
    let $loc := $type/app:getComponentLocator($type, $nsmap, $schemas)
    let $typeVariant := 
        if (not($type)) then 'sb' else app:tgetTypeVariant($type, $schemas)        
        
    let $builtinBaseTypeName := 
        $type/f:tfindTypeBuiltinBaseTypeName(., $schemas) ! app:normalizeQName(., $nsmap)
    let $baseTypeName := 
        $type/app:tfindTypeBaseTypeName(., $schemas) ! app:normalizeQName(., $nsmap)
        [not(. eq $app:ANY_TYPE)]
    let $contentTypeAndVariant :=
        if (not($typeVariant eq 'cs')) then () else

        let $contentTypeOrTypeName := app:tfindTypeContentTypeOrTypeName($type, $schemas)
        return
            if ($contentTypeOrTypeName instance of node()) then (
                (app:getNormalizedComponentName($contentTypeOrTypeName, $nsmap), '_ANON_')[1],
                app:tgetTypeVariant($contentTypeOrTypeName, $schemas)
            ) else (
                app:normalizeQName($contentTypeOrTypeName, $nsmap),
                'sb'
            )
    let $contentType := $contentTypeAndVariant[1]                    
    let $contentTypeVariant := $contentTypeAndVariant[2]
    
    let $stypeTree := app:stypeTreeForTypeNameOrDef($typeOrTypeName, $nsmap, $schemas)
    let $typeDesc := if ($typeVariant eq 'sb') then string($typeName)  
                     else $stypeTree/app:stypeTree2StypeDesc(., ())
    let $contentTypeDesc :=
        if ($typeVariant ne 'cs') then ()
        else if ($contentTypeVariant eq 'sb') then string($contentType)
        else $typeDesc
        
    let $derivationKind := $type/f:tgetTypeDerivationKind(.)            
    return (
        attribute z:type {$nname},       
        attribute z:typeVariant {$typeVariant}, 
        if (not($typeDesc)) then () else
            attribute z:typeDesc {$typeDesc},
        if ($typeVariant ne 'ce') then () else attribute z:isEmpty {"true"},
        if (empty($baseTypeName)) then () else
            attribute z:baseType {$baseTypeName},        
        if (empty($derivationKind)) then () else
            attribute z:derivationKind {$derivationKind},        
        if (empty($builtinBaseTypeName)) then () else
            attribute z:builtinBaseType {$builtinBaseTypeName},
        if (empty($contentType)) then () else (
            attribute z:contentType {$contentType},
            attribute z:contentTypeVariant {$contentTypeVariant},
            if (not($contentTypeDesc)) then () else
                attribute z:contentTypeDesc {$contentTypeDesc}            
        ),
        $type/attribute z:typeLoc {$loc},

        if (not($withStypeTrees) or 'sb' = ($typeVariant, $contentTypeVariant)) then ()
        else $stypeTree
    )
};

(:~
 : Returns an attribute reporting the type of am element.
 :
 : @param elem an element declaration
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @return a @z:type attribute providing the normalized type name
 :)
declare function f:getTypeAtt($elem as element(), $nsmap as element(z:nsMap))
        as attribute(z:type)? {
    let $att :=        
        $elem/self::xs:element/@type/resolve-QName(., ..) 
        ! tt:normalizeQName(., $nsmap) ! attribute z:type {.}
    return
        if ($att) then $att 
        else $elem/(xs:complexType, xs:simpleType)/attribute z:type {z:_LOCAL_}
};

(: *** 
       c o n s t r u c t i o n    o f    g r o u p    d e s c r i p t o r s 
   *** :)

(:~
 : Returns a location tree component representing a group definition.
 :
 : @param groupName the group name
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return the location tree component element
 :)
declare function f:lcomp_group($groupName as xs:QName, 
                               $options as element(options),
                               $nsmap as element(),
                               $schemas as element(xs:schema)+)
        as element(z:group) {
    let $name := local-name-from-QName($groupName)
    let $namespace := namespace-uri-from-QName($groupName)
    let $normalizedName := app:normalizeQName(QName($namespace, $name), $nsmap)
    let $group := app:findGroup($groupName, $schemas)
    
    let $groupContent :=
        let $groupPropertyAtts := f:lcomp_groupPropertyAtts($group, $nsmap, $schemas)
        let $elems := $group/f:lcomp_type_elems(., $options, $nsmap, $schemas)
        return
            <z:_groupContent_>{$groupPropertyAtts, $elems}</z:_groupContent_>    
    return
        <z:group z:name="{$normalizedName}">{
            $groupContent
        }</z:group>        
};        

(:~
 : Returns a sequence of attributes used by a location tree in order to 
 : describe the properties of a group.
 :
 : @param group the group definition
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return attributes describing the group
 :)
declare function f:lcomp_groupPropertyAtts($group as element(xs:group),
                                           $nsmap as element(),
                                           $schemas as element(xs:schema)+)
        as attribute()* {
    let $groupName := app:getComponentName($group)        
    let $nname := app:normalizeQName($groupName, $nsmap)
    let $loc := app:getComponentLocator($group, $nsmap, $schemas)
    return (
        attribute z:groupName {$nname},       
        attribute z:loc {$loc}
    )
};
