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

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at 
    "occUtilities.xqm";

declare namespace z="http://www.xsdplus.org/ns/structure";

(: *** 
       g r o u p    e x p a n s i o n       
   *** :)

declare function f:expandGroupComps($groupComps as element()*)
        as element()* {
        (: 2. expand group references :)
        let $expandedGroups :=
            let $groupDict :=
                map:merge(
                    for $groupComp in $groupComps
                    let $name := $groupComp/@z:name
                    return map:entry($name, $groupComp)
                )
            let $accum :=
                map{'expanded': (), 
                    'groupDict': $groupDict, 
                    'expandedGroupDict': map{}}
            let $foldExpandGroup := app:foldExpandGroup#2
            let $accumFinal := fold-left($groupComps, $accum, $foldExpandGroup)
            return
                $accumFinal?expanded
    return
        $expandedGroups
};

(:~
 : Expands a group descriptor by recursively replacing group 
 : references by a representation of group contents.
 :
 : @param group a group descriptor
 : @param groupDict a mapping of normalized group names to group 
 :    descriptors; descriptors are not expanded
 : @param alreadyExpanded a list of expanded group descriptors
 : @return the expanded group descriptor
 :)
declare function f:expandGroup($group as element(z:group),
                               $groupDict as map(*),
                               $expandedGroupDict as map(*))
        as element(z:group) {
    let $result := f:expandGroupRC($group, $groupDict, $expandedGroupDict, ())
    return
        $result
};        

(:~
 : Recursive helper function of `expandGroup`.
 :
 : @param n a node of the group descriptor
 : @param groupDict a mapping of normalizd group names to group descriptors
 : @param alreadyExpanded a list of expanded group descriptors
 : @param ancestorGroups groups into which this group is nested 
 : @return the expanded group descriptor
 :) 
declare function f:expandGroupRC($n as node(), 
                                 $groupDict as map(*),
                                 $expandedGroupDict as map(*),
                                 $ancestorGroups as element(z:group)*)
        as node()+ {
    typeswitch($n)

    (: elem z:group represents a group definition :) 
    case $group as element(z:group) return
        <z:group>{
            $group/@*,
            f:expandGroupRC($group/z:_groupContent_, 
                $groupDict, $expandedGroupDict, ($ancestorGroups, $group))
        }</z:group>                
    
    (: element z:_group_ is a group reference :)
    case element(z:_group_) return    
        let $ref := $n/@ref   (: TO.DO - name normalization ? :)
        let $occ := $n/@z:occ
        let $fromCache := map:get($expandedGroupDict, $ref)
        let $groupContent :=
            if ($fromCache) then $fromCache/z:_groupContent_
            else
                let $refGroup := map:get($groupDict, $ref) 
                return
                    if ($refGroup intersect $ancestorGroups) then
                        <z:_groupContent_ z:groupName="{$ref}" z:groupRecursion="{$ref}"/>
                    else
                        f:expandGroupRC($refGroup/z:_groupContent_, 
                            $groupDict, $expandedGroupDict, ($ancestorGroups, $refGroup))
        return
            app:updateOccAtt($groupContent, $occ) 
                    
    case element() return
        element {node-name($n)} {
            for $i in $n/(@*, node()) return 
                f:expandGroupRC($i, $groupDict, $expandedGroupDict, $ancestorGroups)
        }
        
    default return $n
};

(:~
 : Folding function used when expanding group definitions by
 : replacing group references by group content. The expansion
 : is realized applying a left-fold on the sequence of 
 : explicit group definitions.
 :
 : Note. Folding is used in order to reuse expansions -
 : expansions are stored in the accumulator map (key
 : 'already-expanded').
 :
 : @param accum accumulator used during left-fold
 : @param item an item of the sequence of explicit group definitions
 : @return an updated copy of the accumulator
 :)
declare function f:foldExpandGroup($accum as map(*),
                                   $item as element(z:group))
        as map(*) {
    let $groupDict := $accum?groupDict        
    let $expandedGroupDict := $accum?expandedGroupDict
    let $expanded := $accum?expanded
    let $needsExpansion := exists($item//z:_group_)
    let $expansion :=
        if (not($needsExpansion)) then $item
        else f:expandGroup($item, $groupDict, $expandedGroupDict)
    
    (: additional new expansions are retrieved from the contents of the expansion :)
    let $newExpandedGroupDict :=
        if (not($needsExpansion)) then $expandedGroupDict else
 
        map:merge((
            $expandedGroupDict,
            map:entry($item/@z:name, $expansion),
            let $namesAlreadyExpanded := distinct-values((map:keys($expandedGroupDict), $expansion/@z:name))
            for $newExpansion in 
                $expansion/*//z:_groupContent_[not(@z:groupName = $namesAlreadyExpanded)]
            group by $newExpansionName := $newExpansion/@z:groupName/string()
            let $expansion1 := $newExpansion[1]
            let $group := <z:group>{app:updateOccAtt($expansion1, '')}</z:group>
            return
                map:entry($newExpansionName, $group)
        ))                
    return
        map{
            'expanded': ($expanded, $expansion),
            'groupDict': $groupDict,            
            'expandedGroupDict': $newExpandedGroupDict
        }
};

