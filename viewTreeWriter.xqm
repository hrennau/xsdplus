(:
 : -------------------------------------------------------------------------
 :
 : viewTreeWriter.xqm - operation and public functions writing view trees
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="vtree" type="node()" func="vtreeOp">
         <param name="attRep" type="xs:string?" default="elem" fct_values="att, elem, elemSorted"/>      
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="gnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="true"/>         
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
         <param name="sortAtts" type="xs:boolean?" default="false"/>
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
    "locationTreeComponents.xqm",
    "occUtilities.xqm";
    
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
 : Implements operation `vtree`.
 :
 : @param request the operation request
 : @return a report containing base tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:vtreeOp($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $enames := tt:getParam($request, 'enames')
    let $tnames := tt:getParam($request, 'tnames')    
    let $gnames := tt:getParam($request, 'gnames')  
    let $global := tt:getParam($request, 'global')    
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $groupNorm := trace(tt:getParam($request, 'groupNormalization') , 'GROUP NORMALIZATION: ')
    let $attRep := tt:getParam($request, 'attRep')    
    
    let $options :=
        <options withStypeTrees="false" attRep="{$attRep}"/>
    
    let $ltree := f:ltree($enames, $tnames, $gnames, $global, $options, 
                          $groupNorm, $nsmap, $schemas)
    let $vtree := f:ltree2Vtree($ltree, $options)                          
    return
        $vtree
};

(:~
 : Transforms a location tree into a view tree.
 :
 : @param ltree a location tree
 : @param options options controlling the view tree construction
 : @return a view tree
 :)
declare function f:ltree2Vtree($ltree as element(), $options as element(options))
        as element() {
    if ($ltree/self::zz:baseTrees) then app:btree2Vtree($ltree, $options) else
    
    f:ltree2VtreeRC($ltree, $options)        
};

(:~
 : Recursive helper function of `ltree2Vtree`.
 :)
declare function f:ltree2VtreeRC($n as node(), $options as element(options))
        as node()* {
    typeswitch($n)
    
    case element(z:locationTrees) return
        <z:trees>{
            for $a in $n/@* return f:ltree2VtreeRC($a, $options),
            for $c in $n/node() return f:ltree2VtreeRC($c, $options)
        }</z:trees>
        
    case element(z:locationTree) return
        let $content := (
            for $a in $n/@* return f:ltree2VtreeRC($a, $options),
            for $c in $n/node() return f:ltree2VtreeRC($c, $options)
        )
        let $nsPrefixes := in-scope-prefixes($content)
        let $nsNodes :=
            for $p in $nsPrefixes return namespace {$p} {namespace-uri-for-prefix($p, $content)}
        return
            <z:tree>{
                $nsNodes,
                $content
            }</z:tree>

    case element(z:_stypeTree_) return ()
    
    case element(z:_sequence_) | element(z:_choice_) | element(z:_all_) return
        element {node-name($n)} {
            for $a in $n/@* return f:ltree2VtreeRC($a, $options),
            for $c in $n/node() return f:ltree2VtreeRC($c, $options)
        }

    case element(z:_attributes_) return f:ltree2VtreeRC_attributes($n, $options)
(:
    case element(z:_attribute_) return
        element {node-name($n)} {
            for $a in $n/@* return f:ltree2VtreeRC($a, $options),
            for $c in $n/node() return f:ltree2VtreeRC($c, $options)
        }

    case element(z:_attribute_) return
        element {node-name($n)} {
            for $a in $n/@* return f:ltree2VtreeRC($a, $options),
            for $c in $n/node() return f:ltree2VtreeRC($c, $options)
        }
:)
    case element(z:nsMap) return ()
    
    case element() return
        let $content := (
            for $a in $n/@* return f:ltree2VtreeRC($a, $options),
            if ($n/z:_groupContent_/@z:groupRecursion) then (
                $n/z:_groupContent_/@z:groupRecursion,
                $n/z:_groupContent_/@z:occ/attribute groupOcc {.}
            ) else
                for $c in $n/node() return f:ltree2VtreeRC($c, $options)
        )
        let $contentAtts := $content[self::attribute()]
        return
            element {node-name($n)} {
                $contentAtts,
                $content except $contentAtts
            }
        
    case attribute(z:name) return
        if ($n/parent::z:_attribute_) then attribute name {$n}
        else ()
        
    case attribute(z:occ) return
        attribute occ {$n}

    case attribute(z:typeRecursion) return
        attribute typeRecursion {$n}

    case attribute(z:groupRecursion) return
        attribute groupRecursion {$n}

    case attribute() return ()
    default return $n

};

(:~
 : Helper function of `ltree2VtreeRC`, processing a source node "z:_attributes_".
 :)
declare function f:ltree2VtreeRC_attributes($n as element(z:_attributes_), $options as element(options))
        as node()* {
    let $sourceAtts :=
        if ($options/@attRep eq 'att' or 
                $options/@attRep eq 'elemSorted') then
            for $a in $n/*
            order by $a/@z:name/lower-case(replace(., '.*:', '')), $a/@z:name/lower-case(.)
            return $a
        else $n/*
    return            
        if ($options/@attRep eq 'att') then
            let $items :=
                for $s in $sourceAtts
                let $postFix := if ($s/@default) then concat('=', $s/@default)
                                else if ($s/@fixed) then concat('!=', $s/@fixed)
                                else if ($s/@required) then ()
                                else '?'
                return
                    concat($s/@z:name, $postFix)
                let $itemsConcat := string-join($items, ', ')
                return
                    attribute atts {$itemsConcat}
            else    
                let $content :=
                    for $s in $sourceAtts return f:ltree2VtreeRC($s, $options)
                return        
                    element {node-name($n)} {
                        for $a in $n/@* return f:ltree2VtreeRC($a, $options),
                        $content
                    }        
};        

