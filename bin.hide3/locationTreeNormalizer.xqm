(:
 : -------------------------------------------------------------------------
 :
 : locationTreeNormalizer.xqm - normalizes location trees
 :
 : -------------------------------------------------------------------------
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
    "locationTreeComponents.xqm",
    "occUtilities.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.xsdr.org/ns/structure";
declare namespace ns0="http://www.xsdr.org/ns/structure";

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Normalizes a location tree by removing unnecessary groupings.
 :
 : Rules
 : =====
 : (1) pseudo_group
 : Target: group descriptor (z:_sequence_, z:_choice_, z:_all_)
 : Condition:
 :   Target has a single child
 : Action:
 :   "Unwrap" the target, replacing it by its children with adapted cardinalities.
 :   Adaptation: for each child the original minOccurs (maxOccurs) values is replaced by 
 :   the product of child and parent minOccurs (maxOccurs) values. 
 :
 :   Special rules for the multiplication of 'unbounded' constraint values: 
 :   if the other factor is 0, the product is 0, otherwise 'unbounded'.
 :
 : (2) implicit_sequence
 : Target: z:_sequence_
 : Condition: 
 :   minOccurs(target) = 1
 :   maxOccurs(target) = 1
 :   parent(target) != z:_choice_, != z:_all_
 : Action:
 :   "Unwrap" the target, replacing it by its children.
 :
 : (3) choice_in_choice
 : Target: z:_choice_
 : Condition:
 :   parent(target)      = z:_choice_
 :   maxOccurs(target)   = 1
 : Action:
 :   "Unwrap" the target, replacing it by its children with adapted cardinalities.
 :   Adaptation: if minOccurs(target) is 0, the minOccurs values of all children are
 :   set to 0, otherwise they remaind unchanged.
 :)
declare function f:normalizeLtree($ltree as element(), $groupNorm as xs:integer?)
        as element() {
    let $tree := $ltree
    
    let $tree := 
        if ($groupNorm le 0) then $tree else f:normalizeLtree_pseudoGroupRC($tree)       
    let $tree := 
        if ($groupNorm le 1) then $tree else f:normalizeLtree_choiceInChoiceRC($tree)
    let $tree := 
        if ($groupNorm le 2) then $tree else f:normalizeLtree_defaultSequenceRC($tree)
    let $tree := 
        if ($groupNorm le 3) then $tree else f:normalizeLtree_optionalSequenceRC($tree)
    return $tree
};        

(:~
 : Performs a location tree normalizing step: unwrap all pseudo-groups.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeLtree_pseudoGroupRC($n as node())
        as node()* {
    typeswitch($n)

    case element(z:_sequence_) | element(z:_choice_) | element(z:_all_) return
        let $contents := for $c in $n/* return f:normalizeLtree_pseudoGroupRC($c)
        return
            (: case: not a pseudo group :)
            if (count($contents) ne 1) then
                element {node-name($n)} {
                    for $a in $n/@* return f:normalizeLtree_pseudoGroupRC($a),
                    $contents
                } 
            (: case: pseudo group :)
            else 
                let $occDesc := f:multiplyOccDesc($contents/@z:occ, $n/@z:occ)                
                let $atts :=
                    if (not($occDesc)) then $contents/@*[not(self::attribute(z:occ))]
                    else if ($contents/@z:occ eq $occDesc) then $contents/@*
                    else
                        let $occAtt := attribute z:occ {$occDesc}
                        return
                            if ($contents/@z:occ) then
                                for $a in $contents/@* return
                                    ($a/self::attribute(z:occ)/$occAtt, $a)[1]
                            else ($occAtt, $contents/@*)
                return
                    element {node-name($contents)} {
                        $atts,
                        $contents/node()
                    }
                
    case element() return
        element {node-name($n)} {
            for $i in $n/(@*, node()) return
                f:normalizeLtree_pseudoGroupRC($i)
        }                
    default return $n                
};

(:~
 : Performs a location tree normalizing step: unwrap all choices in
 : choices, where the inner group has a maximum number of occurrences
 : equal one.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeLtree_choiceInChoiceRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(z:_choice_) return
        (: rawRontents - contents obtained when not unwrapping nested choice groups :)
        let $rawContents := $n/* ! f:normalizeLtree_choiceInChoiceRC(.)
            
        (: contents - contents obtained when unwrapping any nested choice groups :)
        let $contents := 
            if (not($rawContents/self::z:_choice_)) then $rawContents else
            
            (: each item of raw contents is either kept or unwrapped :)
            for $c in $rawContents
                
            (: branch not a choice :)
            return if (not($c/self::z:_choice_)) then $c else
 
            (: maxOccurs not 1 :)
            let $childOccRange := app:occDesc2OccRange($c/@z:occ)                
            return if ($childOccRange[2] gt 1) then $c else

            (: nestedBranchesRaw - branches obtained when not adapting minOccurs
               to the minOccurs of the inner choice element :)
            let $nestedBranchesRaw := $c/*
                    
            (: nestedBranches - the result of editing the raw branches, adapting
               occurrences, when necessary :)
            let $nestedBranches :=
                (: if the nested choice has minOccurs=1, addition/adaption of
                       occurrence descriptors is not necessary :)
                if ($childOccRange[1] eq 1) then $nestedBranchesRaw else

                (: add or adapt occurrence descriptor :)
                for $b in $nestedBranchesRaw
                let $atts :=
                    if (not($b/@z:occ)) then (attribute z:occ {'?'}, $b/@*)
                    else
                        for $a in $b/@* return
                            typeswitch($a)
                            case attribute(z:occ) return 
                                attribute z:occ {app:editOccDescMinOccurs0($a)}
                            default return $a
                return
                    element {node-name($b)} {$atts, $b/node()}
            return
                $nestedBranches
        return
            element {node-name($n)} {
                for $a in $n/@* return f:normalizeLtree_choiceInChoiceRC($a),
                $contents
            }
            
    case element() return
        element {node-name($n)} {
            for $i in $n/(@*, node()) return
                f:normalizeLtree_choiceInChoiceRC($i)
        }                
    default return $n                
};

(:~
 : Performs a location tree normalizing step: unwrap all sequences with
 : an occurrence equal one and not child of z:_choice_ or z:_all_.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeLtree_defaultSequenceRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(z:_sequence_) return
        let $occRange := app:occDesc2OccRange($n/@z:occ)
        let $contents :=
            for $c in $n/node() return f:normalizeLtree_defaultSequenceRC($c)
        return
            if ($occRange[1] eq 1 and $occRange[2] eq 1 
                and not($n/parent::z:_choice_) 
                and not($n/parent::z:_all_))
            then
                $contents
            else
                element {node-name($n)} {
                    for $a in $n/@* return f:normalizeLtree_defaultSequenceRC($a),
                    $contents
                }
            
    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:normalizeLtree_defaultSequenceRC($a),        
            for $c in $n/node() return f:normalizeLtree_defaultSequenceRC($c)            
        }
        
    default return $n
};

(:~
 : Performs a location tree normalizing step: unwrap z:_sequence_ with
 : minOccurs = 0 and maxOccurs = 1. Unwrapping is only performed if
 : all children of the sequence have minOccurs equal 0.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeLtree_optionalSequenceRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(z:_sequence_) return
        let $occRange := app:occDesc2OccRange($n/@z:occ)
        let $contents := $n/node() ! f:normalizeLtree_optionalSequenceRC(.)
        return
            if ($occRange[1] eq 0 and $occRange[2] eq 1
                and not($n/parent::z:_choice_) 
                and not($n/parent::z:_all_)
                and (every $i in $contents satisfies app:occDesc2OccRange($i/@z:occ)[1] eq 0)
                )
            then $contents
            else (
                element {node-name($n)} {
                    for $a in $n/@* return f:normalizeLtree_optionalSequenceRC($a),
                    $contents
                }
            )
            
    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:normalizeLtree_optionalSequenceRC($a),        
            for $c in $n/node() return f:normalizeLtree_optionalSequenceRC($c)            
        }
        
    default return $n
};

(:
 : ============================================================================
 :
 :     p r i v a t e     f u n c t i o n s
 :
 : ============================================================================
 :)

