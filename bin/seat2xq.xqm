(:
 : -------------------------------------------------------------------------
 :
 : seat2xq.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="seat2xq" type="item()*" func="seat2xqOp">     
         <param name="seat" type="docFOX" sep="WS"/>
         <param name="format" type="xs:string?" fct_values="txt, xml, txt2" default="txt"/>
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
    "xqx2xq.xqm",
    "schemaLoader.xqm",
    "seatFunctions.xqm",
    "seat2xq_old.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zprev="http://www.xsdr.org/ns/structure";

(:~
 : Implements operation `seat2xq`. The operation transforms a 'seat'
 : document into an XQuery implementation of the transformation
 : specified by the document.
 :
 : @param request the operation request
 : @return an XQuery query
 :) 
declare function f:seat2xqOp($request as element())
        as item()* {
    let $schemas := app:getSchemas($request)      
    let $seats as element(z:seats)? := 
        tt:getParam($request, 'seat')/*/f:prepareSeatsDoc(.)
    let $format := tt:getParam($request, 'format')
    let $resources := $seats/z:resources
    let $seat := $seats/descendant::z:seat[1]
    let $xq := 
        if ($format eq 'txt') then f:seat2xq($seat, $resources, $request)
        else 
            let $xqx := f:seat2xqx($seat, $resources, $request)
            return
                if ($format eq 'xml') then $xqx
                else f:xqx2xq($xqx)
    return $xq
};

declare function f:prepareSeatsDoc($doc as element())
        as element() {
    f:prepareSeatsDocRC($doc)        
};        

declare function f:prepareSeatsDocRC($n as node())
        as node() {
    typeswitch($n)
    case element(zprev:xmaps) return 
        element z:seats {
            for $a in $n/@* return f:prepareSeatsDocRC($a),
            
            let $seat1 := $n/zprev:xmap[1]
            let $resources := $n/node()[. << $seat1]
            let $seats := $n/node() except $resources
            return (
                <z:resources>{
                    for $r in $resources return f:prepareSeatsDocRC($r)
                }</z:resources>,
                for $s in $seats return f:prepareSeatsDocRC($s)                
            )
        }
            
    case element(zprev:xmap) return 
        element z:seat {
            for $a in $n/@* return f:prepareSeatsDocRC($a),
            for $c in $n/node() return f:prepareSeatsDocRC($c)
        }
    case element(zprev:xmap) return 
        element z:seat {
            for $a in $n/@* return f:prepareSeatsDocRC($a),
            for $c in $n/node() return f:prepareSeatsDocRC($c)
        }
    case element() return
        let $nname := 
            if ($n/self::zprev:*) then QName($app:URI_LTREE, concat('z:', local-name($n)))
            else node-name($n)
        return
            element {$nname} {
                for $a in $n/@* return f:prepareSeatsDocRC($a),
                for $c in $n/node() return f:prepareSeatsDocRC($c)
            }
    default return $n            
};        

(: Maps a SEAT document to an XML representation of the
 : XQuery transformer.
 :)
declare function f:seat2xqx($seat as element(z:seat), 
                            $resources as element(z:resources)?,
                            $request as element()?)
      as item()* {
    let $params := tokenize($seat/@params, ',\s*')
    let $nss := $resources/z:nsMap/z:ns
    
    let $codeItems := (
        <z:namespaces>{
            <z:namespace prefix="f" uri="http://www.xsdplus/ns/xquery-functions"/>,
            <z:namespace prefix="xsi" uri="http://www.w3.org/2001/XMLSchema-instance"/>,
            for $ns in $nss return
                <z:namespace prefix="{$ns/@prefix}" uri="{$ns/@uri}"/>
        }</z:namespaces>,                

        <z:parameters>{
            for $param in $params
            let $name := replace($param, '.*\s+', '')
            let $type := replace($param, '\s.*', '')
            return
                <z:parameter name="{$name}" type="{$type}"/>
        }</z:parameters>,
        
        f:seat2xqx_functions_valueMap($resources),
        f:seat2xqx_functions($resources),
        
        <z:set-context ex="*">{
            f:seat2xqxRC($seat, $request)
        }</z:set-context>
    )    
    return
        <z:xquery>{$codeItems}</z:xquery>
};

declare function f:seat2xqxRC($n as node(), $request as element()?)
        as item()* {
    typeswitch($n)
    case document-node() return
        document {
            for $c in $n/node() return f:seat2xqxRC($c, $request)
        }

    case element(z:seats) return
        for $c in $n/node() return f:seat2xqxRC($c, $request)

    case element(z:seat) return
        for $c in $n/node() return f:seat2xqxRC($c, $request)

    case element(z:_attributes_) return
        <z:attributes>{
            for $c in $n/node() return f:seat2xqxRC($c, $request)
        }</z:attributes>            

(: TODO - support for z:_sequence_ with occs != 1 :)
    case element(z:_sequence_) return
        <z:sequence>{
            for $c in $n/node() return f:seat2xqxRC($c, $request)
        }</z:sequence>            

    (: the choice is represented by <z:choice>
       every branch is represented by <z:branch> with @ex :)
    case element(z:_choice_) return
        let $forEachEx :=
            let $attValue := $n/@for-each/string()
            return
                if (empty($attValue)) then ()
                else if (normalize-space($attValue) = ('.', '')) then '$c'
                else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')                
                else concat("$c/", $attValue)
        
        let $branches :=
            for $case at $pos in $n/*
            let $cond := $case/@case
            let $condEx :=
                if (matches($cond, '^[\d/=]')) then $cond
                else if (matches($cond, '^\s*~')) then replace($cond, '^\s*~\s*', '')
                else if (matches($cond, '^\s*\$')) then replace($cond, '\s+', '')
                else concat('$c/', $cond)
            return
                <z:branch ex="{$condEx}">{
                    f:seat2xqxRC($case, $request)
                }</z:branch>
        let $choice :=
            <z:choice>{
                $branches
            }</z:choice>
        return 
            if ($forEachEx) then
                <z:for-each ex="{$forEachEx}">{
                    $choice
                }</z:for-each>
            else
                $choice

    case element() return
        let $contentModelID := $n/@contentModelID
        
        (: operation parameter 'xsd' triggers a schema location declaration :)
        let $schemaLocation := 
            if (not($n/parent::z:seat)) then ()
            else
                let $xsdUri := tt:getParam($request, 'xsd')
                return
                    if (not($xsdUri)) then () else
                        let $tns := $n/../@targetNamespace
                        return
                            if (empty($tns)) then attribute xsi:noNamespaceSchemaLocation {$xsdUri}
                            else
                                attribute xsi:schemaLocation {concat($tns, ' ', $xsdUri)}
                                
        (: determine effective child elements
               (may be the child elements of a referenced location) :)
        let $childElems :=
            if (not($contentModelID)) then $n/*
            else
                let $contentProvider := $n/root()//*[@xml:id eq $contentModelID]
                return
                    if (not($contentProvider)) then error(QName((), 'INVALID_SEAT'), 
                        concat('Cannot resolve contentModelID: ', $contentModelID))
                    else
                        $contentProvider/*

        (: eval @vars 
           ---------- :)
        let $setVars :=
            let $vars := $n/@vars/tokenize(., '\s*;\s*')
            return
                if (empty($vars)) then () 
                else
                    for $var in $vars
                    let $vname := replace($var, '\s*(.+?)\s*=.*', '$1')
                    let $vvalue := replace($var, '^.+?=\s*', '')            
                    let $vvalue :=
                        if (matches($vvalue, '^\s*~')) then replace($vvalue, '^\s*~\s*', '')
                        else concat('$c/', $vvalue)           
                    return 
                        <z:set-var name="{$vname}" value="{$vvalue}"/>

        (: eval @for-each 
                --------- :)
        let $forEachEx :=
            let $attValue := $n/@for-each/string()
            return
                if (empty($attValue)) then ()
                else if (normalize-space($attValue) = ('.', '')) then '$c'
                else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')                
                else concat("$c/", $attValue)
                
        (: eval @ctxt 
           ---------- :)
        let $ctxtEx :=
           let $attValue := $n/@ctxt/string()
           return
               if (not($attValue) or normalize-space($attValue) = ('.', '')) then () 
               else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
               else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')
               else concat("$c/", $attValue)
                
        (: isConditional :)
        let $isConditional := exists($n/@if0)
            
        (: eval @altEx
                ====== :)
        let $altEx :=
            if (not($isConditional)) then ()
            else
                let $attValue := $n/@if0/string()
                return
                    if (not(normalize-space($attValue))) then () 
                    else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                    else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')
                    else concat("$c/", $attValue)
                
        (: eval @default 
           ------------- :)
        let $defaultAtt :=
            let $defaultEx :=
                let $attValue := $n/@default/string()
                return
                    if (not($attValue)) then () 
                    else if (not(normalize-space($attValue))) then ''                    
                    else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                    else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')
                    else concat("$c/", $attValue)
            return
                $defaultEx ! attribute default {.}

        (: eval @src 
           --------- :)
        let $srcEx :=
            let $attValue := $n/@src/string() 
            return
                if (not($attValue)) then ()
                else if (normalize-space($attValue) = ('', '.')) then '$c/string()'
                else if (matches($attValue, '^\s*=')) then concat("'", replace($attValue, '^\s*=\s*', ''), "'")
                else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                else if (matches($attValue, '^\s*\$')) then concat(replace($attValue, '\s+', ''), "/string()")
                else  concat("$c/", $attValue, "/string()")
                
        (: eval @post 
           ---------- :)
        let $postAtt :=
            let $postEx := ($n/@post ! f:resolvePost(., "$v"))
            return
                ($postEx ! attribute post {.})
        (: let $_LOG := $postAtt ! trace(., ' POST: ') :)
(:        
        let $_LOG := if (not($n/@post)) then ()
                     else trace($n/@post, 'ORIGINAL: ')
:)        
        (: construct source code
           --------------------- :)    
        (: skip this element, if appropriate :)
        return 
            if ('%skip' = ($ctxtEx, $forEachEx)) then () else
          
        let $nodeChildren :=
            $childElems ! f:seat2xqxRC(., $request)
        
        let $nodeChildrenWithVarContext :=
            $nodeChildren
(:            
            if (not($setVars)) then $nodeChildren
            else
                <z:set-var-context>{
                    <z:var-context>{
                        $setVars
                    }</z:var-context>,
                    $nodeChildren
                }</z:set-var-context>
:)                
        let $node :=            
            element {node-name($n)} {
                $schemaLocation,
                if ($isConditional) then () else (                
                    $srcEx ! attribute src {.},
                    $defaultAtt,
                    $postAtt
                ),
                $nodeChildrenWithVarContext
            }


        let $conditionalNode :=
            if (not($isConditional)) then $node
            else if ($srcEx) then 
                <z:if-value>{
                    if (not($postAtt)) then $node
                    else
                        element {node-name($n)} {
                            $node/@*,
                            $postAtt
                        }
                }</z:if-value>
            else <z:if-context>{$node}</z:if-context>

        let $nodeInValueContext :=
            if (not($isConditional)) then $conditionalNode
            else if (not($srcEx)) then $conditionalNode
            else
                <z:set-value>{
                    attribute ex {$srcEx},
                    $conditionalNode
                }</z:set-value>
            
        let $nodeInContext :=
            if (not($ctxtEx)) then $nodeInValueContext
            else
                <z:set-context ex="{$ctxtEx}">{
                    $altEx ! attribute altEx {.},
                    $nodeInValueContext
                }</z:set-context>
       
        let $nodeSequence :=
            if (not($forEachEx)) then $nodeInContext
            else
                <z:for-each ex="{$forEachEx}">{
                    $nodeInContext
                }</z:for-each>

        let $nodeSequenceWithVarContext :=
            if (not($setVars)) then $nodeSequence
            else
                <z:set-var-context>{
                    <z:var-context>{
                        $setVars
                    }</z:var-context>,
                    $nodeSequence
                }</z:set-var-context>
                
        return
            $nodeSequenceWithVarContext
            
    case attribute() return ()

    case text() return
        if ($n/../* and not(matches($n, '\S'))) then () else $n
    default return $n
            
};

(:~ 
 : Helper function of `seat2xqx`, writing an XML representation of
 : value mapping functions capturing the value mappings.
 :)
declare function f:seat2xqx_functions_valueMap($resources as element(z:resources))
        as element(z:function-value-mapper)* {
    for $valueMap in $resources/z:valueMaps/z:valueMap
    return
        <z:function-value-mapper name="{$valueMap/@name}" param="v" as="xs:string?">{
            <z:switch value="$v">{
                $valueMap/z:entry[@from] ! <z:case match="{@from}" value="{@to}"/>,
                ($valueMap/z:entry[not(@from)][last()]/@to, '')[1] ! <z:default value="{.}"/>
            }</z:switch>
        }</z:function-value-mapper>
};

(:~
 : Helper function of `seat2xqx`, writing an XML wrapper for user-defined functions.
 :) 
declare function f:seat2xqx_functions($resources as element(z:resources))
        as element(z:functions)? {      
    $resources/z:xqueryFunctions/string()[matches(., '\S')] !
    <z:functions>{concat('&#xA;', ., '&#xA;')}</z:functions>
};


