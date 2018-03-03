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
         <param name="attRep" type="xs:string?" default="elem" fct_values="att, count, elem, elemSorted"/>      
         <param name="collapseElems" type="nameFilter?"/>
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="gnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="true"/>         
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
         <param name="noprefix" type="xs:boolean?" default="false"/>
         <param name="sgroupStyle" type="xs:string?" default="ignore" fct_values="expand, compact, ignore"/>         
         <param name="sortAtts" type="xs:boolean?" default="false"/>
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="ltree" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
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
    "occUtilities.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";
declare namespace z2="http://www.xsdr.org/ns/structure";
declare namespace ns0="http://www.xsdr.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `vtree`. Creations a view tree.
 :
 : @param request the operation request
 : @return a report containing base tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:vtreeOp($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $ltree := tt:getParam($request, 'ltree')/*
    let $enames := tt:getParam($request, 'enames')
    let $tnames := tt:getParam($request, 'tnames')    
    let $gnames := tt:getParam($request, 'gnames')  
    let $global := tt:getParam($request, 'global')    
    let $noprefix := tt:getParam($request, 'noprefix')
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $groupNorm := tt:getParam($request, 'groupNormalization')
    let $sgroupStyle := tt:getParam($request, 'sgroupStyle')    
    let $attRep := tt:getParam($request, 'attRep')    
    let $collapseElems := tt:getParam($request, 'collapseElems')
    
    let $options :=
        <options withStypeTrees="false" 
                 attRep="{$attRep}" 
                 noprefix="{$noprefix}"
                 sgroupStyle="{$sgroupStyle}">{
            <collapseElems>{
                $collapseElems
            }</collapseElems>                 
        }</options>
    
    let $ltree := 
        if ($ltree) then $ltree
        else
            f:ltree($enames, $tnames, $gnames, $global, $options, 
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
    if ($ltree/self::z2:baseTrees) then app:btree2Vtree($ltree, $options) else
    
    let $raw := f:ltree2VtreeRC($ltree, $options)
    return
        let $noprefix := $options/@noprefix/xs:boolean(.)
        return
            if ($noprefix) then f:vtree_stripPrefixes($raw)
            else $raw
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
        let $nsPrefixes := in-scope-prefixes($n)
        let $nsNodes :=
            for $p in $nsPrefixes return namespace {$p} {namespace-uri-for-prefix($p, $n)}
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
    case element(z:_annotation_) return ()
    case element(zz:nsMap) return ()
    
    case element() return
        let $content := (
            for $a in $n/@* return f:ltree2VtreeRC($a, $options),
            if ($n/z:_groupContent_/@z:groupRecursion) then (
                $n/z:_groupContent_/@z:groupRecursion/attribute __groupRecursion__ {.},
                $n/z:_groupContent_/@z:occ/attribute __groupOcc__ {.}
            ) else if ($n/@z:elemRecursion) then (
                $n/@z:elemRecursion/attribute __elemRecursion__ {name($n)}
            ) else
                let $collapse :=
                    let $collapseElems := $options/collapseElems/*
                    return
                        if (not($collapseElems)) then ()
                        else
                            let $lname := local-name($n)
                            return
                                tt:matchesNameFilter($lname, $collapseElems)
                return
                    if ($collapse) then
                        attribute __collapsed__ {'true'}
                    else
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
        else if ($options/@attRep eq 'count') then
            attribute countAtts {count($sourceAtts)} [$sourceAtts]
        else    
            let $content :=
                for $s in $sourceAtts return f:ltree2VtreeRC($s, $options)
            return        
                element {node-name($n)} {
                    for $a in $n/@* return f:ltree2VtreeRC($a, $options),
                    $content
                }        
};        

(:~
 : Creates a copy of a collection of view trees with all non-z prefixes removed.
 :)
declare function f:vtree_stripPrefixes($trees as element(z:trees))
        as element(z:trees) {
    f:vtree_stripPrefixesRC($trees)
};

(:~
 : Recursive helper fnction of 'vtree_stripPrefixes'.
 :)
declare function f:vtree_stripPrefixesRC($n as node())
        as node() {
    typeswitch($n)
    case document-node() return
        document {for $c in $n/node() return f:vtree_stripPrefixesRC($c)}
    case element() return
        let $ns := namespace-uri($n)
        let $useNs := $ns[. eq $app:URI_LTREE]
        let $useLname := string-join(('z'[$ns eq $app:URI_LTREE], local-name($n)), ':')
        return
            element {QName($useNs, $useLname)} {
                for $a in $n/@* return f:vtree_stripPrefixesRC($a),
                for $c in $n/node() return f:vtree_stripPrefixesRC($c)
            }
    default return $n            
};


