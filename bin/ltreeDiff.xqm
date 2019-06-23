(:
 : -------------------------------------------------------------------------
 :
 : ltreeDiff.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.xsdplus.org/ns/xquery-functions/xsddiff";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at 
    "constants.xqm",
    "factTreeUtilities.xqm",
    "locationTreeInspector.xqm",
    "locationTreeWriter.xqm",
    "schemaLoader.xqm",
    "treesheetWriter.xqm";

import module namespace diff="http://www.xsdplus.org/ns/xquery-functions/xsddiff" at 
    "xsddiffTools.xqm";

declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

(:~
 : Reports differences between two location trees.
 :)
declare function f:ltreeDiff($comp1 as element(), 
                             $comp2 as element(), 
                             $schemas1 as element(xs:schema)+, 
                             $schemas2 as element(xs:schema)+, 
                             $nsmap1 as element(zz:nsMap), 
                             $nsmap2 as element(zz:nsMap), 
                             $nsmap3 as element(zz:nsMap), 
                             $options as element(options))
        as element()* {
        
    let $ltreeOptions :=
        <options withStypeTrees="true" 
                 sgroupStyle="ignore"
                 withAnnos="false"/>
        
    let $ltree1 := app:ltree($comp1, $ltreeOptions, (), $nsmap1, $schemas1)/z:locationTree[1]           
    let $ltree2 := app:ltree($comp2, $ltreeOptions, (), $nsmap2, $schemas2)/z:locationTree[1]
    let $ltreeDiffItems := f:ltreeDiffItems($ltree1, $ltree2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options, ())
    let $ltreeDiffReport := f:ltreeDiffReport($ltreeDiffItems, $ltree1, $ltree2, $nsmap1, $nsmap2, $nsmap3, $options, ())
    return $ltreeDiffReport
};   

(:~
 : Returns items reporting differences between two location trees.
 :)
declare function f:ltreeDiffItems($ltree1 as element(z:locationTree), 
                                  $ltree2 as element(z:locationTree), 
                                  $schemas1 as element(xs:schema)*, 
                                  $schemas2 as element(xs:schema)*,
                                  $nsmap1 as element(zz:nsMap),                                
                                  $nsmap2 as element(zz:nsMap),
                                  $nsmap3 as element(zz:nsMap),
                                  $options as element(options),
                                  $diffConfig as element(diffConfig)?)                                
        as element()* {
    let $ltreeRoot1 := $ltree1/app:getLtreeRoot(.)
    let $ltreeRoot2 := $ltree2/app:getLtreeRoot(.)    
    let $additionsAndChanges := f:ltreeDiffItemsRC($ltreeRoot1, $ltreeRoot2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options, $diffConfig)
    let $removals := f:ltreeRemovalsRC($ltreeRoot1, $ltreeRoot2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options)
    return
        ($additionsAndChanges, $removals)
};

(:~
 : Recursive helper function of 'ltreeDiff'.
 :)
declare function f:ltreeDiffItemsRC($lnode1 as element()+, 
                                    $lnode2 as element(),
                                    $schemas1 as element(xs:schema)*, 
                                    $schemas2 as element(xs:schema)*,
                                    $nsmap1 as element(zz:nsMap),
                                    $nsmap2 as element(zz:nsMap),
                                    $nsmap3 as element(zz:nsMap),
                                    $options as element(options),
                                    $diffConfig as element(diffConfig)?)                           
    as element()* {
(:  let $DUMMY := trace($lnode1/name(), 'LNODE1_NAME: ') :)
    let $elems1 := app:getLnodeChildElemDescriptors($lnode1)   
    let $elems2 := app:getLnodeChildElemDescriptors($lnode2)
    let $attsDiff := f:lnodesAttsDiff($lnode1, $lnode2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options, $diffConfig)
    let $elemsDiff := f:lnodesChildElemsDiff($lnode1, $lnode2, $elems1, $elems2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options, $diffConfig)    
    return (
        $attsDiff,
        $elemsDiff,
        
        for $elem2 in $elems2
        let $name := $elem2/node-name(.)
        let $alignmentCandidates := $elems1[node-name(.) eq $name]
        let $elem1:= f:getLnodeAligned($elem2, $alignmentCandidates, $nsmap3)
        where $elem1
        return f:ltreeDiffItemsRC($elem1, $elem2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options, $diffConfig)
    )
};

(:~
 : Transforms a diff list into a diff report.
 :)
declare function f:ltreeDiffReport($ltreeDiffItems as element()*,
                                   $ltree1 as element(),
                                   $ltree2 as element(),
                                   $nsmap1 as element(zz:nsMap),
                                   $nsmap2 as element(zz:nsMap),
                                   $nsmap3 as element(zz:nsMap),
                                   $options as element(options),
                                   $diffConfig as element(diffConfig)?)                           
        as item()* {
    <z:diffReport crTime="{current-dateTime()}">{
        let $addedPathPrefixes := $ltreeDiffItems/self::z:addedItem[not(starts-with(@name, '@'))]/concat(@apath, '/')    
        
        for $name in distinct-values($ltreeDiffItems/@name)
        let $myItems := for $item in $ltreeDiffItems[@name eq $name] order by $item/@apath return $item        
        let $added := $myItems/self::z:addedItem    
        let $changed := $myItems/self::z:changedItem        
        let $removed := $myItems/self::z:removedItem        

        let $added := <z:addedItems count="{count($added)}">{$added}</z:addedItems> [$added]
        let $changed := <z:changedItems count="{count($changed)}">{$changed}</z:changedItems> [$changed]        
        let $removed := <z:removedItems count="{count($removed)}">{$removed}</z:removedItems> [$removed]     
        
        let $unchanged :=
            if (not($added or $changed)) then () else
                let $paths := app:ltreePathsForItemName($name, $ltree2, $nsmap2)
                (: exclude paths under the root of added fragments :)
                let $paths := $paths[not(some $pstart in $addedPathPrefixes satisfies starts-with(., $pstart))]
                let $paths := $paths[not(. = ($added/*/@apath, $changed/*/@apath))]
                return
                    <z:unchangedItems count="{count($paths)}">{
                        for $p in $paths order by lower-case($p) return <z:unchanged apath="{$p}"/>
                    }</z:unchangedItems>

        let $notRemoved :=
            if (not($removed)) then () else
                let $paths := app:ltreePathsForItemName($name, $ltree1, $nsmap1)
                (: exclude paths under the root of added fragments :)                
                let $paths := $paths[not(some $pstart in $addedPathPrefixes satisfies starts-with(., $pstart))]
                let $paths := $paths[not(. = $removed/*/@apath)]
                return
                    <z:notRemovedItems count="{count($paths)}">{
                        for $p in $paths order by lower-case($p) return <z:notRemoved apath="{$p}"/>
                    }</z:notRemovedItems>
        order by lower-case($name)
        return
            <z:items name="{$name}">{            
                $added,
                $changed,
                $removed,
                $unchanged,
                $notRemoved                
            }</z:items>

    }</z:diffReport>
};

(: 
    differences between corresponding lnodes
    ----------------------------------------
:)

(:~
 : Reports the differences between the attributes of two location nodes.
 : The location nodes are expected to represent elements.
 :)
declare function f:lnodesAttsDiff($lnode1 as element(), 
                                  $lnode2 as element(),
                                  $schemas1 as element(xs:schema)*, 
                                  $schemas2 as element(xs:schema)*,
                                  $nsmap1 as element(zz:nsMap),
                                  $nsmap2 as element(zz:nsMap),
                                  $nsmap3 as element(zz:nsMap),
                                  $options as element(options),
                                  $diffConfig as element(diffConfig)?)                           
        as element()* {     
    let $atts1 := app:getLnodeAttributeDescriptors($lnode1)
    let $atts2 := app:getLnodeAttributeDescriptors($lnode2)
    for $node2 in $atts2
    let $name := resolve-QName($node2/@z:name, $node2)
    let $nameInfo := concat('@', $node2/@z:name/string())    
    let $node1 := $atts1[resolve-QName(@z:name, .) eq $name]    
    return
        (: attribute is new :)
        if (not($node1)) then
            let $apath2 := app:ltreePath($node2, $node2/ancestor::z:locationTree)
            let $loc2 := $node2/@z:loc
            let $parentTypeLoc1 := distinct-values($lnode1/@z:typeLoc)
            return
                <z:addedItem name="{$nameInfo}" apath="{$apath2}">{
                    attribute loc2 {$loc2},
                    attribute parentTypeLoc {$parentTypeLoc1}
                }</z:addedItem>
        (: attribute not new :)
        else          
            let $propsDiff := f:lnodePropertiesDiff($node1, $node2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options, $diffConfig)
            where $propsDiff
            return
                let $apath1 := app:ltreePath($node1, $node1/ancestor::z:locationTree)
                let $loc1 := $node1/@z:loc    
                let $loc2 := $node2/@z:loc                
                return
                    <z:changedItem name="{$nameInfo}" apath="{$apath1}">{
                        attribute loc {$loc1},
                        attribute loc2 {$loc2}[$loc1 ne $loc2],                        
                        $propsDiff
                    }</z:changedItem>
};

(:~
 : Reports the differences between the child elements of two location nodes.
 : The location nodes are expected to represent elements.
 :)
declare function f:lnodesChildElemsDiff($lnode1 as element()+, 
                                        $lnode2 as element(),
                                        $elems1 as element()*, 
                                        $elems2 as element()*,
                                        $schemas1 as element(xs:schema)*, 
                                        $schemas2 as element(xs:schema)*,
                                        $nsmap1 as element(zz:nsMap),                                
                                        $nsmap2 as element(zz:nsMap),
                                        $nsmap3 as element(zz:nsMap),
                                        $options as element(options),
                                        $diffConfig as element(diffConfig)?)                                    
        as element()* {
    let $addedDeeperItems := $options/@addedDeeperItems/string()
    for $node2 in $elems2
    let $name := $node2/node-name(.)
    let $nameInfo := $node2/@z:name/string()
    let $alignmentCandidates := $elems1[node-name(.) eq $name]
    let $node1 := f:getLnodeAligned($node2, $alignmentCandidates, $nsmap3)    
    return
        (: path new :)
        if (not($node1)) then
            let $apath2 := app:ltreePath($node2, $node2/ancestor::z:locationTree)
            let $loc2 := $node2/@z:loc
            let $parentTypeLoc1 := distinct-values($lnode1/@z:typeLoc)
            let $deeperItems :=
                if ($addedDeeperItems eq 'ignore') then () 
                else
                    let $underPaths := app:ltreeFragmentPaths($node2)
                    return
                        if (empty($underPaths)) then () 
                        else if ($addedDeeperItems eq 'count') then attribute countAddedDeeperItems {count($underPaths)} 
                        else
                            <z:addedDeeperItems>{
                                for $p in $underPaths order by lower-case($p) 
                                return <z:addedDeeperItem arpath="{$p}"/>
                            }</z:addedDeeperItems>
            
            return
                <z:addedItem name="{$nameInfo}" apath="{$apath2}">{
                    attribute loc2 {$loc2},
                    attribute parentTypeLoc {$parentTypeLoc1},
                    $deeperItems
                }</z:addedItem>
        (: path exists :)
        else           
            let $propsDiff := f:lnodePropertiesDiff($node1, $node2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options, $diffConfig) 
            return if (not($propsDiff)) then () else
                
                let $apath1 := app:ltreePath($node1, $node1/ancestor::z:locationTree)
                let $loc1 := $node1/@z:loc   
                let $loc2 := $node2/@z:loc
                return
                    <z:changedItem name="{$nameInfo}" apath="{$apath1}">{
                        attribute loc {$loc1},
                        attribute loc2 {$loc2}[$loc1 ne $loc2],
                        $propsDiff
                    }</z:changedItem>
};

(: 
    removal of lnodes
    -----------------
:)

(:~
 : Reports the removal of elements and attributes observed when comparing two 
 : location trees. A "removed" element or attribute is an item found in the 
 : first location tree but not found in the matching location of the second 
 : location tree.
 :)
declare function f:ltreeRemovalsRC(
                               $lnode1 as element()+, 
                               $lnode2 as element(),
                               $schemas1 as element(xs:schema)*, 
                               $schemas2 as element(xs:schema)*,
                               $nsmap1 as element(zz:nsMap),
                               $nsmap2 as element(zz:nsMap),
                               $nsmap3 as element(zz:nsMap),
                               $options as element(options))                           
        as element()* {
    let $atts1 := app:getLnodeAttributeDescriptors($lnode1)
    let $atts2 := app:getLnodeAttributeDescriptors($lnode2)
    let $elems1 := app:getLnodeChildElemDescriptors($lnode1)   
    let $elems2 := app:getLnodeChildElemDescriptors($lnode2)    
    
    let $attsRemoval := f:ltreeAttRemovals($lnode1, $lnode2, $atts1, $atts2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options)
    let $elemsRemoval := f:ltreeChildElemRemovals($lnode1, $lnode2, $elems1, $elems2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options)    
    return (
        $attsRemoval,
        $elemsRemoval,
        
        for $elem1 in $elems1
        let $name := $elem1/node-name(.)
        let $alignmentCandidates := $elems2[node-name(.) eq $name]
        let $elem2 := f:getLnodeAligned($elem1, $alignmentCandidates, $nsmap3)              
        where $elem2
        return
            f:ltreeRemovalsRC($elem1, $elem2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options)
    )        

};

(:~
 : Reports the removal of attributes observed when comparing two location trees.
 : A "removed" attribute is an attribute found in the first location tree but not
 : found in the matching location of the second location tree.
 :
 : A removal is mapped to an item removal descriptor:
 : <removedItem name="..." apath="..." loc="..." parentTypeLoc2=""/>
 : 
 : where: 
 : @name the qualified item name, preceded by "@"
 : @apath the ltree path of the removed attribute
 : @loc the location of the removed attribute
 : @parentTypeLoc2 the location of the type from which the attribute has been removed
 :)
declare function f:ltreeAttRemovals($lnode1 as element()+, 
                                    $lnode2 as element(),
                                    $atts1 as element()*, 
                                    $atts2 as element()*,
                                    $schemas1 as element(xs:schema)*, 
                                    $schemas2 as element(xs:schema)*,
                                    $nsmap1 as element(zz:nsMap),                                
                                    $nsmap2 as element(zz:nsMap),
                                    $nsmap3 as element(zz:nsMap),
                                    $options as element(options))                              
        as element()* {
    for $node1 in $atts1
    let $name := resolve-QName($node1/@z:name, $node1)
    let $nameInfo := concat('@', $node1/@z:name/string())    
    let $node2 := $atts2[resolve-QName(@z:name, .) eq $name]   
    where not ($node2)
    return
        let $path1 := app:ltreePath($node1, $node1/ancestor::z:locationTree)
        let $loc1 := $node1/@z:loc
        let $parentTypeLoc2 := 
            let $try := $lnode2/@z:typeLoc
            return
                if (not(starts-with($try, 'simpleType'))) then $try
                else
                    (: version 2: complex type with simple content has been reverted to a simple type;
                                  @parentLoc2 is set to the type or group thus changed :)
                    let $anc := $lnode2/ancestor::*[@z:typeLoc, @z:groupName][1]
                    return ($anc/@z:typeLoc, $anc/@z:groupName/concat('group(', ., ')'))[1]            
        return
            <z:removedItem name="{$nameInfo}" apath="{$path1}">{
                attribute loc {$loc1},
                attribute parentTypeLoc2 {$parentTypeLoc2}
            }</z:removedItem>
};

(:~
 : Reports the removal of elements observed when comparing two location trees.
 : A "removed" element is an element found in the first location tree but not
 : found in the matching location of the second location tree.
 :
 : A removal is mapped to an item removal descriptor:
 : <removedItem name="..." apath="..." loc="..." parentTypeLoc2=""
 :   <removedDeeperItems>
 :     <removeDeeperItem arpath="..."/>
 :   </removedDeeperItems>
 : </removedItem>
 : 
 : where: 
 : @name the qualified item name
 : @apath the ltree path of the removed element
 : @loc the location of the removed element
 : @parentTypeLoc2 the location of the type from which the element has been removed
 : @arpath the ltree path of a removed descendant, relative to the removed element
:)
declare function f:ltreeChildElemRemovals($lnode1 as element()+, 
                                          $lnode2 as element(),
                                          $elems1 as element()*, 
                                          $elems2 as element()*,
                                          $schemas1 as element(xs:schema)*, 
                                          $schemas2 as element(xs:schema)*,
                                          $nsmap1 as element(zz:nsMap),                                
                                          $nsmap2 as element(zz:nsMap),
                                          $nsmap3 as element(zz:nsMap),
                                          $options as element(options))                                    
        as element()* {
    let $removedDeeperItems := $options/@removedDeeperItems/string()
    
    (: visit child elements of version1 element :)
    for $node1 in $elems1
    let $name := $node1/node-name(.)
    let $nameInfo := $node1/@z:name/string()
    let $alignmentCandidates := $elems2[node-name(.) eq $name]
    let $node2 := f:getLnodeAligned($node1, $alignmentCandidates, $nsmap3)    
    where not($node2)
    return
        (: element was removed :)        
        let $path1 := app:ltreePath($node1, $node1/ancestor::z:locationTree)
        let $loc1 := $node1/@z:loc
        let $parentTypeLoc2 := 
            let $try := $lnode2/@z:typeLoc
            return
                if (not(starts-with($try, 'simpleType'))) then $try
                else
                    (: version 2: complex type with complex content has been reverted to a simple type;
                                  @parentLoc2 is set to the type or group thus changed :)                
                    let $anc := $lnode2/ancestor::*[@z:typeLoc, @z:groupName][1]
                    return ($anc/@z:typeLoc, $anc/@z:groupName/concat('group(', ., ')'))[1]            
        let $deeperItems := 
            if ($removedDeeperItems eq 'ignore') then () else
            let $underPaths := app:ltreeFragmentPaths($node1)
            return
                if (empty($underPaths)) then () 
                else if ($removedDeeperItems eq 'count') then attribute countRemovedDeeperItems {count($underPaths)}
                else
                    <z:removedDeeperItems>{
                        for $p in $underPaths order by lower-case($p) 
                        return <z:removedDeeperItem arpath="{$p}"/>
                    }</z:removedDeeperItems>
        return
            <z:removedItem name="{$nameInfo}" apath="{$path1}">{
                attribute loc {$loc1},
                attribute parentTypeLoc2 {$parentTypeLoc2},                    
                $deeperItems
            }</z:removedItem>
};

(: 
    differences between lnode properties
    ------------------------------------
:)

(:~
 : Reports any differences of the properties of two location nodes. The nodes are 
 : expected to represent the same item declaration in two schema versions. 
 : They are thus expected to both represent attributes, or both represent elements.
 :) 
declare function f:lnodePropertiesDiff($lnode1 as element()+, 
                                       $lnode2 as element(),
                                       $schemas1 as element(xs:schema)*, 
                                       $schemas2 as element(xs:schema)*,
                                       $nsmap1 as element(zz:nsMap),
                                       $nsmap2 as element(zz:nsMap),
                                       $nsmap3 as element(zz:nsMap),
                                       $options as element(options),
                                       $diffConfig as element(diffConfig)?)                           
        as element()* { 
    let $typeDesc1 := f:typeDescriptionForLnode($lnode1, $schemas1, $nsmap1)        
    let $typeDesc2 := f:typeDescriptionForLnode($lnode2, $schemas2, $nsmap2)
    
    let $p1 :=
        <lnode>{
            if ($lnode1/parent::z:_attributes_) then (
                <default>{$lnode1/@default/string()}</default>,
                <fixed>{$lnode1/@fixed/string()}</fixed>,
                <form>{($lnode1/@form/string(), 'unqualified')[1]}</form>
            ) else (
                <abstract>{($lnode1/@abstract/string(), 'false')[1]}</abstract>,                
                <block>{$lnode1/@block/string()}</block>,
                <final>{$lnode1/@final/string()}</final>,                
                <minOccurs>{($lnode1/@minOccurs/string(), '1')[1]}</minOccurs>,
                <maxOccurs>{($lnode1/@maxOccurs/string(), '1')[1]}</maxOccurs>,               
                <nillable>{($lnode1/@nillable/string(.), 'false')[1]}</nillable>            
            ),
            let $nname := $lnode1/@z:type                
            let $qname := $nname/app:resolveNormalizedQName(., $nsmap1)
            let $lname := local-name-from-QName($qname)
            let $uri := namespace-uri-from-QName($qname)
            return 
                <type name="{$lname}" uri="{$uri}" nname="{$nname}"/>,
            <typeDesc>{$typeDesc1}</typeDesc>[$typeDesc1 and $typeDesc2],
            <use>{($lnode1/@use/string(), 'optional')[1]}</use>                
        }</lnode>            
    let $p2 :=
        <lnode>{
            if ($lnode2/parent::z:_attributes_) then (
                <default>{$lnode2/@default/string()}</default>,
                <fixed>{$lnode2/@fixed/string()}</fixed>,
                <form>{($lnode2/@form/string(), 'unqualified')[1]}</form>
            ) else (
                <abstract>{($lnode2/@abstract/string(), 'false')[1]}</abstract>,                
                <block>{$lnode2/@block/string()}</block>,
                <final>{$lnode2/@final/string()}</final>,                
                <minOccurs>{($lnode2/@minOccurs/string(), '1')[1]}</minOccurs>,
                <maxOccurs>{($lnode2/@maxOccurs/string(), '1')[1]}</maxOccurs>,               
                <nillable>{($lnode2/@nillable/string(.), 'false')[1]}</nillable>            
            ),
            let $nname := $lnode2/@z:type                
            let $qname := $nname/app:resolveNormalizedQName(., $nsmap2)
            let $lname := local-name-from-QName($qname)
            let $uri := namespace-uri-from-QName($qname)
            return 
                <type name="{$lname}" uri="{$uri}" nname="{$nname}"/>,
            <typeDesc>{$typeDesc2}</typeDesc>[$typeDesc1 and $typeDesc2],
            <use>{($lnode2/@use/string(), 'optional')[1]}</use>                
        }</lnode>            
    return f:getLnodePropertiesDiffReport($p1, $p2, $nsmap1, $nsmap2, $nsmap3, $options, $diffConfig)    
};

(:~
 : Reports the difference between location node descriptions.
 :
 : @param p1 location node description #1
 : @param p2 location node description #2
 : @param ignores configures which changes to ignore
 : @param nsmap1 namespace prefix map for locartion tree #1
 : @param nsmap2 namespace prefix map for location tree #2
 : @param nsmap3 namespace prefix map for union of location trees #1 dn #2
 : @return a change report
 :) 
declare function f:getLnodePropertiesDiffReport($p1 as element(lnode), 
                                                $p2 as element(lnode), 
                                                $nsmap1 as element(zz:nsMap), 
                                                $nsmap2 as element(zz:nsMap),
                                                $nsmap3 as element(zz:nsMap),
                                                $options as element(options),
                                                $diffConfig as element(diffConfig)?)                           
        as element()* {
    if (deep-equal($p1, $p2)) then () else 
    
    let $typeName1 := if ($p1/type/@uri eq $app:URI_XSD) then concat('xs:', $p1/type/@name) else $p1/type/@name/string()
    let $typeName2 := if ($p2/type/@uri eq $app:URI_XSD) then concat('xs:', $p2/type/@name) else $p2/type/@name/string()    
    return
    
    (

    if (deep-equal($p1/abstract, $p2/abstract)) then ()
    else if ($p2/abstract eq 'true') then <z:addedAbstract/>
    else <z:removedAbstract/>,      
                
    if (deep-equal($p1/block, $p2/block)) then ()
    else if (not($p1/block/string())) then <z:addedBlock value="{$p2/block}"/>
    else if (not($p2/block/string())) then <z:removedBlock value="{$p1/block}"/>    
    else <z:changedBlock fr="{$p1/block}" to="{$p2/block}"/>,      
                
    if (deep-equal($p1/default, $p2/default)) then ()
    else if (not($p1/default/string())) then <z:addedDefault value="{$p2/default}"/>
    else if (not($p2/default/string())) then <z:removedDefault value="{$p1/default}"/>
    else <z:changedDefault fr="{$p1/default}" to="{$p2/default}"/>,      
                
    if (deep-equal($p1/final, $p2/final)) then ()
    else if (not($p1/final/string())) then <z:addedFinal value="{$p2/final}"/>
    else if (not($p2/final/string())) then <z:removedFinal value="{$p1/final}"/>    
    else <z:changedFinal fr="{$p1/final}" to="{$p2/final}"/>,      
                
    if (deep-equal($p1/fixed, $p2/fixed)) then ()
    else if (not($p1/fixed/string())) then <z:addedFixed value="{$p2/fixed}"/>
    else if (not($p2/fixed/string())) then <z:removedFixed value="{$p1/fixed}"/>
    else <z:changedFixed fr="{$p1/fixed}" to="{$p2/fixed}"/>,      
                
    if (deep-equal($p1/form, $p2/form)) then ()
    else <z:changedForm fr="{$p1/form}" to="{$p2/form}"/>,

    if (deep-equal($p1/minOccurs, $p2/minOccurs)) then ()
    else <z:changedMinOccurs fr="{$p1/minOccurs}" to="{$p2/minOccurs}"/>,                
                
    if (deep-equal($p1/maxOccurs, $p2/maxOccurs)) then ()
    else <z:changedMaxOccurs fr="{$p1/maxOccurs}" to="{$p2/maxOccurs}"/>,               

    if (deep-equal($p1/nillable, $p2/nillable)) then ()
    else if ($p2/nillable eq 'true') then <z:addedNillable/>
    else <z:removedNillable/>,      
                
    if (not($typeName1) and not($typeName2)) then ()
    else if ($typeName1 and not($typeName2)) then <z:lostType type="{$typeName1}"/>
    else if (not($typeName1) and $typeName2) then <z:addedType type="{$typeName2}"/> 
    else if ($p1/type/@name eq $p2/type/@name and not($p1/type/@uri eq $p2/type/@uri)) then   
        let $diff :=        
            <z:changedType type="{$typeName1}" namespaceFrom="{$p1/type/@uri}" namespaceTo="{$p2/type/@uri}"/>
        return
            f:editPropertiesDiffReport($diff, $p1, $p2, $options, $diffConfig)           
    
    else if (QName($p1/type/@uri, $p1/type/@name) ne QName($p2/type/@uri, $p2/type/@name)) then
        let $diff := <z:changedType fr="{$typeName1}" to="{$typeName2}"/>
        return
            f:editPropertiesDiffReport($diff, $p1, $p2, $options, $diffConfig)
    else (),
                
    if ($p1/type/@nname eq "" and $p2/type/@nname eq "") then ()
    else if ($p1/type/@nname ne "" and $p2/type/@nname eq "") then ()
    else if ($p1/type/@nname eq "" and $p2/type/@nname ne "") then () 
    else if (deep-equal($p1/typeDesc, $p2/typeDesc)) then ()
    else 
        let $diff :=
            <z:changedTypeDef>
                <fr typeInfo="{$p1/typeDesc}"/>
                <to typeInfo="{$p2/typeDesc}"/>
            </z:changedTypeDef>
        return
            f:editPropertiesDiffReport($diff, $p1, $p2, $options, $diffConfig),

    if (deep-equal($p1/use, $p2/use)) then ()
    else <z:changedUse fr="{$p1/use}" to="{$p2/use}"/>,

    ()
    
    )
};

(:~
 : Edits a properties diff report, controlled by an editing confguration.
 :)
declare function f:editPropertiesDiffReport($diff as element(), 
                                            $p1 as element(lnode), 
                                            $p2 as element(lnode), 
                                            $options as element(options),
                                            $cfg as element(diffConfig)?)
        as element()? {
                
    let $kind :=    
        typeswitch($diff)
        case element(z:changedType) return 'typeChange'
        case element(z:changedTypeDef) return 'typeDefChange'
        default return local-name($diff)
    let $changes := $cfg/*[@kind eq $kind]
                [not(@typeName) or @typeName eq $p1/type/@name]
                [not(@fromTypeName) or @fromTypeName eq $p1/type/@name]                
                [not(@toTypeName) or @toTypeName eq $p2/type/@name]  
                [@typeName, @fromTypeName, @toTypeName]
    return
        if ($changes/self::diffIgnore) then 
            trace((), concat('DIFF_IGNORE, KIND=', $kind, ' ; P1/TYPE=', $p1/type/@name, ' ; P2/TYPE=', $p2/type/@name, ' : '))
        else if ($changes/self::diffEdit) then
            let $atts := ($changes/(@append, @replace))[1]
            return
                element {node-name($diff)} {
                    $diff/@*,
                    $atts,
                    $diff/node()
                }
        else $diff                
};

(: Selects for a given location node the aligned location node in a second location tree. 
 : The aligned node is selected from a set of candidates which all have the same node name 
 : as the given location node. The aligned node is determined as the node whose last path 
 : step matches the last path step of the given node.
 :
 : @param node the location tree node for which the aligned location tree node is sought
 : @param candidates the candidates for the aligned node
 :)
declare function f:getLnodeAligned($node as node(), 
                                   $candidates as node()*,
                                   $nsmapAll as element(zz:nsMap))                                   
        as node()? {
    let $pathLastStep := app:ltreePathLastStep($node, (), $nsmapAll)       
    let $aligned := $candidates[app:ltreePathLastStep(., (), $nsmapAll) eq $pathLastStep]
    return
        if ($aligned) then $aligned[1] else
        
        let $pathLastStep := app:ltreePathLastStep($node, 'ignChoice', $nsmapAll)       
        let $aligned := $candidates[app:ltreePathLastStep(., 'ignChoice', $nsmapAll) eq $pathLastStep]
        return
            if ($aligned) then $aligned[1] else
            
            let $pathLastStep := app:ltreePathLastStep($node, 'ignChoiceSequence', $nsmapAll)       
            let $aligned := $candidates[app:ltreePathLastStep(., 'ignChoiceSequence', $nsmapAll) eq $pathLastStep]
            return $aligned[1]        

};

(:~
 : Returns the description of a simple type. The type may be a simple type definition,
 : or a complex type definition with simple content.
 :)
declare function f:typeDescriptionForLnode($lnode as element(), 
                                           $schemas as element(xs:schema)+, 
                                           $nsmap as element(zz:nsMap))
        as xs:string? {
    if (not($schemas)) then () else
            
    let $typeLoc := $lnode/@z:typeLoc
    let $typeDef := $lnode/(
        @z:typeLoc/app:resolveComponentLocator(., $nsmap, $schemas),
        @z:type/app:resolveNormalizedQName(., $nsmap))[1]
    return                    
        if ($typeDef instance of node()) then
            let $typeVariant := app:tgetTypeVariant($typeDef, $schemas)
            return
                if ($typeVariant eq 'cc') then () 
                else if ($typeVariant eq 'ce') then '%EMPTY%'                 
                else if ($typeVariant eq 'cc') then '%COMPLEX%'                        
                else app:stypeInfo($typeDef, "text", $nsmap, $schemas)
        else if (exists($typeDef)) then 
            app:stypeInfoForTypeName($typeDef, "text", $nsmap, $schemas)
        else 
            '%UNTYPED%'
        
};

