(:
 : -------------------------------------------------------------------------
 :
 : seatxqx.xqm - Document me!
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
    "seatx.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zprev="http://www.xsdr.org/ns/structure";

(: Maps a SEAT document to an XML representation of the
 : XQuery transformer.
 :)
declare function f:seatxqx($seat as element(z:seat), 
                           $resources as element(z:resources)?,
                           $request as element()?)
      as item()* {
    let $seatx := f:seatx($seat, $resources, $request)
    let $xqx := f:seatxqxRC($seatx)
    return $xqx
};

(:~
 : Recursive helper function of `seatxqx`.
 :
 : @param n the node to be processed
 : @return the XQuery code represented by this node
 :) 
declare function f:seatxqxRC($n as node())
        as item()* {
    typeswitch($n)        
    case document-node() return
        document {
            for $c in $n/node() return f:seatxqxRC($c)
        }

    case element(z:sequence) return
        <z:sequence>{
            for $a in $n/@* return f:seatxqxRC($a),
            for $c in $n/node() return f:seatxqxRC($c)
        }</z:sequence>

    case element(z:choice) return
        <z:choice>{
            for $a in $n/@* return f:seatxqxRC($a),
            for $c in $n/node() return f:seatxqxRC($c)
        }</z:choice>

    case element(z:branch) return
        <z:branch>{
            for $a in $n/@* return f:seatxqxRC($a),
            for $c in $n/node() return f:seatxqxRC($c)
        }</z:branch>

    case element(z:set-var-context) return (
        for $v in $n/z:var-context/z:set-var return 
            <z:let name="{$v/@name}" expr="{$v/@value}"/>,
        <z:return>{
            for $c in $n/(* except z:var-context) return f:seatxqxRC($c)
        }</z:return>
    )
    
    case element(z:set-context) return (
        <z:let name="c" expr="{$n/@expr}"/>,
        <z:return>{
            for $c in $n/node() return f:seatxqxRC($c)        
        }</z:return>        
    )
    
    case element(z:set-value) return (
        <z:let name="v" expr="{$n/@expr}"/>,
        <z:return>{
            for $c in $n/node() return f:seatxqxRC($c)
        }</z:return>
    )
    
    case element(z:if-value) return
        <z:if cond="empty($v)">{
            <z:then expr="()"/>,
            <z:else>{for $c in $n/node() return f:seatxqxRC($c)}</z:else>
        }</z:if>
     
    case element(z:if-context) return
        <z:if cond="empty($c)">{
            <z:then expr="()"/>,
            <z:else>{for $c in $n/node() return f:seatxqxRC($c)}</z:else>
        }</z:if>
     
    case element(z:for-each) return (
        <z:for expr="{$n/@expr}"/>,
        <z:return>{
            for $c in $n/* return f:seatxqxRC($c)
        }</z:return>
    )

    case element(z:attributes) return
        <z:attributes>{
            for $a in $n/@* return f:seatxqxRC($a),
            for $c in $n/node() return f:seatxqxRC($c)
        }</z:attributes>

    case element(z:namespaces) | element(z:function-value-mapper) | element(z:functios) return
        $n
        
    case element() return
        let $isAttribute := $n/ancestor::z:attributes
        let $nname := $n/name()
        let $children := $n/(z:attributes/*, * except z:attributes)
        let $hasAttributes := exists($n/z:attributes/*)
        let $src := $n/@src/string()
        let $post := $n/@post/string()
        let $default := $n/@default/string()
        
        (: $code_scontent - code used to set simple content :)
        let $expr_scontent :=
            let $expr :=
                if ($src) then
                    if (not($post) and not($default)) then 
                        attribute expr {$src}
                    else (
                        <z:let name="v" expr="{$src}"/>,
                        $post ! <z:let name="v" expr="{.}"/>,
                        if (not($default)) then
                            <z:return expr="$v"/>
                        else
                            <z:return>
                                <z:if cont="exists($v)">{
                                    <z:then expr="$v"/>,
                                    <z:else expr="{$default}"/>
                                }</z:if>
                            </z:return>
                    )
                else if ($n/ancestor::z:set-value) then
                    let $exprText := if ($post) then $post else '$v'
                    return 
                        attribute expr {$exprText}
                else ()                        
            return $expr
                
        (: $code_ccontent - code used to set complex content :)
        let $expr_ccontent := 
            if ($isAttribute) then () 
            else if (not($children)) then ()
            else
                for $c in $n/* return f:seatxqxRC($c)
                
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

