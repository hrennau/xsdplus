(:
 : -------------------------------------------------------------------------
 :
 : seatx2xq.xqm - Document me!
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
    "schemaLoader.xqm",
    "seatFunctions.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zprev="http://www.xsdr.org/ns/structure";

(: Maps a SEAT document to a SEATX document, which is an
 : extended representation of the SEAT.
 :)
declare function f:seatx($seat as element(z:seat), 
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
        
        f:seatx_functions_valueMap($resources),
        f:seatx_functions($resources),
        
        <z:set-context expr="*">{
            f:seatxRC($seat, $request)
        }</z:set-context>
    )    
    return
        <z:xquery>{$codeItems}</z:xquery>
};

declare function f:seatxRC($n as node(), $request as element()?)
        as item()* {
    typeswitch($n)
    case document-node() return
        document {
            for $c in $n/node() return f:seatxRC($c, $request)
        }

    case element(z:seats) return
        for $c in $n/node() return f:seatxRC($c, $request)

    case element(z:seat) return
        for $c in $n/node() return f:seatxRC($c, $request)

    case element(z:_attributes_) return
        <z:attributes>{
            for $c in $n/node() return f:seatxRC($c, $request)
        }</z:attributes>            

(: TODO - support for z:_sequence_ with occs != 1 :)
    case element(z:_sequence_) return
        <z:sequence>{
            for $c in $n/node() return f:seatxRC($c, $request)
        }</z:sequence>            

    (: the choice is represented by <z:choice>
       every branch is represented by <z:branch> with @expr :)
    case element(z:_choice_) return
        let $forEachEx :=
            let $attValue := $n/@for-each/string()
            return
                if (empty($attValue)) then ()
                else if (normalize-space($attValue) = ('.', '')) then '$c'
                else f:seatx_expressionValue($attValue, false())
(:                
                else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                else if (matches($attValue, '^\s*/')) then replace($attValue, '^\s+', '')                
                else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')                
                else concat("$c/", $attValue)
:)        
        let $branches :=
            for $case at $pos in $n/*
            let $cond := $case/@case
            let $condEx :=
                if (empty($cond)) then ()
                else if (matches($cond, '^[\d/=]')) then $cond
                else f:seatx_expressionValue($cond, false())
(:                
                else if (matches($cond, '^\s*~')) then replace($cond, '^\s*~\s*', '')
                else if (matches($cond, '^\s*/')) then replace($cond, '^\s+', '')
                else if (matches($cond, '^\s*\$')) then replace($cond, '\s+', '')
                else concat('$c/', $cond)
:)                
            return
                <z:branch expr="{$condEx}">{
                    f:seatxRC($case, $request)
                }</z:branch>
        let $choice :=
            <z:choice>{
                $branches
            }</z:choice>
        return 
            if ($forEachEx) then
                <z:for-each expr="{$forEachEx}">{
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
                    let $vvalue := f:seatx_expressionValue($vvalue, false())
(:                    
                        if (matches($vvalue, '^\s*~')) then replace($vvalue, '^\s*~\s*', '')
                        else if (matches($vvalue, '^\s*/')) then replace($vvalue, '^\s+', '')                        
                        else concat('$c/', $vvalue)
:)                        
                    return 
                        <z:set-var name="{$vname}" value="{$vvalue}"/>

        (: eval @for-each 
                --------- :)
        let $forEachEx :=
            let $attValue := $n/@for-each/string()
            return
                if (empty($attValue)) then ()
                else if (normalize-space($attValue) = ('.', '')) then '$c'
                else f:seatx_expressionValue($attValue, false())
(:                
                else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                else if (matches($attValue, '^\s*/')) then replace($attValue, '^\s+', '')
                else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')                
                else concat("$c/", $attValue)
:)                
        (: eval @ctxt 
           ---------- :)
        let $ctxtEx :=
           let $attValue := $n/@ctxt/string()
           return
               if (not($attValue) or normalize-space($attValue) = ('.', '')) then ()
               else f:seatx_expressionValue($attValue, false())
(:               
               else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
               else if (matches($attValue, '^\s*/')) then replace($attValue, '^\s+', '')               
               else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')
               else concat("$c/", $attValue)
:)                
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
                    else f:seatx_expressionValue($attValue, true())
(:                    
                    else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                    else if (matches($attValue, '^\s*/')) then concat(replace($attValue, '^\s+', ''), '/string()')
                    else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')
                    else concat('$c/', $attValue, '/string()')
:)                
        (: eval @default 
           ------------- :)
        let $defaultAtt :=
            let $defaultEx :=
                let $attValue := $n/@default/string()
                return  
                    if (not($attValue)) then ()
                    else if (not(normalize-space($attValue))) then ''  
                    else f:seatx_expressionValue($attValue, true())
(:                    
                    else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                    else if (matches($attValue, '^\s*/')) then concat(replace($attValue, '^\s+', ''), '/string()')                    
                    else if (matches($attValue, '^\s*\$')) then replace($attValue, '\s+', '')
                    else concat('$c/', $attValue, '/string()')
:)                    
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
                else f:seatx_expressionValue($attValue, true())
(:                
                else if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
                else if (matches($attValue, '^\s*/')) then concat(replace($attValue, '^\s+', ''), '/string()')
                else if (matches($attValue, '^\s*\$')) then concat(replace($attValue, '\s+', ''), '/string()')
                else  concat('$c/', $attValue, '/string()')
:)                
        (: eval @post 
           ---------- :)
        let $postAtt :=
            let $postEx := ($n/@post ! f:resolvePost(., "$v"))
            return
                ($postEx ! attribute post {.})
                
        (: construct source code
           --------------------- :)    
        (: skip this element, if appropriate :)
        return 
            if ('%skip' = ($ctxtEx, $forEachEx)) then () else
          
        let $nodeChildren :=
            $childElems ! f:seatxRC(., $request)
        
        let $nodeChildrenWithVarContext := $nodeChildren
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
                    attribute expr {$srcEx},
                    $conditionalNode
                }</z:set-value>
            
        let $nodeInContext :=
            if (not($ctxtEx)) then $nodeInValueContext
            else
                <z:set-context expr="{$ctxtEx}">{
                    $altEx ! attribute altEx {.},
                    $nodeInValueContext
                }</z:set-context>
       
        let $nodeSequence :=
            if (not($forEachEx)) then $nodeInContext
            else
                <z:for-each expr="{$forEachEx}">{
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
 : Helper function of `seatx`, writing an XML representation of
 : value mapping functions capturing the value mappings.
 :)
declare function f:seatx_functions_valueMap($resources as element(z:resources))
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
 : Helper function of `seatx`, writing an XML wrapper for user-defined functions.
 :) 
declare function f:seatx_functions($resources as element(z:resources))
        as element(z:functions)? {      
    $resources/z:xqueryFunctions/string()[matches(., '\S')] !
    <z:functions>{concat('&#xA;', ., '&#xA;')}</z:functions>
};

declare function f:seatx_expressionValue($attValue as xs:string?, $atomize as xs:boolean?)
        as xs:string {
    if (matches($attValue, '^\s*~')) then replace($attValue, '^\s*~\s*', '')
    else if (matches($attValue, '^\s*\$')) then replace($attValue, '^\s+', '')    
    else if ($atomize) then
        if (matches($attValue, '^\s*/')) then concat(replace($attValue, '^\s+', ''), '/string()')    
        else 
            let $expr :=
                if (contains($attValue, ',')) then concat('(', $attValue, ')')
                else $attValue                   
            return concat("$c/", $expr, '/string()')
    else
        if (matches($attValue, '^\s*/')) then replace($attValue, '^\s+', '')
        else 
            let $expr :=
                if (contains($attValue, ',')) then concat('(', $attValue, ')')
                else $attValue                   
            return concat("$c/", $expr)
};   
