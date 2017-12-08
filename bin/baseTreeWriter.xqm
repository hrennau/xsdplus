(:
 : -------------------------------------------------------------------------
 :
 : locationTreeWriter.xqm - operation which writes location trees
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="btree" type="node()" func="btreeOp">
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="gnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="false"/>   
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
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
    "locationTreeWriter.xqm",
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
 : Implements operation `btree`.
 :
 : @param request the operation request
 : @return a report containing base tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:btreeOp($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $enames := tt:getParam($request, 'enames')
    let $tnames := tt:getParam($request, 'tnames')    
    let $gnames := tt:getParam($request, 'gnames')  
    let $global := tt:getParam($request, 'global')    
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $groupNorm := trace(tt:getParam($request, 'groupNormalization') , 'GROUP_NORM: ')    
    let $options :=
        <options withStypeTrees="false" sgroupStyle="ignore"/>
    
    let $ltreeReport := f:ltree($enames, $tnames, $gnames, $global, $options, 
                                $groupNorm, $nsmap, $schemas)
    let $btreeReport := f:ltrees2Btrees($ltreeReport)
    return
        app:addNSBs($btreeReport, $nsmap)
};     

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Transforms location trees into the legacy base tree format.
 :
 : @param ltrees location trees document
 : @return a base trees document
 :)
declare function f:ltrees2Btrees($ltrees as element(z:locationTrees))
        as element(zz:baseTrees) {
    let $btrees := f:ltrees2BtreesRC($ltrees)   
    return
        $btrees
};

(:~
 : Recursive helper function of `f:ltrees2Btrees`.
 :
 : @param n a node visited during recursive processing
 : @return the base tree version of that node
 :)
declare function f:ltrees2BtreesRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(z:locationTrees) return
        element {QName($app:URI_BTREE, 'z:baseTrees')} {
            for $a in $n/(@* except @format) return f:ltrees2BtreesRC($a),
            attribute format {'baseTree'},
            for $c in $n/node() return f:ltrees2BtreesRC($c)            
        }
        
    case element(z:locationTree) return
        element {QName($app:URI_BTREE, 'z:baseTree')} {
            for $c in $n/node() return f:ltrees2BtreesRC($c)          
        }

    case element(z:_stypeTree_) return ()
    
    case element() return
        let $addAttributes :=
            if ($n/self::z:nsMap) then ()
            else if ($n/parent::z:locationTree) then (
                attribute {QName($app:URI_BTREE, 'z:format')} {"baseTree"},
                attribute name {$n/@z:name},                
                
                let $compKind := $n/../@compKind
                let $typeQName := $n/@z:type/resolve-QName(., ..)
                let $typeName := local-name-from-QName($typeQName)
                let $typeNamespace := namespace-uri-from-QName($typeQName)[not(. eq $app:URI_LTREE)]
                return (
                    attribute {QName($app:URI_BTREE, 'z:norepeat')} {-1},
                    if ($compKind eq 'elem') then (
                        attribute {QName($app:URI_BTREE, 'z:treeSourceElem')} {name($n)},                    
                        attribute {QName($app:URI_BTREE, 'z:treeSourceElemName')} {local-name($n)},
                        attribute {QName($app:URI_BTREE, 'z:treeSourceElemNamespace')} {namespace-uri($n)}                    
                    ) else (),
                    if ($compKind ne 'group') then (
                        attribute {QName($app:URI_BTREE, 'z:treeSourceType')} {$n/@z:type/replace(., 'z:', '')},
                        attribute {QName($app:URI_BTREE, 'z:treeSourceTypeName')} {$typeName},                    
                        attribute {QName($app:URI_BTREE, 'z:treeSourceTypeNamespace')} {$typeNamespace}                        
                    ) else ()
                )
            ) else ()
        let $elemName :=
            if (namespace-uri($n) eq $app:URI_LTREE) then
                QName($app:URI_BTREE, concat('z:', local-name($n)))
            else if ($n/parent::z:_attributes_) then QName($app:URI_BTREE, 'z:_attribute_')
            else node-name($n)
        return
            element {$elemName} {
                for $a in $n/@* return f:ltrees2BtreesRC($a),
                $addAttributes,
                for $c in $n/node() return f:ltrees2BtreesRC($c)          
            }

    case attribute(z:baseType) return
        if ($n/../z:type eq 'z:_LOCAL_') then 
            attribute {QName($app:URI_BTREE, 'z:baseTypeName')} {$n}
        else ()

    case attribute(z:builtinBaseType) return
        attribute {QName($app:URI_BTREE, 'z:builtinBaseType')} {$n}

    case attribute(z:occ) return
        attribute {QName($app:URI_BTREE, 'ns0:occ')} {$n}

    case attribute(z:derivationKind) return ()

    case attribute(uri) return
        if ($n eq 'http://www.xsdplus.org/ns/structure') then
            attribute {node-name($n)} {'http://www.xsdr.org/ns/structure'}
        else $n
        
    case attribute() return
        if (namespace-uri($n) eq $app:URI_LTREE) then
            attribute {QName($app:URI_BTREE, concat('z:', local-name($n)))} {$n}
        else $n
    default return $n       
};

(:
(:~
 : Performs a location tree finalizing step: unwrap all sequences with
 : an occurrence equal one and not child of z:_choice_ or z:_all_.
 :
 : @param n the current node
 : @return the result of processing the current node
 :)
declare function f:ltrees2Btrees_adhocRC($n as node())
        as node()* {
    typeswitch($n)
    
    case element(zz:_choice_) return
        if ($n/parent::*:IncludeAppliedDescendants) then
            <zz:_sequence_ z:groupName="b:PriceItemFilterGroup" minOccurs="0" ns0:occ="?">{
                element {node-name($n)} {
                    for $a in $n/(@* except @ns0:occ) return f:ltrees2Btrees_adhocRC($a),
                    attribute ns0:occ {'+'},
                    for $c in $n/node() return f:ltrees2Btrees_adhocRC($c)                
                }
            }</zz:_sequence_>
        else
            element {node-name($n)} {
                for $a in $n/@* return f:ltrees2Btrees_adhocRC($a),
                for $c in $n/node() return f:ltrees2Btrees_adhocRC($c)                
            }
           
    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:ltrees2Btrees_adhocRC($a),
            for $c in $n/node() return f:ltrees2Btrees_adhocRC($c)                
        }
    default return $n
};
:)