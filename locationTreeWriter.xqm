(:
 : -------------------------------------------------------------------------
 :
 : locationTreeWriter.xqm - operation which writes location trees
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="ltree" type="node()" func="ltreeOp">
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="gnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="true"/>         
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
         <param name="stypeTrees" type="xs:boolean?" default="true"/>         
         <param name="annos" type="xs:boolean?" default="true"/>   
         <param name="propertyFilter" type="nameFilter?"/>
         <param name="sgroupStyle" type="xs:string?" default="ignore" fct_values="expand, compact, ignore"/>
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
    "constants.xqm",
    "locationTreeComponents.xqm",
    "locationTreeNormalizer.xqm",
    "occUtilities.xqm",
    "substitutionGroups.xqm";
    
declare namespace c="http://www.xsdplus.org/ns/xquery-functions";    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.xsdr.org/ns/structure";
declare namespace ns0="http://www.xsdr.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `ltree`. The operation writes location trees.
 :
 : @param request the operation request
 : @return a report containing base tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:ltreeOp($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $enames := tt:getParam($request, 'enames')
    let $tnames := tt:getParam($request, 'tnames')    
    let $gnames := tt:getParam($request, 'gnames')  
    let $global := tt:getParam($request, 'global')  
    let $withStypeTrees := tt:getParams($request, 'stypeTrees')    
    let $withAnnos := tt:getParams($request, 'annos')    
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $groupNorm := trace(tt:getParam($request, 'groupNormalization') , 'GROUP NORMALIZATION: ')
    let $propertyFilter := tt:getParam($request, 'propertyFilter')
    let $sgroupStyle := tt:getParam($request, 'sgroupStyle')
    
    let $options :=
        <options withStypeTrees="{$withStypeTrees}"
                 sgroupStyle="{$sgroupStyle}"
                 withAnnos="{$withAnnos}"/>
    
    let $ltree := f:ltree($enames, $tnames, $gnames, $global, $options, 
                          $groupNorm, $nsmap, $schemas)
    let $ltree :=
        if (not($propertyFilter)) then $ltree else 
            let $DUMMY := trace('', 'Filter ltree properties ... ')
            return
                f:filterLtreeProperties($ltree, $propertyFilter)
    return
        $ltree
};     

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Writes a location tree.
 :
 : @param enames a name filter selecting element declarations
 : @param tnames a name filter selecting type definitions
 : @param gnames a name filter selecting group definitions
 : @param global if true, only top-level element declarations are considered
 : @param options they control the processing behaviour;
 : @param groupNormalization controls the extent of group normalization
 : @param nsmap normalized bindings of namespace URIs to prefixes 
 : @param schemas the schema elements currently considered
 : @return a report containing one or several location trees
 :) 
declare function f:ltree($enames as element(nameFilter)*,
                         $tnames as element(nameFilter)*,    
                         $gnames as element(nameFilter)*,  
                         $global as xs:boolean?,
                         $options as element(options),
                         $groupNormalization as xs:integer?,
                         $nsmap as element(z:nsMap),
                         $schemas as element(xs:schema)+)
        as element(z:locationTrees) {                         
    
    let $groupNormalization := ($groupNormalization, 4)[1]
    
    (: select schema components to be translated into location trees :)
    let $comps :=
        f:lcomps($enames, $tnames, $gnames, $global, $options, 
            true(), true(), $nsmap, $schemas)
        
    let $ltrees :=
        for $comp in $comps/*
        let $ltree := 
            let $DUMMY := trace('', 'COMPONENTS WRITTEN ...')
            let $sgroups := f:sgroupMembers($schemas, (), (), (), ())
            let $raw := f:lcomps2Ltree($comp, $sgroups, $options, $nsmap)
            let $DUMMY := trace('', 'RAW TREE CONSTRUCTED ...')            
            let $fine := f:finalizeLtree($raw, $groupNormalization)
            let $DUMMY := trace('', 'TREE TIDIED UP ...')            
            return $fine
        let $root := $ltree/*[not(self::z:nsMap)][1]
        order by $root/local-name(.), $root/namespace-uri(.)
        return
            $ltree
    let $report :=
        <z:locationTrees count="{count($ltrees)}">{
            $ltrees
        }</z:locationTrees>
    let $DUMMY := trace((), ' - GOING to add NSBs')
    return
        app:addNSBs($report, $nsmap)
};     

(:~
 : Transforms a collection of location tree components into a location tree.
 :
 : @param comp an element containing the location tree components of a schema 
 :     component (e.g. the elements, types and groups required for an element)
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @return a location tree
 :)
declare function f:lcomps2Ltree($comp as element(),
                                $sgroups as map(xs:QName, xs:QName+),
                                $options as element(options),
                                $nsmap as element(z:nsMap))
        as element() {
    let $compKindLabel := local-name($comp) 
        (: elem | type | group :)
    let $compName := tt:resolveNormalizedQNamePrefixed($comp/@z:name, $nsmap)
        (: elem, type or group name :)
        
    let $lname := local-name-from-QName($compName)
    let $ns := namespace-uri-from-QName($compName)
    let $atts := $comp/@*    
   
    let $elemDict :=
        map:merge(
            for $elem in $comp/z:elems/z:elem
            return map:entry($elem/@z:name, $elem)
        )
    let $typeDict := 
        map:merge(
            for $type in $comp/z:types/z:type
            return map:entry($type/(@z:name, @z:loc)[1], $type)
        )
    let $groupDict :=
        map:merge(
            for $group in $comp/z:groups/z:group
            return map:entry($group/@z:name, $group)
        )
        
    let $ltree := f:lcomps2LtreeRC(
        $comp, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, ())
    return
        <z:locationTree compKind="{$compKindLabel}">{
            $atts,
            $nsmap,
            $ltree
        }</z:locationTree>
};

(:
 : ============================================================================
 :
 :     p r i v a t e     f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Recursive helper fnction of `lcomps2Ltree`.
 : 
 : @param n a node encountered in a component
 : @param typeDict a dictionary of type components
 : @param groupDict a dictionary of group component
 : @param nsmap
 : @param visited a sequence of element declarations, group
 :     components ('z:group') and type components ('z:type')
 :     visited by outer calls
 : @return a fragment of the location tree
 :)
declare function f:lcomps2LtreeRC($n as node(), 
                                  $elemDict as map(*),
                                  $typeDict as map(*),
                                  $groupDict as map(*),
                                  $sgroups as map(xs:QName, xs:QName+),
                                  $options as element(options),
                                  $nsmap as element(z:nsMap),
                                  $visited as element()*)
        as node()* {
    let $DUMMY :=
        if (count($visited) ne count($visited/.)) then ()
            (: trace((),
            concat('count(visited)=', count($visited), ' ; count(visited/*)=', count($visited/*))) :)
        else if (count($visited) lt 120) then () else 
            let $callPath := string-join(
                $visited ! @z:name/concat(., parent::z:group/'(group)', parent::z:type/'(type)')
                , '/')
            return                
                trace($callPath, concat('LARGE_COUNT_VISITED (', count($visited), ': '))
    return
    
    typeswitch($n)
    
    (: element represents an ELEMENT component to be translated into a location tree :)
    case $comp as element(elem) return
        let $compName := tt:resolveNormalizedQNamePrefixed($comp/@z:name, $nsmap)    
        let $type :=
            if ($comp/@z:type) then map:get($typeDict, $comp/@z:type)
            else if ($comp/@z:typeLoc) then $typeDict?*[@z:loc eq $comp/@z:typeLoc]
            else error()
        (: content (metadata attributes and children representing atts and elems) :)
        let $typeContent := (
            $type/z:typeContent/@*,        
            for $c in $type/z:typeContent/* return f:lcomps2LtreeRC(
                $c, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $type)
        )        
        return
            element {$compName} {
                attribute z:name {$compName},
                $typeContent
            }
            
    (: element represents a TYPE component to be translated into a location tree :)            
    case $comp as element(type) return
        let $compName := tt:resolveNormalizedQNamePrefixed($comp/@z:name, $nsmap)    
        let $type := map:get($typeDict, $comp/@z:name)
        (:content :)
        let $typeContent := (
            $type/z:typeContent/@*,
            for $c in $type/z:typeContent/* return f:lcomps2LtreeRC(
                $c, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $type)
        )        
        return
            <typedElement>{
                $typeContent
            }</typedElement>
    
    (: element represents a GROUP component to be translated into a location tree :)    
    case $comp as element(group) return
        let $compName := tt:resolveNormalizedQNamePrefixed($comp/@z:name, $nsmap)  
        let $group := map:get($groupDict, $comp/@z:name)
        let $content := f:lcomps2LtreeRC(
            $group, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, ())                
        return
            <z:group name="{$compName}">{$content}</z:group>

    (: element represents a compositor :)
    case element(z:_sequence_) | element(z:_choice_) | element(z:_all_) return
        let $content :=
            for $i in $n/(@*, node()) return f:lcomps2LtreeRC(
                $i, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $visited)
        let $contentAtts := $content/self::attribute()
        return
            element {node-name($n)} {
                ($contentAtts, $content except $contentAtts)
            }    

    (: element represents a group reference :)
    (: note - group references within type contents have not yet been resolved :)
    case element(z:_group_) return    
        let $groupDef := map:get($groupDict, $n/@ref)  (: TO.DO - normalize name ? :)
        return if (empty($groupDef)) then error() else
            
        let $groupContent := f:lcomps2LtreeRC(
            $groupDef, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $visited)        
        return
            if (empty($groupContent)) then error() else
            f:updateOccAtt($groupContent, $n/@z:occ)

    (: element represents a group definition;    
       returns the recursively expanded 'z:_groupContent_' child :)
    case element(z:group) return 
        if ($visited intersect $n) then
            let $_ := f:_debug_reportRecursion(
                concat('GROUP-RECURSION=', $n/@z:name, ': '), $visited) return
            
            <z:_groupContent_>{
                $n/z:_groupContent_/@*,
                attribute z:groupRecursion {$n/@z:name}
            }</z:_groupContent_>
            else  
                f:lcomps2LtreeRC($n/z:_groupContent_, 
                    $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, ($visited, $n))
        
    (: group contents are recursively expanded :)
    case element(z:_groupContent_) return
        if ($n/@z:groupRecursion) then $n else
        
        let $content := (
            for $a in $n/@* return f:lcomps2LtreeRC(
                $a, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $visited),
            for $i in $n/node() return f:lcomps2LtreeRC(
                $i, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $visited)
        )                
        return
            element {node-name($n)} {
                $content
            }

    (: element represents a referenced element declaration :)
    case element(z:elem) return
        if ($visited intersect $n) then
            let $_ := f:_debug_reportRecursion(
                concat('ELEM-RECURSION=', $n/@z:name, ': '), $visited) 
            return
                let $compName := tt:resolveNormalizedQNamePrefixed($n/@z:name, $nsmap)
                return
                    element {$compName} {
                        attribute z:elemRecursion {$n/@z:name}
                    }
        else      
            for $c in $n/* return f:lcomps2LtreeRC(
                $c, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, ($visited, $n))


    (: element represents a referenced type definition :)
    case element(z:type) return
        if ($visited intersect $n) then
            let $_ := f:_debug_reportRecursion(
                concat('TYPE-RECURSION=', $n/@z:name, ': '), $visited) return
        
            attribute z:typeRecursion {$n/@z:name}
        else            
            for $c in $n/* return f:lcomps2LtreeRC(
                $c, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, ($visited, $n))
      
    (: 'z:typeContent' is replaced by its attributes and recursively
       expanded contents :)  
    case element(z:typeContent) return (
        $n/@*,
        for $c in $n/node() return f:lcomps2LtreeRC(
            $c, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $visited)
    )
    
    (: element represents an element location :)
    case element() return
        (: case 1: element use with @z:ref :)
        if ($n/@z:ref) then
            let $ref := $n/@z:ref/string()
            let $qname := $n/@z:ref/tt:resolveNormalizedQNamePrefixed(., $nsmap) 
            let $elemD := $elemDict($ref)
            let $sgroupMemberNames :=
                if ($options/@sgroupStyle eq 'ignore') then ()
                else map:keys($sgroups)[. eq $qname] ! $sgroups(.)
            let $targets := (
                $elemD,
                for $qn in $sgroupMemberNames
                let $nqname := string(tt:normalizeQName($qn, $nsmap))
                return $elemDict($nqname)
            )
            return if (empty($targets)) then error(QName((), 'SYSTEM_ERROR'),
                concat('No targets for elem: ', $ref)) else
            let $sgmTargets := $targets except $elemD 
            let $targetTrees := (
                f:lcomps2LtreeRC(
                    $elemD, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $visited)
                ,                
                if ($options/@sgroupStyle eq 'expand') then                
                    for $t in $sgmTargets return f:lcomps2LtreeRC(
                        $t, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, $visited)
                else if ($options/@sgroupStyle eq 'compact') then
                    for $t in $sgmTargets
                    let $typeVariant := $t/*/@z:type ! $typeDict(.)/*/@z:typeVariant
                    return
                        if ($typeVariant/matches(., '^(s|cs)')) then
                            f:lcomps2LtreeRC(
                                $t, $elemDict, $typeDict, $groupDict, $sgroups, 
                                $options, $nsmap, $visited)
                        else
                            element {$t/*/node-name(.)} {
                                $t/*/@*, 
                                attribute z:collapsed {true()},
                                $t/*/node()
                            }
                else if  ($options/@sgroupStyle eq 'ignore') then ()
                else error()
            )                    
            return
                if (exists($sgroupMemberNames)) then
                    <z:_sgroup_>{
                        attribute z:sgHead {$n/@z:name},                
                        $n/@z:occ,
                        $targetTrees
                    }</z:_sgroup_>
                else
                    let $occ := $n/@z:occ
                    return
                        if (not($occ)) then $targetTrees else
                            element {node-name($targetTrees)} {
                                $targetTrees/@z:name,
                                $occ,
                                $targetTrees/(@* except @z:name),
                                $targetTrees/node()
                            }
        (: case 2: element use with @z:name :)                            
        else
            let $content :=
                (: case 2a: element with global type reference :)
                if ($n/@z:type ne 'z:_LOCAL_') then                    
                    let $supplementaryContent := $n/*   (: z:_annotation_, z:_stypeTree_ :)            
                    let $type := $typeDict($n/@z:type)
                    return
                        if (not($type)) then ($n/@*, $supplementaryContent)
                        else if (not($type/z:typeContent)) then ($n/@*, $supplementaryContent)
                        else
                            let $content := 
                                f:lcomps2LtreeRC($type, $elemDict, $typeDict, $groupDict, 
                                    $sgroups, $options, $nsmap, ($visited, $n))
                            let $contentAtts := $content[self::attribute()]
                            let $contentElems := $content except $contentAtts
                        
                            let $contentAttNames := $contentAtts/name()     
                            let $ownAtts := $n/@*[not(name() = $contentAttNames)]
                            let $allAtts := ($ownAtts, $contentAtts)                        
                            let $mainAtts := $allAtts[self::attribute(z:name), self::attribute(z:occ)]
                            let $locAtt := $allAtts[self::attribute(z:loc)]
                            let $otherZAtts := $allAtts[namespace-uri(.) eq $c:URI_LTREE] 
                                               except ($mainAtts, $locAtt)
                            let $nonZAtts := $allAtts[not(namespace-uri(.) eq $c:URI_LTREE)]
                            return (
                                $mainAtts, $otherZAtts, $locAtt, $nonZAtts,
                                $supplementaryContent,                            
                                $contentElems
                            )
                (: case 2b: element with local type :)                            
                else (
                    $n/@*,                        
                    for $c in $n/node() return f:lcomps2LtreeRC(
                        $c, $elemDict, $typeDict, $groupDict, $sgroups, $options, $nsmap, 
                        ($visited, $n))
                        (: 20170525, hjr: "$visited" -> "($visited, $n)" :)
                )                        
        return
            element {node-name($n)} {
                $content
            }    
    default return $n
};

(:~
 : For debugging purposes - logs recursion paths.
 :)
declare function f:_debug_reportRecursion($label as xs:string, $visited as element()*)
        as empty-sequence() {      
    let $steps := $visited[empty((self::z:group, self::z:type))]/@z:name      
    
    let $elemPath := string-join($steps, '/')
    let $compPath := string-join(
        $visited ! @z:name/concat(., parent::z:group/'(group)', parent::z:type/'(type)')
        , '/')
    
    let $file := $app:_DEBUGFILE_RECURSION_PATHS
    return (
        file:append($file, concat($label, ' [#ELEM-STEPS=', count($steps), '] ', $elemPath, '&#xA;')),
        file:append($file, concat($label, ' [#COMP-STEPS=', count($visited), '] ', $compPath, '&#xA;'))        
    )
};

(:~
 : Finalizes a location tree by removing unnecessary items. z:_groupContent_
 : elements are unwrapped (unless they have a recursion flag) and
 : group normalization is launched.
 :
 : @param ltree the location tree and pre-finalization state
 : @param groupNorm controls the degree of group normalization
 : @return the finalized location tree
 :)
declare function f:finalizeLtree($ltree as element(), $groupNorm as xs:integer?)
        as element() {
        
    let $tree := f:finalizeLtree_groupContentRC($ltree)
    let $tree := f:normalizeLtree($tree, $groupNorm)
    return $tree
};        

(:~
 : Performs a location tree finalizing step: unwrap all z:_groupContent_ elements.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:finalizeLtree_groupContentRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(z:_groupContent_) return   
        if ($n/@z:groupRecursion) then $n else

        for $c in $n/* 
        let $c := f:finalizeLtree_groupContentRC($c)
        return
            typeswitch($c)
            case element(z:_annotation_) return $c
            default return (
                let $newOcc := app:multiplyOccDesc($n/@z:occ, $c/@z:occ)            
                return app:updateOccAtt($c, $newOcc)
            )

(:
        let $content :=
            for $c in $n/* return f:finalizeLtree_groupContentRC($c)
        let $newOcc := app:multiplyOccDesc($n/@z:occ, $content/@z:occ)            
        return
            app:updateOccAtt($content, $newOcc)
:)

    (: add group name :)
    case element(z:_sequence_) | element(z:_choice_) |  element(z:_all_) return
        element {node-name($n)} {
            for $a in $n/@* return f:finalizeLtree_groupContentRC($a),
            $n/parent::z:_groupContent_/@z:groupName,
            for $c in $n/node() return f:finalizeLtree_groupContentRC($c)            
        }                
    
    case element() return
        element {node-name($n)} {
            for $i in $n/(@*, node()) return
                f:finalizeLtree_groupContentRC($i)
        }                
    default return $n                
};

declare function f:filterLtreeProperties($ltree as element(), 
                                         $propertiesFilter as element(nameFilter))
        as element() {
    f:filterLtreePropertiesRC($ltree, $propertiesFilter)        
};

declare function f:filterLtreePropertiesRC($n as node(), 
                                           $propertiesFilter as element(nameFilter))
        as node()? {
    typeswitch($n)
    case document-node() return
        document {for $c in $n/node() return 
            f:filterLtreePropertiesRC($c, $propertiesFilter)}
    case element(z:locationTrees) return
        element {node-name($n)} {
            for $ns in $n/descendant::z:nsMap[1]/z:ns return
                namespace {$ns/@prefix} {$ns/@uri},
            for $a in $n/@* return f:filterLtreePropertiesRC($a, $propertiesFilter),
            for $c in $n/node() return f:filterLtreePropertiesRC($c, $propertiesFilter)
        } 
        
    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:filterLtreePropertiesRC($a, $propertiesFilter),
            for $c in $n/node() return f:filterLtreePropertiesRC($c, $propertiesFilter)
        } 
        
    case attribute() return
        if ($n/ancestor::z:nsMap) then $n
        else if (not(namespace-uri($n) eq $app:URI_LTREE)) then ()
        else if (not(tt:matchesNameFilter(local-name($n), $propertiesFilter))) then ()
        else $n
    default return $n
};

