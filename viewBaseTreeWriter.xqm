(:
 : -------------------------------------------------------------------------
 :
 : locationTreeWriter.xqm - operation and functions writing location trees
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="vbtree" type="node()" func="vbtreeOp">
         <param name="attRep" type="xs:string?" default="elem" fct_values="att, elem, elemSorted"/>      
         <param name="btree" type="docFOX"/> 
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>         
         <param name="sortAtts" type="xs:boolean?" default="false"/>         
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
    "baseTreeNormalizer.xqm",
    "constants.xqm",
    "locationTreeComponents.xqm",
    "occUtilities.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.xsdr.org/ns/structure";
declare namespace c="http://www.xsdplus.org/ns/xquery-functions";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `vbtree`. The operation transforms a base tree
 : into a view tree.
 :
 : @param request the operation request
 : @return a report containing base tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:vbtreeOp($request as element())
        as element() {
    let $btree := tt:getParam($request, 'btree')/*
    let $attRep := tt:getParam($request, 'attRep')  
    let $groupNorm := trace(tt:getParam($request, 'groupNormalization') , 'BTREE GROUP NORMALIZATION: ')
    
    let $btreeNorm := app:normalizeBtree($btree, $groupNorm)    
    let $options := <options attRep="{$attRep}"/>
    let $vtree := f:btree2Vtree($btreeNorm, $options)                          
    return
        $vtree
};

(:~
 : Transforms a base tree into a view tree.
 :
 : @param btree a base tree
 : @param options options controlling the processing
 : @return a view tree
 :)
declare function f:btree2Vtree($btree as element(), $options as element(options))
        as element() {
    f:btree2VtreeRC($btree, $options)
};

(:~
 : Recursive helper function of `btree2Vtree`.
 :
 : @param n the base tree node currently processed
 : @return result of processing the node
 :)
declare function f:btree2VtreeRC($n as node(), $options as element(options))
        as node()* {
    typeswitch($n)
    
    case element(zz:baseTrees) return
        <z:trees xmlns:z="http://www.xsdplus.org/ns/structure">{
            for $a in $n/@* return f:btree2VtreeRC($a, $options),
            for $c in $n/node() return f:btree2VtreeRC($c, $options)
        }</z:trees>
        
    case element(zz:baseTree) return
        let $content := (
            for $a in $n/@* return f:btree2VtreeRC($a, $options),
            for $c in $n/node() return f:btree2VtreeRC($c, $options)
        )
        let $root := $content[self::element()][1]
        let $nsPrefixes := in-scope-prefixes($root)
        let $nsNodes :=
            for $p in $nsPrefixes return namespace {$p} {namespace-uri-for-prefix($p, $root)}
        return    
            <z:tree>{
                $nsNodes,
                $content
            }</z:tree>

    case element(zz:_sequence_) | element(zz:_choice_) | element(zz:_all_) return
        element {f:xsdplusName(node-name($n))} {
            for $a in $n/@* return f:btree2VtreeRC($a, $options),
            for $c in $n/node() return f:btree2VtreeRC($c, $options)
        }

    case element(zz:_attributes_) return f:btree2VtreeRC_attributes($n, $options)
    
    case element(zz:_attribute_) return
        element {f:xsdplusName(node-name($n))} {
            for $a in $n/@* return f:btree2VtreeRC($a, $options),
            if ($n/@use eq 'required') then () 
                else attribute occ {'?'},
            for $c in $n/node() return f:btree2VtreeRC($c, $options)            
        }

    case element(zz:nsMap) return ()
    
    case element() return
        let $content := (
            for $a in $n/@* return f:btree2VtreeRC($a, $options),
            for $c in $n/node() return f:btree2VtreeRC($c, $options)
        )        
        let $contentAtts := $content[self::attribute()]
        return
            element {f:xsdplusName(node-name($n))} {
                $contentAtts,
                $content except $contentAtts
            }
        
    case attribute(zz:name) return
        if ($n/parent::zz:_attribute_) then attribute name {$n}
        else ()
        
    case attribute(zz:occ) return attribute occ {$n}        
    case attribute() return ()    
    case comment() return ()    
    default return $n

};  

(:~
 : Helper function of `btree2VtreeRC`, processing a source node "z:_attributes_".
 :)
declare function f:btree2VtreeRC_attributes($n as element(zz:_attributes_), $options as element(options))
        as node()* {
    let $sourceAtts :=
        if ($options/@attRep eq 'att' or 
                $options/@attRep eq 'elemSorted') then
            for $a in $n/zz:_attribute_
            order by $a/@zz:name/lower-case(replace(., '.*:', '')), $a/@zz:name/lower-case(.)
            return $a
        else $n/zz:_attribute_
    return            
        if ($options/@attRep eq 'att') then
            let $items :=
                for $s in $sourceAtts
                let $postFix := if ($s/@default) then concat('=', $s/@default)
                                else if ($s/@fixed) then concat('!=', $s/@fixed)
                                else if ($s/@required) then ()
                                else '?'
                return
                    concat($s/@zz:name, $postFix)
                let $itemsConcat := string-join($items, ', ')
                return
                    attribute atts {$itemsConcat}
            else    
                let $content :=
                    for $s in $sourceAtts return f:btree2VtreeRC($s, $options)
                return        
                    element {node-name($n)} {
                        for $a in $n/@* return f:btree2VtreeRC($a, $options),
                        $content
                    }        
};        

(:~
 : Transforms names from the base tree namespace into the location tree namespace.
 : Names not in the base tree namespace are returned unchanged.
 :
 : @param qname a qualified name
 : @return the transformed name
 :)
declare function f:xsdplusName($qname as xs:QName)
        as xs:QName {
    if (namespace-uri-from-QName($qname) eq $c:URI_BTREE) then        
        QName($c:URI_LTREE, concat('z:', local-name-from-QName($qname)))
    else
        $qname
};        



