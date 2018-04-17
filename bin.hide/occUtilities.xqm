(:
 : -------------------------------------------------------------------------
 :
 : occUtilities.xqm - utility functions for handling occurrency constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at
    "constants.xqm",
    "schemaLoader.xqm",
    "treeNavigator.xqm";
    
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_namespaceTools.xqm";    

declare namespace z="http://www.xsdplus.org/ns/structure";

(:~
 : Returns an attribute reporting occurrence constraints
 : in succinct form. The constraints refer to an element
 : declaration or a group compositor. The constraints are 
 : specified by the @minOccurs and @maxOccurs attributes 
 : on the given element, which default to the value 1.
 :
 : @param elem an element which may have attributes
 :     @minOccurs and/or @maxOccurs
 : @return `z:occ` attribute expressing the information
 :     provided by @minOccurs and @maxOccurs, or the
 :     empty sequence if there are no such attributes
 :)
declare function f:getOccAtt($elem as element())
        as attribute(z:occ)? {
    let $min := ($elem/@minOccurs, '1')[1]        
    let $max := ($elem/@maxOccurs, '1')[1] ! replace(., 'unbounded', '*')
    let $value :=
        if ($min eq '1' and $max eq '1') then ()
        else if ($min eq '0') then
            switch($max)
            case '1' return '?'
            case '*' return $max
            default return concat('0-', $max)
        else if ($min eq '1') then
            switch($max)
            case '0' return '0'
            case '*' return '+'
            default return concat('1-', $max)
        else if ($min eq 'unbounded') then '0'
        else concat($min, '-', $max)
    return
        if (empty($value)) then () else attribute z:occ {$value}
};

(:~
 : Returns an attribute reporting occurrence constraints
 : of an attribute declaration in succinct form. The 
 : constraints are specified by the @minOccurs and @maxOccurs 
 : attributes on the given element, which default to the value 1.
 :
 : @param elem an element which may have attributes
 :     @minOccurs and/or @maxOccurs
 : @return `z:occ` attribute expressing the information
 :     provided by @minOccurs and @maxOccurs, or the
 :     empty sequence if there are no such attributes
 :)
declare function f:getAttributeOccAtt($att as element())
        as attribute(z:occ)? {
    if ($att/@use eq 'required') then ()
    else if ($att/@use eq 'prohibited') then attribute z:occ {'0'}
    else attribute z:occ {'?'}
};

(:~
 : Returns the minOccurs and maxOccurs values implied by
 : a succinct occurrence descriptor (?, *, +, {i}, {i-j}).
 : The infinity value is represented by -1.
 :
 : @params occDesc a succinct occurrence descriptor, as used
 :     in @z:occ
 : @return minimum and maximum numbers of occurrence implied by 
 :     the occurrence descriptor; a maximum value of infinity
 :     is represented by the value -1
 :)
declare function f:occDesc2OccRange($occDesc as xs:string?)
        as xs:integer+ {
    if (not($occDesc)) then (1, 1) else
    
    let $comps := replace(translate($occDesc, ' ', ''), '^\{|\}$', '')
    return
        switch($comps)
        case '' return (1, 1)
        case '?' return  (0, 1)
        case '*' return (0, -1)
        case '+' return (1, -1)
        default return
            let $limits := tokenize($comps, '-') !
                           (if (. = ('*', 'unbounded')) then -1 else xs:integer(.))
            return (
                $limits,
                if (count($limits) lt 2) then $limits else ()
            )
};

(:~
 : Maps minimum and maximum numbers of occurrence to a succinct
 : occurrence descriptor as used in @z:occ (?, *, +, {i-j}).
 : An input maximum value of -1 is interpreted as infinity.
 :
 : @params minimum and maximum numbers of occurrence
 : @return a succinct occurrence descriptor, as used in @z:occ
 :)
declare function f:occRange2OccDesc($minOccurs as xs:integer, 
                                    $maxOccurs as xs:integer)
        as xs:string {
    switch($maxOccurs)
    case 0 return '{0-0}'
    case 1 return
        switch($minOccurs)
        case 0 return '?'
        case 1 return ''
        default return '{0-0}' 
    case -1 return
        switch($minOccurs)
        case 0 return '*'
        case 1 return '+'
        default return concat($minOccurs, '-*')
    default return concat($minOccurs, '-', $maxOccurs) 
};

(:~
 : Returns the occurrence descriptor capturing the result of 
 : "multiplying" two occurrence descriptors. The minOccurs
 : of the result is the product of the minOccurs values of the
 : input descriptors. Likewise, the maxOccurs of the result is
 : the product of the maxOccurs values of the input descriptors,
 : taking the special value "unbounded" into due account. 
 : 
 : Note. Multiplication is used in two contexts:
 : <ul>
 :   <li>replacing parent/child descriptors by a single descriptor</li>
 :   <li>referencing a definition</li> 
 : </ul>
 : 
 : An example for usecase 1 is the removal of pseudo groups consisting of
 : a single member. An example for usecase 2 is the replacement of
 : a group reference by the group contents.
 :
 : Rules:
 :     minOccurs(left)   = 0  => minOccurs = 0
 :     minOccurs(left)   = 1  => minOccurs = minOccurs(right)
 :     minOccurs(left)   > 1  => minOccurs = minOccurs(right) * minOccurs(left)
 :     maxOccurs(left)   = 0  => maxOccurs = 0
 :     maxOccurs(left)   = 1  => maxOccurs = maxOccurs(right)
 :     maxOccurs(left)   = *  => maxOccurs = *
 :     maxOccurs(right)  = *  => maxOccurs = *
 :     otherwise              => maxOccurs = maxOccurs(right) * maxOccurs(left) 
 :)
declare function f:multiplyOccDesc($lhsOccDesc as xs:string?, 
                                   $rhsOccDesc as xs:string?)
        as xs:string {
    let $lhsRange := f:occDesc2OccRange($lhsOccDesc)
    let $lhsMin := $lhsRange[1]
    let $lhsMax := $lhsRange[2]
    let $rhsRange := f:occDesc2OccRange($rhsOccDesc)    
    let $rhsMin := $rhsRange[1]
    let $rhsMax := $rhsRange[2]
    
    let $min :=
        switch($lhsMin)
        case 0 return 0
        case 1 return $rhsMin
        default return $lhsMin * $rhsMin
    let $max :=
        switch($lhsMax)
        case 0 return 0
        case 1 return $rhsMax
        case -1 return -1
        default return
            if ($rhsMax eq -1) then $rhsMax
            else $lhsMax * $rhsMax
    return
        f:occRange2OccDesc($min, $max)
};

(:~
 : Returns the adapted occurrence descriptor for the single child of a 
 : sequence, choice or all, to be applied after removal of the parent 
 : sequence, choice or all.
 :
 : Rules:
 :     minOccurs(parent) = 0  => new-minOccurs(child) = 0
 :     minOccurs(parent) = 1  => new-minOccurs(child) = minOccurs(child)
 :     minOccurs(parent) > 1  => new-minOccurs(child) = minOccurs(child) * minOccurs(parent)
 :     maxOccurs(parent) = 0  => new-maxOccurs(child) = 0
 :     maxOccurs(parent) = 1  => new-maxOccurs(child) = maxOccurs(child)
 :     maxOccurs(parent) = *  => new-maxOccurs(child) = *
 :     maxOccurs(child)  = *  => new-maxOccurs(child) = *
 :     otherwise              => new-maxOccurs(child) = maxOccurs(child) * maxOccurs(parent) 
 :)
(: 
declare function f:adaptPseudoGroupContentOccDesc($contentOccDesc as xs:string?, 
                                                  $groupOccDesc as xs:string?)
        as xs:string {
    let $contentRange := f:occDesc2OccRange($contentOccDesc)
    let $groupRange := f:occDesc2OccRange($groupOccDesc)
    let $groupMin := $groupRange[1]
    let $groupMax := $groupRange[2]
    let $contentMin := $contentRange[1]
    let $contentMax := $contentRange[2]
    
    let $newContentMin :=
        switch($groupMin)
        case 0 return 0
        case 1 return $contentMin
        default return $groupMin * $contentMin
    let $newContentMax :=
        switch($groupMax)
        case 0 return 0
        case 1 return $contentMax
        case -1 return -1
        default return
            if ($contentMax eq -1) then $contentMax
            else $groupMax * $contentMax
    return
        f:occRange2OccDesc($newContentMin, $newContentMax)
};
:)

(:~
 : Edits an occurrence descriptor, returning a descriptor
 : obtained after changing minOccurs to 0.
 :
 : @param occDesc the occurrence descriptor
 : @return the edited occurrence descriptor
 :)
declare function f:editOccDescMinOccurs0($occDesc as xs:string?) 
        as xs:string {
    if (not($occDesc) or $occDesc eq '{1}') then '?'
    else
        let $occRange := f:occDesc2OccRange($occDesc)
        return
            f:occRange2OccDesc(0, $occRange[2])
};

(:~
 : Returns a copy of an element with the value or absence of an 'z:occ'
 : attribute reflecting the value of the occurrence descriptor provided.
 :
 : If 'occDesc' is not set, the updated element has no 'z:occ' attribute.
 : If 'occDesc' is set, the updated element has an 'z:occ' attribute
 : with a value equal 'occDesc'.
 :
 : If 'occDesc' is set and the element already has an 'z:occ' attribute,
 : the updated attribute has the same position among the other
 : attributes as the origial attribute.
 :
 : @param item the element to be updated
 : @param occDesc an occurrence descriptor
 : @return an updated copy of the element
 :)
declare function f:updateOccAtt($item as element(), $occDesc as xs:string?)
        as element() {
    let $occAtt := $occDesc[string()] ! attribute z:occ {.}        
    return
        element {node-name($item)} {
            for $a in $item/@*
            return (
                typeswitch($a)
                case attribute(z:occ) return $occAtt
                default return $a),
            if ($occAtt and not($item/@z:occ)) then $occAtt else (),
            $item/node()
        }        
};        
