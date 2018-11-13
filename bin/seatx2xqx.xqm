(:
 : -------------------------------------------------------------------------
 :
 : seatxqx.xqm - a function transforming a SEAT document into an xqx document describing the XQuery transformer.
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
    "constants.xqm",
    "xqx2xq.xqm",
    "schemaLoader.xqm",
    "seatFunctions.xqm",
    "seat2seatx.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zprev="http://www.xsdr.org/ns/structure";

(: Maps a SEATX document to an xqx document describing the XQUery transformer.
 :)
declare function f:seatx2xqx($seatx as element(z:seatx), 
                             $request as element()?)
        as item()* {
    let $raw := f:seatx2xqxRC($seatx)
    return
        f:editXqx_addFlowr($raw)
};

(:~
 : Recursive helper function of `seatxqx`.
 :
 : @param n the node to be processed
 : @return the XQuery code represented by this node
 :) 
declare function f:seatx2xqxRC($n as node())
        as item()* {
    typeswitch($n)        
    case document-node() return
        document {$n/node() ! f:seatx2xqxRC(.)}

    case element(z:seatx) return
        <z:xqx>{
            $n/@* ! f:seatx2xqxRC(.),
            $n/node() ! f:seatx2xqxRC(.)
        }</z:xqx>

    case element(z:function-value-mapper) return
        let $switch := $n/z:switch return
        
        <z:function name="{concat('f:map-', $n/@name)}" as="{$n/@as}">{
            <z:params>{
                <z:param name="{$n/@param}" as="xs:string"/>
            }</z:params>,
            <z:switch expr="{$switch/@value}">{
                for $case in $switch/z:case
                return
                    <z:case match="{concat('&apos;', $case/@match, '&apos;')}" 
                            expr="{concat('&apos;', $case/@value, '&apos;')}"/>,
                $switch/z:default/<z:default expr="{concat('&apos;', @value, '&apos;')}"/>
            }</z:switch>
        }</z:function>            

    case element(z:functions) return
        <z:functions parsed="false">{
            $n/text()
        }</z:functions>

    case element(z:sequence) return
        <z:sequence>{
            $n/@* ! f:seatx2xqxRC(.),
            $n/node() ! f:seatx2xqxRC(.)
        }</z:sequence>

    case element(z:choice) return
        <z:choice>{
            $n/@* ! f:seatx2xqxRC(.),
            $n/node() ! f:seatx2xqxRC(.)
        }</z:choice>

    case element(z:branch) return
        <z:branch>{
            $n/@* ! f:seatx2xqxRC(.),
            $n/node() ! f:seatx2xqxRC(.)
        }</z:branch>

    case element(z:set-var-context) return (
        (: map the variable assignments to let clauses :)
        $n/z:var-context/z:set-var ! <z:let name="{@name}" expr="{@value}"/>,
        <z:return>{
            (: map the remaining content :)
            $n/(* except z:var-context) ! f:seatx2xqxRC(.)
        }</z:return>
    )
    
    case element(z:set-context) return (
        <z:let name="c" expr="{$n/@expr}"/>,
        <z:return>{$n/node() ! f:seatx2xqxRC(.)}</z:return>        
    )
    
    case element(z:set-value) return (
        <z:let name="v" expr="{$n/@expr}"/>,
        <z:return>{$n/node() ! f:seatx2xqxRC(.)}</z:return>
    )
    
    case element(z:if-value) return
        <z:if expr="empty($v)">{
            <z:then expr="()"/>,
            <z:else>{$n/node() ! f:seatx2xqxRC(.)}</z:else>
        }</z:if>
     
    case element(z:if-context) return
        <z:if expr="empty($c)">{
            <z:then expr="()"/>,
            <z:else>{$n/node() ! f:seatx2xqxRC(.)}</z:else>
        }</z:if>
     
    case element(z:for-each) return (
        <z:for name="c" expr="{$n/@expr}"/>,
        <z:return>{$n/* ! f:seatx2xqxRC(.)}</z:return>
    )

    case element(z:attributes) return
        $n/node() ! f:seatx2xqxRC(.)

    case element(z:namespaces) | element(z:function-value-mapper) | element(z:functios) return
        $n
        
    case element() return
        let $isAttribute := $n/ancestor::z:attributes
        let $nname := $n/name()
        let $children := $n/(z:attributes/*, * except z:attributes)
        let $hasAttributes := exists($n/z:attributes/*)
        let $src := $n/@src/string()
        let $post := $n/@post/string()
        let $dflt := $n/@dflt/string()
        
        (: $code_scontent - code used to set simple content :)
        let $expr_scontent :=
            if ($src) then
                if (not($post) and not($dflt)) then 
                    if ($n/z:attributes) then <z:value expr="{$src}"/>
                    else attribute expr {$src}
                else (
                    <z:let name="v" expr="{$src}"/>,
                    $post ! <z:let name="v" expr="{.}"/>,
                    if (not($dflt)) then
                        <z:return expr="$v"/>
                    else
                        <z:return>
                            <z:if expr="exists($v)">{
                                <z:then expr="$v"/>,
                                <z:else expr="{$dflt}"/>
                            }</z:if>
                        </z:return>
                )
            else if ($n/ancestor::z:set-value) then
                let $exprText := if ($post) then $post else '$v'
                return 
                    if ($n/z:attributes) then <z:value expr="{$exprText}"/>
                    else attribute expr {$exprText}
            else ()                        
                
        (: $code_ccontent - code used to set complex content :)
        let $expr_ccontent := $n/* ! f:seatx2xqxRC(.)
                
        return
            (: attribute node 
               -------------- :)
            if ($isAttribute) then
                <z:attribute name="{$nname}">{$expr_scontent}</z:attribute>
                
            (: element node 
               ------------ :)
            else
                element {node-name($n)} {
                    $expr_scontent/self::attribute(),
                    $expr_ccontent,
                    $expr_scontent/self::*
                }

    default return $n
};        

(:~
 : Helper function of `xqx2xq`, transforms value mapper functions into code.
 :
 : @param xqx XML representation of an XQuery query
 : @return XQuery code
 :) 
declare function f:seatx2xq_valueMappers($xqx as element())
        as xs:string* {
    for $mapper in $xqx//z:function-value-mapper
    let $name := $mapper/@name
    let $varName := concat("$", $mapper/@param)
    let $switch := $mapper//z:switch
    return 
        string-join((
            concat("declare function f:map-", $name, "(", $varName, " as xs:string?)"),
            "        as xs:string? {",
            concat("    switch(", $varName, ")"),
            for $case in $switch/z:case
            return
                concat("        case '", $case/@match, "' return '", $case/@value, "'"),
            concat("        default return '", $switch/z:default/@value, "'"),
            '};&#xA;'
        ), '&#xA;')
};        

(:~
 : Helper function of `xqx2xq`, transforms a `z:functions` element into code.
 :
 : @param xqx XML representation of an XQuery query
 : @return XQuery code
 :) 
declare function f:seatx2xq_functions($xqx as element())
        as xs:string* {
    $xqx//z:functions/concat(., '&#xA;')        
};        

declare function f:editXqx_addFlowr($xqx as element(z:xqx))
        as element(z:xqx) {
    let $flworStartNodes := 
        for $r in $xqx//z:return
        let $before := $r/preceding-sibling::*[not((self::z:let, self::z:for, self::z:group))][1]
        return
            if ($before) then $before/following-sibling::*[1]
            else $r/../*[1]
    let $flworFurtherNodes :=
        for $fsn in $flworStartNodes
        let $return := $fsn/following-sibling::z:return[1]
        return
            $fsn/following-sibling::*[not(. >> $return)]
    let $_DUMMY := trace(count($flworStartNodes), '#START_NODES: ')
    let $_DUMMY := trace(count($flworFurtherNodes), '#FURTHER_NODES: ')    
    return
        f:editXqx_addFlowrRC($xqx, $flworStartNodes, $flworFurtherNodes)
};

declare function f:editXqx_addFlowrRC($n as node(), 
                                      $flworStartNodes as element()*,
                                      $flworFurtherNodes as element()*)
        as node()? {
    typeswitch($n)
    case document-node() return 
        document {$n/node() ! f:editXqx_addFlowrRC(., $flworStartNodes, $flworFurtherNodes)}
    
    case element() return
        if ($n intersect $flworStartNodes) then
            <z:flwor>{
                let $return := $n/following-sibling::z:return[1]
                return
                    for $clause in ($n, $n/following-sibling::*[not(. >> $return)])
                    return
                        element {node-name($clause)} {
                            $clause/@* ! f:editXqx_addFlowrRC(., $flworStartNodes, $flworFurtherNodes),
                            $clause/node() ! f:editXqx_addFlowrRC(., $flworStartNodes, $flworFurtherNodes)
                        }
            }</z:flwor>
        else if ($n intersect $flworFurtherNodes) then ()
        else
            element {node-name($n)} {
                $n/@* ! f:editXqx_addFlowrRC(., $flworStartNodes, $flworFurtherNodes),
                $n/node() ! f:editXqx_addFlowrRC(., $flworStartNodes, $flworFurtherNodes)
            }
            
    case attribute() return $n
    default return $n        
};        

