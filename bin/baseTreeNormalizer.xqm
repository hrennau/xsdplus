(:
 : -------------------------------------------------------------------------
 :
 : baseTreeNormalizer.xqm - operation and function normalizing base trees
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="normBtree" type="node()" func="normBtreeOp">
         <param name="btree" type="docFOX"/> 
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>         
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
    "occUtilities.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.xsdr.org/ns/structure";
declare namespace ns0="http://www.xsdr.org/ns/structure";
declare namespace c="http://www.xsdplus.org/ns/xquery-functions";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `normBtree`.
 :
 : @param request the operation request
 : @return a report containing base tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:normBtreeOp($request as element())
        as element() {
    let $btree := tt:getParam($request, 'btree')/*
    let $groupNormalization := trace(tt:getParam($request, 'groupNormalization') , 'BTREE GROUP NORMALIZATION: ') 
    
    let $btreeNorm := f:removeComments($btree)
    let $btreeNorm := f:normalizeBtree($btreeNorm, $groupNormalization)    
    return
        $btreeNorm
};

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Edits an XML node, removing all comment nodes.
 :)
declare function f:removeComments($n as node()) as node()? {
    typeswitch($n)
    case document-node() return
        document {for $c in $n/node() return f:removeComments($c)}
        
    case element() return
        element {node-name($n)} {
            for $i in $n/(@*, node()) return f:removeComments($i)            
        }
    case comment() return ()
    default return $n
};

(:~
 : Normalizes a base tree by removing unnecessary groupings.
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
declare function f:normalizeBtree($btree as element(), $groupNorm as xs:integer?)
        as element() {
    let $tree := $btree
    
    let $tree := 
        if ($groupNorm le 0) then $tree else f:normalizeBtree_pseudoGroupRC($tree)       
    let $tree := 
        if ($groupNorm le 1) then $tree else f:normalizeBtree_choiceInChoiceRC($tree)
    let $tree := 
        if ($groupNorm le 2) then $tree else f:normalizeBtree_defaultSequenceRC($tree)
    let $tree := 
        if ($groupNorm le 3) then $tree else f:normalizeBtree_optionalSequenceRC($tree)
    return $tree
};        

(:~
 : Performs a base tree normalizing step: unwrap all pseudo-groups.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeBtree_pseudoGroupRC($n as node())
        as node()* {
    typeswitch($n)
    case element(zz:_sequence_) | element(zz:_choice_) | element(zz:_all_) return
        let $contents := for $c in $n/* return f:normalizeBtree_pseudoGroupRC($c)
        return
            (: case: not a pseudo group :)
            if (count($contents) ne 1) then
                element {node-name($n)} {
                    for $a in $n/@* return f:normalizeBtree_pseudoGroupRC($a),
                    $contents
                } 
            (: case: pseudo group :)
            else 
                let $occDesc := f:multiplyOccDesc($contents/@zz:occ, $n/@zz:occ)                
                let $atts :=
                    if (not($occDesc)) then $contents/@*[not(self::attribute(zz:occ))]
                    else if ($contents/@zz:occ eq $occDesc) then $contents/@*
                    else
                        let $occAtt := attribute {QName($c:URI_BTREE, 'z:occ')} {$occDesc}
                        return
                            if ($contents/@zz:occ) then
                                for $a in $contents/@* return
                                    ($a/self::attribute(zz:occ)/$occAtt, $a)[1]
                            else ($occAtt, $contents/@*)
                return
                    element {node-name($contents)} {
                        $atts,
                        $contents/node()
                    }
                
    case element() return
        element {node-name($n)} {
            for $i in $n/(@*, node()) return
                f:normalizeBtree_pseudoGroupRC($i)
        }                
    default return $n                
};

(:~
 : Performs a base tree normalizing step: unwrap all choices in
 : choices, where the outer group has a maximum number of occurrences
 : equal one.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeBtree_choiceInChoiceRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(zz:_choice_) return
        (: rawRontents - contents obtained when not unwrapping nested choice groups :)
        let $rawContents :=
            for $c in $n/* return f:normalizeBtree_choiceInChoiceRC($c)
            
        (: contents - contents obtained when unwrapping any nested choice groups :)
        let $contents := 
            if (not($rawContents/self::zz:_choice_)) then $rawContents else
            
            (: each item of raw contents is either kept or unwrapped :)
            for $c in $rawContents
                
            (: branch not a choice :)
            return if (not($c/self::zz:_choice_)) then $c else
 
            (: maxOccurs not 1 :)
            let $childOccRange := app:occDesc2OccRange($c/@zz:occ)                
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
                    if (not($b/@zz:occ)) then 
                        (attribute {QName($c:URI_BTREE, 'z:occ')} {'?'}, $b/@*)
                    else
                        for $a in $b/@* 
                        return
                            typeswitch($a)
                            case attribute(zz:occ) return 
                                attribute {QName($c:URI_BTREE, 'z:occ')} {app:editOccDescMinOccurs0($a)}
                            default return $a
                return
                    element {node-name($b)} {$atts, $b/node()}
            return
                $nestedBranches
        return
            element {node-name($n)} {
                for $a in $n/@* return f:normalizeBtree_choiceInChoiceRC($a),
                $contents
            }
            
    case element() return
        let $content :=
            for $i in $n/(@*, node()) return
                f:normalizeBtree_choiceInChoiceRC($i)
        let $contentAtts := $content[self::attribute()]
        return
            element {node-name($n)} {
                $contentAtts,
                $content except $contentAtts
            }                
    default return $n                
};

(:~
 : Performs a base tree normalizing step: unwrap all sequences with
 : an occurrence equal one and not child of z:_choice_ or z:_all_.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeBtree_defaultSequenceRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(zz:_sequence_) return
        let $occRange := app:occDesc2OccRange($n/@zz:occ)
        let $contents :=
            for $c in $n/node() return f:normalizeBtree_defaultSequenceRC($c)
        return
            if ($occRange[1] eq 1 and $occRange[2] eq 1 
                and not($n/parent::zz:_choice_) 
                and not($n/parent::zz:_all_))
            then
                $contents
            else
                element {node-name($n)} {
                    for $a in $n/@* return f:normalizeBtree_defaultSequenceRC($a),
                    $contents
                }
            
    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:normalizeBtree_defaultSequenceRC($a),        
            for $c in $n/node() return f:normalizeBtree_defaultSequenceRC($c)            
        }
        
    default return $n
};

(:~
 : Performs a base tree normalizing step: unwrap all sequence with
 : minOccurs = 0 and maxOccurs = 1. Note that this step means a distortion
 : of the original model. It is only used for test and comparison purposes.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:normalizeBtree_optionalSequenceRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(zz:_sequence_) return
        let $occRange := app:occDesc2OccRange($n/@zz:occ)
        let $contents := $n/node() ! f:normalizeBtree_optionalSequenceRC(.)
        return
            if ($occRange[1] eq 0 and $occRange[2] eq 1
                and not($n/parent::zz:_choice_) 
                and not($n/parent::zz:_all_)
                and (every $i in $contents satisfies app:occDesc2OccRange($i/@zz:occ)[1] eq 0)
                )
            then $contents
            else (
                element {node-name($n)} {
                    for $a in $n/@* return f:normalizeBtree_optionalSequenceRC($a),
                    $contents
                }
            )
            
    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:normalizeBtree_optionalSequenceRC($a),        
            for $c in $n/node() return f:normalizeBtree_optionalSequenceRC($c)            
        }
        
    default return $n
};
