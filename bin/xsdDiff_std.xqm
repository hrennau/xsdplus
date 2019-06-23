(:
 : -------------------------------------------------------------------------
 :
 : xsdDiff_std - transforms a base diff report into a std diff report
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.xsdplus.org/ns/xquery-functions/xsddiff";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm"
;    
    
import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at 
    "constants.xqm"
;

import module namespace diff="http://www.xsdplus.org/ns/xquery-functions/xsddiff" at 
    "xsddiffTools.xqm",
    "ltreeDiff.xqm"
;

declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

declare function f:xsdBaseDiff2Std($baseDiff as element(), $options as element(options)?)
        as element() {
(:        
    let $tpath := $options/@tpath/xs:boolean(.)
    let $epath := $options/@epath/xs:boolean(.)    
    let $apath := $options/@apath/xs:boolean(.)    
    let $gpath := $options/@gpath/xs:boolean(.)    
    let $skipDeeperItems := $options/@skipDeeperItems/xs:boolean(.)    
    let $noprefix := $options/@noprefix/xs:boolean(.)
    let $igroup := $options/@igroup/xs:boolean(.)    
    let $skipLoc := $options/@skipLoc/xs:boolean(.)   
    let $changeDetails := $options/@changeDetails/string(.)
:)    
    f:xsdBaseDiff2StdRC($baseDiff, $options)        
};

(:~
 : Recursive helper function of 'xsdBaseDiff2Std'.
 :)
declare function f:xsdBaseDiff2StdRC($n as node()?, $options as element(options)?)
        as node()? {
    typeswitch($n)  
    case document-node() return document {$n/node() ! f:xsdBaseDiff2StdRC(., $options)}
        
    case element(z:xsdDiff) return
        element {node-name($n)} {
            namespace zz {"http://www.ttools.org/structure"},
            $n/in-scope-prefixes(.) ! namespace {.} {namespace-uri-for-prefix(., $n)},
            attribute format {"std"},
            $options/@noprefix[string()]/attribute noprefix {.},
            $options/@tpath[string()]/attribute tpath {.},
            $options/@epath[string()]/attribute epath {.},            
            $options/@apath[string()]/attribute apath {.},     
            $options/@gpath[string()]/attribute gpath {.},            
            $options/@changeDetails[string()]/attribute changeDetails {.},
            $n/(@* except @format) ! f:xsdBaseDiff2StdRC(., $options),
            $n/node() ! f:xsdBaseDiff2StdRC(., $options)            
        }
        
    case element(z:component) return
        (: the content of changed components is reorganized :)
        if ($n/parent::z:componentsChanged) then
            let $igroup := $options/@igroup/xs:boolean(.)
            let $items := $n/z:items/f:xsdBaseDiff2StdRC(., $options)
            let $added := $items//z:addedItem 
            let $removed := $items//z:removedItem            
            let $changed := $items//z:changedItem            
            
            let $changeReport := 
                (: *** if igroup=true, grouping is by item name ... :)
                if ($igroup) then $items 
                (: *** otherwise, grouping is by change type, added | changed | removed :)
                else (           
                    <z:addedItems>{
                        $added/element {node-name(.)} {ancestor::z:items/@name, @* except @name, node()}
                    }</z:addedItems>[$added],
                    <z:changedItems>{
                        $changed/element {node-name(.)} {ancestor::z:items/@name, @* except @name, node()}
                    }</z:changedItems>[$changed],
                    <z:removedItems>{
                        $removed/element {node-name(.)} {ancestor::z:items/@name, @* except @name, node()}
                    }</z:removedItems>[$removed]
                )
            return
                element {node-name($n)} {
                    $n/@* ! f:xsdBaseDiff2StdRC(., $options),
                    $changeReport                
                }
        else
            element {node-name($n)} {
                $n/@* ! f:xsdBaseDiff2StdRC(., $options),
                $n/node() ! f:xsdBaseDiff2StdRC(., $options)                
            }
        
    (: <z:items> contains all items with a particular item name :)    
    case element(z:items) return
        let $tpath := $options/@tpath/xs:boolean(.)
        return
    
        if (not($tpath)) then
             element {node-name($n)} {
                $n/@* ! f:xsdBaseDiff2StdRC(., $options),
                $n/node() ! f:xsdBaseDiff2StdRC(., $options)                
            }
            
        (: *** tpath=true: provide distinctive trailing path :)           
        else            
            let $addedItems := $n/z:addedItems
            let $changedItems := $n/z:changedItems
            let $removedItems := $n/z:removedItems
            let $unchangedItems := $n/z:unchangedItems
            let $DUMMY := trace( count($unchangedItems/*) , 'COUNT_UNCHANGED: ')        
            let $notRemovedItems := $n/z:notRemovedItems
            let $allItems := $addedItems | $changedItems | $removedItems | $unchangedItems | $notRemovedItems

            let $addedItemsAggregated :=
                if (not($addedItems)) then () else
                    let $otherItems := ($allItems except $addedItems)/*            
                    let $items := f:getTrailingPathItems($addedItems/*, $otherItems)            
                    return trace(
                        <z:addedItems countTrailingPaths="{count($items)}" countPaths="{count($addedItems/*)}">{
                            for $i in $items order by $i/@path return $i                    
                        }</z:addedItems> , 'ADDED_ITEMS: ')
            
            let $changedItemsAggregated :=
                if (not($changedItems)) then () else
                    let $otherItems := ($allItems except $changedItems)/*
                    let $items := f:getTrailingPathItems($changedItems/*, $otherItems)
                    return
                        <z:changedItems countTrailingPaths="{count($items)}" countPaths="{count($changedItems/*)}">{
                            for $i in $items order by $i/@path return $i                    
                        }</z:changedItems>
            
            let $removedItemsAggregated :=
                if (not($removedItems)) then () else
                    let $otherItems := ($allItems except $removedItems)/*
                    let $items := f:getTrailingPathItems($removedItems/*, $otherItems)
                    return
                        <z:removedItems countTrailingPaths="{count($items)}" countPaths="{count($removedItems/*)}">{
                            for $i in $items order by $i/@path return $i                    
                        }</z:removedItems>
            return
                element {node-name($n)} {
                    $n/@name/f:xsdBaseDiff2StdRC(., $options),
                    $addedItemsAggregated/f:xsdBaseDiff2StdRC(., $options),
                    $changedItemsAggregated/f:xsdBaseDiff2StdRC(., $options),
                    $removedItemsAggregated/f:xsdBaseDiff2StdRC(., $options),               
                    ()
                }
    case element() return
        let $skipDeeperItems := $options/@skipDeeperItems/xs:boolean(.)
        let $changeDetails := $options/@changeDetails/string(.)
        return        
            if ($skipDeeperItems and 
                ($n/self::z:addedDeeperItems or $n/self::z:removedDeeperItems)) then () 
            else
                element {node-name($n)} {
                $n/@* ! f:xsdBaseDiff2StdRC(., $options),
                if (not($n/self::z:changedItem) or $changeDetails eq 'all') then             
                    $n/node()/f:xsdBaseDiff2StdRC(., $options)
                else if ($changeDetails eq 'none') then 
                    () 
                else 
                    attribute changes {f:getChangeDescriptor($n, $changeDetails)}
            }
    case attribute(loc) return 
        let $skipLoc := $options/@skipLoc/xs:boolean(.)
        return if ($skipLoc) then () else $n        
    
    case attribute(name) return
        let $noprefix := $options/@noprefix/xs:boolean(.)
        return
            if (not($noprefix)) then $n else
                let $value:= f:dePrefixPath($n)
                return
                    attribute {node-name($n)} {$value}

    case attribute(tpath) return
        let $gpath := $options/@gpath/xs:boolean(.)
        let $noprefix := $options/@noprefix/xs:boolean(.)        
        let $value := 
            let $v := if ($gpath) then $n else f:deAnnotatePath($n)
            let $v := if (not($noprefix)) then $v else f:dePrefixPath($v)
            return $v
        return
            attribute {node-name($n)} {$value}
            
    case attribute(epath) return
        let $gpath := $options/@gpath/xs:boolean(.)
        let $noprefix := $options/@noprefix/xs:boolean(.)        
        let $value :=
            let $v := if ($gpath) then $n else f:deAnnotatePath($n) 
            let $v := if (not($noprefix)) then $v else f:dePrefixPath($v)
            return $v
        return
            attribute {node-name($n)} {$value}

    case attribute(apath) | attribute(arpath) return
        let $apath := $options/@apath/xs:boolean(.)    
        let $gpath := $options/@gpath/xs:boolean(.)  
        let $noprefix := $options/@noprefix/xs:boolean(.)   
        return        
            let $value :=
                let $v := 
                    if ($apath) then $n
                    else if ($gpath) then f:deAnnotatePathRetainingStructure($n)
                    else f:deAnnotatePath($n)
                let $v := if (not($noprefix)) then $v else f:dePrefixPath($v)
                return $v
            let $name := 
                if ($apath) then local-name($n)
                else if ($gpath) then 
                    if (local-name($n) eq 'arpath') then 'grpath' else 'gpath' 
                else 
                    if (local-name($n) eq 'arpath') then 'rpath' else 'path'
            return
                attribute {$name} {$value}

    case attribute() return $n
    
    default return $n

};

(:~
 : Maps the information about the changes of an item to a single descriptor string.
 :
 : @param format short|... => concise / verbose
 : @return the descriptor string
 :)
declare function f:getChangeDescriptor($change as element(), $format as xs:string)
        as xs:string {
    let $descriptors :=
        for $item in $change/*
        return
            typeswitch($item)
            case element(z:addedAbstract) return 
                if ($format eq 'types') then 'abstract'
                else 'added abstract'            
            case element(z:removedAbstract) return 
                if ($format eq 'types') then 'abstract'
                else 'removed abstract'

            case element(z:addedBlock) return 
                if ($format eq 'types') then 'block'
                else concat('added block: ', $item/@value)            
            case element(z:removedBlock) return 
                if ($format eq 'types') then 'block'
                else concat('removed block: ', $item/@value)
            case element(z:changedBlock) return
                if ($format eq 'types') then 'block'
                else if ($format eq 'short') then concat('block ', $item/@fr, '/', $item/@to)
                else concat('changed block from#to: ', $item/@fr, ' #', $item/@to)            

            case element(z:addedDefault) return 
                if ($format eq 'types') then 'default'
                else concat('added default: ', $item/@value)
            case element(z:removedDefault) return 
                if ($format eq 'types') then 'default'
                else concat('removed default: ', $item/@value)            
            case element(z:changedDefault) return
                if ($format eq 'types') then 'default'                
                else if ($format eq 'short') then concat('default ', $item/@fr, '/', $item/@to)
                else concat('changed default from#to: ', $item/@fr, ' #', $item/@to)           

            case element(z:addedFinal) return 
                if ($format eq 'types') then 'final'
                else concat('added final: ', $item/@value)
            case element(z:removedFinal) return 
                if ($format eq 'types') then 'final'
                else concat('removed final: ', $item/@value)          
            case element(z:changedFinal) return
                if ($format eq 'types') then 'final'            
                else if ($format eq 'short') then concat('final ', $item/@fr, '/', $item/@to)
                else concat('changed final from#to: ', $item/@fr, ' #', $item/@to)           

            case element(z:addedFixed) return 
                if ($format eq 'types') then 'fixed'
                else concat('added fixed: ', $item/@value)
            case element(z:removedFixed) return 
                if ($format eq 'types') then 'fixed'
                else concat('removed fixed: ', $item/@value)          
            case element(z:changedFixed) return
                if ($format eq 'types') then 'fixed'
                else if ($format eq 'short') then concat('fixed ', $item/@fr, '/', $item/@to)
                else concat('changed fixed from#to: ', $item/@fr, ' #', $item/@to)           

            case element(z:changedForm) return 
                if ($format eq 'types') then 'form'
                else concat('changed form from#to: ', $item/@fr, ' #', $item/@to)

            case element(z:changedMinOccurs) return
                if ($format eq 'types') then 'minOccurs'
                else if ($format eq 'short') then concat('minOccurs ', $item/@fr, '/', $item/@to)
                else concat('minOccurs changed from#to: ', $item/@fr, ' #', $item/@to)            
            case element(z:changedMaxOccurs) return
                if ($format eq 'types') then 'maxOccurs'
                else if ($format eq 'short') then concat('maxOccurs ', $item/@fr, '/', $item/@to)
                else concat('maxOccurs changed from#to: ', $item/@fr, ' #', $item/@to)            

            case element(z:addedNillable) return 
                if ($format eq 'types') then 'nillable'
                else 'added nillable'
            case element(z:removedNillable) return 
                if ($format eq 'types') then 'nillable'
                else 'removed nillable'            

            case element(z:addedType) return 
                if ($format eq 'types') then 'type'
                else concat('type added: ', $item/@type)
            case element(z:lostType) return 
                if ($format eq 'types') then 'type'
                else concat('type lost: ', $item/@type)            
            case element(z:changedType) return
                if ($format eq 'types') then 'type'
                else if ($item/@namespaceFrom) then
                    concat('type namespace of type ', $item/@type, ' changed from#to=', $item/@namespaceFrom, ' #', $item/@namespaceTo, $item/@append)
                else                    
                    let $t1 := $item/@fr
                    let $t1 := if ($t1 eq 'z:_LOCAL_') then '(local)' else $t1
                    let $t1 := if (starts-with($t1, 'xs:')) then $t1 else replace($t1, '.+:', '')
                    let $t2 := $item/@to
                    let $t2 := if ($t2 eq 'z:_LOCAL_') then '(local)' else $t2                
                    let $t2 := if (starts-with($t1, 'xs:')) then $t2 else replace($t2, '.+:', '')                
                    return
                        if ($item/@replace) then $item/@replace
                        else
                            if ($format eq 'short') then concat('type ', $t1, '/', $t2, $item/@append)
                            else concat('type changed from#to: ', $t1, ' #', $t2, $item/@append)
           
            case element(z:changedTypeDef) return
                if ($format eq 'types') then 'typeDef' else
                
                let $typeChange := $change/z:changedType
                return
                    if ($typeChange and starts-with($typeChange/@fr, 'xs:') and starts-with($typeChange/@to, 'xs:')) then () else
                    (: suppress change type def description if both types involved are built-in :)
                    
                let $truncate := 40
                let $info1 := $item/fr/@typeInfo
                let $info1 := if (string-length($info1) le $truncate) then $info1 else concat(substring($info1, 1, $truncate), ' ...')
                let $info2 := $item/to/@typeInfo
                let $info2 := if (string-length($info2) le $truncate) then $info2 else concat(substring($info2, 1, $truncate), ' ...')                
                return
                    if ($format eq 'short') then concat('type def changed, now: ', $info2)
                    else concat('type definition changed from#to: ', $info1, ' #', $info2)
            case element(z:changedUse) return 
                if ($format eq 'types') then 'use' else
                
                if ($item/@to eq 'optional') then 'attribute made optional'
                else if ($item/@to eq 'required') then 'attribute made required'
                else if ($item/@to eq 'prohibited') then 'attribute made prohibited'                
                else 
                    if ($format eq 'short') then concat('attribute use ', $item/@fr, '/', $item/@to)
                    else concat('attribute use changed from#to: ', $item/@fr, ' #', $item/@to)            
            default return local-name($item)
    return
        string-join($descriptors, '; ')
};

(:~
 : Returns aggregated items grouped by trailing path. The grouping 
 : uses the smallest possible number of trailing path steps which ...
 : (1)
 : ensures among the updated items an unambiguous mapping from trailing 
 : path to the value of one of the attributes:
 : - @loc (item: changedItem) 
 : - @loc2 (item: addedItem) 
 : - @parentTypeLoc (item: addedItem)
 : - @parentTypeLoc2 (item: removedItem)
 : (2)
 : is not a prefix of any not updated item
 : 
 : Note: for every group defined by one of the trailing paths, 
 : all items have the same locations.
 :
 : @param itemsUpdated each item describes an element or attribute which has been added, changed or removed
 : @itemsOther each item describes an element or attribute which has not been changed
 : @return aggregated updated items, one for each location
 :)
declare function f:getTrailingPathItems($itemsUpdated as element()*, $itemsOther as element()*) {    
    if (empty($itemsUpdated)) then () else    
    
    (: enhance items with a normalized path :)   
    let $items :=   
        for $item in $itemsUpdated
        let $path := f:deAnnotatePathRetainingStructure($item/@apath)
        return
            element {node-name($item)} {
                attribute path {$path},
                $item/(@*, node())
            }
    let $paths := $items/@path/string()            
    let $otherPaths := $itemsOther/f:deAnnotatePathRetainingStructure(@apath)    
    let $allPaths := ($paths, $otherPaths)
    let $maxPathLen := max(for $p in $allPaths return count(tokenize($p, '/')))
    let $result := f:getTrailingPathItemsRC($items, $paths, $otherPaths, $maxPathLen, 1)
    return 
        $result
};

(:~
 : Recursive helper function of 'getTrailingPathItems'.
 :)
declare function f:getTrailingPathItemsRC($items as element()*, 
                                          $paths as xs:string+, 
                                          $otherPaths as xs:string*,
                                          $maxPathLen as xs:integer, 
                                          $usePathLen as xs:integer)
        as element()* {
    if ($usePathLen ge $maxPathLen) then 
        for $item in $items
        let $tpath := concat('/', f:deAnnotatePath($item/@apath))
        return
            element {node-name($item)} {
                attribute tpath {$tpath},
                attribute epath {$item[1]/@path},
                $item/@loc,
                $item/node()
            } 
        
    else    

    let $trailingPaths :=
        distinct-values(
            for $p in $paths return string-join(tokenize($p, '/')[position() ge last() - $usePathLen + 1], '/'))            

    let $matches :=
        for $t in distinct-values($trailingPaths)
        let $myItems := $items[ends-with(@path, concat('/', $t)) or @path eq $t]
        let $myItems1 := $myItems[1]
        let $locationCount :=
            if ($myItems1/@loc) then count(distinct-values($myItems/@loc))
            else if ($myItems1/@loc2) then count(distinct-values($myItems/@loc2))            
            else if ($myItems1/@parentTypeLoc) then count(distinct-values($myItems/@parentTypeLoc))
            else if ($myItems1/@parentTypeLoc12) then count(distinct-values($myItems/@parentTypeLoc2))

            else ()
        return
            if (starts-with($t, '#') or starts-with($t, '%')) then ()
            else if ($locationCount ne 1) then ()            
            else if (exists($otherPaths[ends-with(., concat('/', $t)) or . eq $t])) then ()
            else
                let $item1 := $myItems[1]
                let $tpath := if ($t eq $item1/@path) then concat('/', $t) else $t
                return (
                    (: remember the matching paths as paths that have been taken care of :)
                    $myItems/@path/string(),
                    
                    (: the element represents a "reduced" item - with @tpath instead of @path :)
                    element {node-name($item1)} {
                        attribute tpath {$tpath},
                        attribute epath {$myItems[1]/@path},
                        $item1/(@* except (@path, @apath)),
(:                        
                        $item1/@loc,
                        $item1/@loc2,
:)                        
                        $item1/node()
                    }
                )
    (: the items that have been taken care of :)
    let $trailingPathItems := $matches[. instance of node()]
    
    (: the paths that have been matched :)
    let $matchedPaths := $matches[. instance of xs:anyAtomicType]
    
    (: the paths that have not yet been matched :)
    let $unmatchedPaths := $paths[not(. = $matchedPaths)]
            
    (: the items that have not yet been taken care of :)
    let $unmatchedItems :=
        if (empty($matchedPaths)) then $items else $items[@path = $unmatchedPaths]
    return (
        $trailingPathItems,
        if (empty($unmatchedPaths)) then () else
            f:getTrailingPathItemsRC($unmatchedItems, $unmatchedPaths, $otherPaths, $maxPathLen, $usePathLen + 1)
    )            
};

(:~
 : Deannotates a path. Deannotation means removing all annotation information 
 : (steps representing model groups like sequences, all groups and choices, 
 : as well as step postfixes indicating occurrence constraints or default values). 
 : The resulting path consists only of element and attribute names.
 :)
declare function f:deAnnotatePath($apath as xs:string)
        as xs:string {
    string-join(        
        for $step in tokenize($apath, '/')[matches(., '^@?\i\c*')]
        return replace($step, '(^@?\i\c*).*', '$1')
    , '/')       
};

(:~
 : Deannotates a path. Deannotation means removing all annotation information 
 : (steps representing model groups like sequences, all groups and choices, 
 : as well as step postfixes indicating occurrence constraints or default values). 
 : The resulting path consists only of element and attribute names.
 :)
declare function f:deAnnotatePathRetainingStructure($apath as xs:string)
        as xs:string {        
    let $path := replace($apath, '(^|/)(#|%seq|%all)[^/]*', '$1$2')
    return
        string-join(        
            for $step in tokenize($path, '/')
            return replace($step, '^(@?\i\c*).*', '$1')
        , '/')       
};

(:~
 : Deprefixes a path. Deprefixing means removing all name prefixes.
 :
 : @param path the path
 : @return the deprefixed path
 :)
declare function f:dePrefixPath($path as xs:string)
        as xs:string {
    replace($path, '(^|/)\i\c*:', '$1')        
};        

