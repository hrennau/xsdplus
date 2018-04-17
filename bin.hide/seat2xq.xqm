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
         <param name="format" type="xs:string?" fct_values="txt, xml" default="txt"/>
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
    "schemaLoader.xqm",
    "seatFunctions.xqm";
    
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
        else f:seat2xqx($seat, $resources, $request)
    return $xq
};

(:~
 : Transforms a 'seat' document into an XQuery implementation of the 
 : transformation specified by the document.
 :
 : @param seat a 'seat' element specifying a transformation
 : @return an XQuery query
 :) 
declare function f:seat2xq($seat as element(z:seat), 
                           $resources as element(z:resources)?,
                           $request as element()?)
      as item()* {
    let $params := tokenize($seat/@params, ',\s*')
    let $codeItems := (

    string-join((
        "(: ============================================================== ",
        "   Generated from a seat document by: xsdplus, operation seat2xq. ",
        "   Do not edit this document.",
        "",
        "   Copyright xsdplus 2018 ",
        "   ============================================================== :) ",
        "",
        "declare namespace f='http://www.xsdplus/ns/xquery-functions';",
        "declare namespace xsi='http://www.w3.org/2001/XMLSchema-instance';",
        for $ns in $seat/z:nsMap/z:ns
        return
            concat("declare namespace ", $ns/@prefix, "='", $ns/@uri, "';"),
        "",
        for $param in $params 
        return
            concat("declare variable $", replace($param, '.*\s+', ''), " as ", replace($param, '\s.*', ''), ' external;'),
        "",
        f:seat2xq_functions_valueMap($resources),
        f:seat2xq_functions($resources),
        "",
        "let $c := * return (&#xA;")
    , "&#xA;"),

    f:seat2xqRC($seat, 0, $request),
    "())"
    )
    return
        $codeItems
    
};

(:~
 : Writes XQuery code - value mapping functions.
 :) 
declare function f:seat2xq_functions_valueMap($resources as element(z:resources))
        as xs:string {
    let $lines :=        
        for $valueMap in $resources/z:valueMaps/z:valueMap
        return (
            concat("declare function f:map-", $valueMap/@name, '($v as xs:string?)'),
            "       as xs:string? {",
            "switch($v)",
            $valueMap/z:entry[@from] ! concat("case '", @from, "' return '", @to, "'")
            ,
            let $default := ($valueMap/z:entry[not(@from)][last()]/@to, '')[1]
            return
                concat("default return '", $default, "'")
            ,
            "};"
        )
    return string-join($lines, "&#xA;")
};

(:~
 : Writes XQuery code - user-defined functions.
 :) 
declare function f:seat2xq_functions($resources as element(z:resources))
        as xs:string? {      
    $resources/z:xqueryFunctions/string()[matches(., '\S')]
};

(:~
 : Writes XQuery code - recurses the SEAT tree
 :) 
declare function f:seat2xqRC($n as node(), 
                             $level as xs:integer, 
                             $request as element()?)
      as item()* {
    typeswitch($n)
    case document-node() return
        document {
            for $c in $n/node() return f:seat2xqRC($c, $level, $request)
        }

    case element(z:seats) return
        for $c in $n/node() return f:seat2xqRC($c, $level, $request)

    case element(z:seat) return
        for $c in $n/node() return f:seat2xqRC($c, $level, $request)

    case element(z:_attributes_) return
        for $c in $n/node() return f:seat2xqRC($c, $level, $request)

(: TODO - support for z:_sequence_ with occs != 1 :)
    case element(z:_sequence_) return
        for $c in $n/node() return f:seat2xqRC($c, $level, $request)

    case element(z:_choice_) return
        let $nextLevel := $level + 1
        let $indent := f:seat2xq_indent($level)
        let $nextIndent := f:seat2xq_indent($nextLevel)

        let $forEach :=
            $n/@for-each !
            concat($indent, "for $c in $c/", @for-each, " return", "&#xA;") 
        let $branches :=
            for $case at $pos in $n/*
            let $cond := $case/@case
            let $condEx := 
                if (matches($cond, '^[\d/=]')) then $cond 
                else if (matches($cond, '^\s*~')) then 
                    replace($cond, '^\s*~\s*', '')
                else if (matches($cond, '^\s*\$')) then 
                    replace($cond, '\s+', '')            
                else concat('$c/', $cond)
            let $if := if ($pos eq 1) then "if" else "else if"
            return (
                concat($nextIndent, $if, " (", $condEx, ") then (&#xA;"),
                f:seat2xqRC($case, $nextLevel, $request),
                concat($nextIndent, "())&#xA;")
            )

        return (
            $forEach,
            $branches,
            concat ($indent, "else (),&#xA;")
        )

    case element() return
        let $nextLevel := $level + 1
        let $indent := f:seat2xq_indent($level)
        let $nextIndent := f:seat2xq_indent($nextLevel)        
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

        let $childElems :=
            if (not($contentModelID)) then $n/node()
            else
                let $contentProvider := $n/root()//*[@xml:id eq $contentModelID]
                return
                    if (not($contentProvider)) then error(QName((), 'INVALID_SEAT'), 
                        concat('Cannot resolve contentModelID: ', $contentModelID))
                    else
                        $contentProvider/*

        let $ctxt := $n/@ctxt[string()]/string()
        let $vars := tokenize($n/@vars, '\s*;\s*')
        let $src := 
            let $att := $n/@src/string()
            return if ($att eq '') then '.' else $att
        let $forEach := 
            let $att := $n/@for-each
            return if ($att eq '') then '.' else $att
        let $post := $n/@post      
        let $ifMissing := ($n/@ifMissing, $n/@ifEmpty, $n/@default, $n/@if0)[1]
        let $defaultValue as xs:string? := if (not($src)) then () else $ifMissing[string(.)]/string()
        
        let $ifMissingClause := 
(:      
          if (not($ifMissing)) then ()
          else if ($n/@default) then ()
:)
            if (not($n/@if0 eq '')) then ()
            else if ($src) then concat($indent, "if (empty($v)) then () else&#xA;")
            else if ($ctxt) then concat($indent, "if (empty($c)) then () else&#xA;")          
            else ()

        (: skip this element, if appropriate :)
        return 
            if ('%skip' = ($ctxt, $forEach)) then () else

        let $clauses := (      
            (: eval @ctxt 
               ---------- :)
            (:      let $c := ... :)
            if (not($ctxt) or $ctxt eq ".") then () 
            else if (matches($ctxt, '^\s*~')) then 
                concat($indent, "let $c := ", replace($ctxt, '^\s*~\s*', ''))
            else if (matches($ctxt, '^\s*\$')) then 
                concat($indent, "let $c := ", replace($ctxt, '\s+', ''))
            else 
                concat($indent, "let $c := $c/", $ctxt),
            
            (: eval @vars 
               ---------- :)            
            if (empty($vars)) then () 
            else
                for $var in $vars
                let $vname := trace( replace($var, '\s*(.+?)\s*=.*', '$1') , 'VARNAME: ')
                let $vvalue := trace( replace($var, '^.+?=\s*', ''), 'VARVALUE: ')            
                let $vvalue :=
                    if (matches($vvalue, '^\s*~')) then replace($vvalue, '^\s*~\s*', '')
                    else concat('$c/', $vvalue)           
                return 
                    concat($indent, 'let $', $vname, ' := ', $vvalue), 
                
            (: eval @for-each 
                    --------- :)      
            (:      for $c in ... :)
            if (not($forEach)) then () 
            else 
                if (matches($forEach, '^\s*~')) then 
                    concat($indent,   "for $c in ", replace($forEach, '^\s*~\s*', ''))
                else 
                    concat($indent, "for $c in $c/", $forEach),
         
            (: eval @src 
               --------- :)
            (:      let $v := ... :)
            if (not($src)) then () 
            else 
                (: case: constant :)
                if (matches($src, '^\s*=')) then 
                    concat($indent, "let $v := '", replace($src, '^\s*=\s*', ''), "'")
                (: case: standalone expression :)
                else if (matches($src, '^\s*~')) then 
                    concat($indent, "let $v := ", replace($src, '^\s*~\s*', ''))
                (: case: expression starts with variable ref :)
                else if (matches($src, '^\s*\$')) then 
                    concat($indent, "let $v := ", replace($src, '\s+', ''), "/string()")
                else  (
                    (: the $defaultValue (if set) replaces a value which has an empty string value :) 
                    concat($indent, "let $v := $c/", $src, "/string()"),
                    if (empty($defaultValue)) then () else
                        concat($indent, "let $v := if (string($v)) then $v else ", $defaultValue)
                )
        )
        (: eval @post 
           ---------- :)
        let $post := 
            if (not($src)) then ()
            else if (not($post)) then () 
            else
                let $clause := f:resolvePost($post, "$v", $indent)
                return
                    concat($clause, ' return&#xA;')

        (: construct FLWOR 
           --------------- :)
        let $flowr := 
            if (empty($clauses)) then () 
            else if (count($clauses) eq 1) then concat($clauses, " return&#xA;")
            else 
                ($clauses, concat($indent, "return&#xA;"))
        
        (: construct source code
           --------------------- :)        
        return (
            text {string-join($flowr, "&#xA;")},
         
            (: the $ifMissingClause (if set) suppresses the node construction if the value is empty :)
            text {$ifMissingClause},
            $post,
            (: node construction 
               ----------------- :)
            
            (: case: attribute node 
               -------------------- :)
            if ($n/parent::z:_attributes_) then
                concat($indent, "attribute ", name($n), " {$v},&#xA;")
            
            (: case: element node 
               ------------------ :)
            else (
                text {$indent},
                element {node-name($n)} {
                    $schemaLocation,
                    if ($src) then 
                        if ($n/z:_attributes_) then (
                            "{&#xA;",
                            for $c in $childElems return f:seat2xqRC($c, $nextLevel, $request),
                            concat($nextIndent, "$v&#xA;", $indent, "}")
                        ) else text{"{$v}"}
                
                    else if ($childElems) then (
                        "{&#xA;",
                        for $c in $childElems return f:seat2xqRC($c, $nextLevel, $request),
                        concat($nextIndent, "()&#xA;"),
                        concat($indent, "}")
                    )
                    else ()
                },
                ",&#xA;"
            )
        )
    case attribute() return ()

    case text() return
        if ($n/../* and not(matches($n, '\S'))) then () else $n
    default return $n
};

(:~
 : Writes XQuery code - returns the whitespace string producing
 : indentation.
 :
 : @param level hierarchical level of the code line to be indented (>= 0)
 : @return an XQuery query
 :) 
declare function f:seat2xq_indent($level as xs:integer)
      as xs:string {
   string-join(for $i in 1 to $level return '   ', '')
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
                <z:namespace prefix="{$ns/@prefix}" uri="$ns/@uri"/>
        }</z:namespaces>,                

        <z:parameters>{
            for $param in $params
            let $name := replace($param, '.*\s+', '')
            let $type := replace($param, '\s.*', '')
            return
                <z:parameter name="{$name}" type="{$type}"/>
        }</z:parameters>,
(:        
        f:seat2xq_functions_valueMap($resources),
        f:seat2xq_functions($resources),
:)
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
        for $c in $n/node() return f:seat2xqxRC($c, $request)

(: TODO - support for z:_sequence_ with occs != 1 :)
    case element(z:_sequence_) return
        for $c in $n/node() return f:seat2xqxRC($c, $request)

    case element(z:_choice_) return
        let $forEach := $n/@for-each 
        let $branches :=
            for $case at $pos in $n/*
            let $cond := $case/@case
            let $condEx := 
                if (matches($cond, '^[\d/=]')) then $cond 
                else if (matches($cond, '^\s*~')) then 
                    replace($cond, '^\s*~\s*', '')
                else if (matches($cond, '^\s*\$')) then 
                    replace($cond, '\s+', '')            
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
            if ($forEach) then
                <z:for-each ex="{$forEach}">{
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

        let $childElems :=
            if (not($contentModelID)) then $n/node()
            else
                let $contentProvider := $n/root()//*[@xml:id eq $contentModelID]
                return
                    if (not($contentProvider)) then error(QName((), 'INVALID_SEAT'), 
                        concat('Cannot resolve contentModelID: ', $contentModelID))
                    else
                        $contentProvider/*

        let $ctxt := $n/@ctxt[string()]/string()
        let $vars := tokenize($n/@vars, '\s*;\s*')
        let $src := 
            let $att := $n/@src/string()
            return if ($att eq '') then '.' else $att
        let $forEach := 
            let $att := $n/@for-each
            return if ($att eq '') then '.' else $att
        let $post := $n/@post      
        let $ifMissing := ($n/@ifMissing, $n/@ifEmpty, $n/@default, $n/@if0)[1]
        let $defaultValue as xs:string? := if (not($src)) then () else $ifMissing[string(.)]/string()
        
        let $ifMissingClause := ()
(:        
            if (not($n/@if0 eq '')) then ()
            else if ($src) then concat($indent, "if (empty($v)) then () else&#xA;")
            else if ($ctxt) then concat($indent, "if (empty($c)) then () else&#xA;")          
            else ()
:)

        (: skip this element, if appropriate :)
        return 
            if ('%skip' = ($ctxt, $forEach)) then () else

        let $clauses := (      
            (: eval @ctxt 
               ---------- :)
            let $ctxtEx :=
                if (not($ctxt) or $ctxt eq ".") then () 
                else if (matches($ctxt, '^\s*~')) then replace($ctxt, '^\s*~\s*', '')
                else if (matches($ctxt, '^\s*\$')) then replace($ctxt, '\s+', '')
                else concat("$c/", $ctxt)
            return
                $ctxtEx ! <z:ctxtEx ex="{.}"/>,
                
            (: eval @vars 
               ---------- :)
            let $setVars :=               
                if (empty($vars)) then () 
                else
                    for $var in $vars
                    let $vname := trace( replace($var, '\s*(.+?)\s*=.*', '$1') , 'VARNAME: ')
                    let $vvalue := trace( replace($var, '^.+?=\s*', ''), 'VARVALUE: ')            
                    let $vvalue :=
                        if (matches($vvalue, '^\s*~')) then replace($vvalue, '^\s*~\s*', '')
                        else concat('$c/', $vvalue)           
                    return 
                        <z:set-var name="{$vname}" value="{$vvalue}"/>
            return
                $setVars,
                
            (: eval @for-each 
                    --------- :)
            let $forEachEx :=                    
                if (not($forEach)) then () 
                else if (matches($forEach, '^\s*~')) then replace($forEach, '^\s*~\s*', '')
                else concat("$c/", $forEach)
            return
                <z:for-each ex="{$forEachEx}"/>,
                
            (: eval @src 
               --------- :)
            let $srcEx :=
                if (not($src)) then () 
                else 
                    (: case: constant :)
                    if (matches($src, '^\s*=')) then concat("'", replace($src, '^\s*=\s*', ''), "'")
                    (: case: standalone expression :) 
                else if (matches($src, '^\s*~')) then replace($src, '^\s*~\s*', '')
                    (: case: expression starts with variable ref :)
                else if (matches($src, '^\s*\$')) then concat(replace($src, '\s+', ''), "/string()")
                else  concat("$c/", $src, "/string()")
            return
                <z:src-ex ex="{$srcEx}"/>
                
        )
        (: eval @post 
           ---------- :)
        let $postEx := 
            if (not($src)) then ()
            else if (not($post)) then () 
            else
                let $clause := f:resolvePost($post, "$v", ())
                return
                    $clause

        (: construct FLWOR 
           --------------- :)
        let $flowr := 
            if (empty($clauses)) then () 
            else if (count($clauses) eq 1) then concat($clauses, " return&#xA;")
            else 
                ($clauses)
        
        (: construct source code
           --------------------- :)        
        return (
            text {string-join($flowr, "&#xA;")},
         
            (: the $ifMissingClause (if set) suppresses the node construction if the value is empty :)
            text {$ifMissingClause},
            $post,
            (: node construction 
               ----------------- :)
            
            (: case: attribute node 
               -------------------- :)
            if ($n/parent::z:_attributes_) then
                <z:attribute name="{name($n)}" value="$v"/>
            
            (: case: element node 
               ------------------ :)
            else (
                element {node-name($n)} {
                    $schemaLocation,
                    if ($src) then 
                        if ($n/z:_attributes_) then (
                            for $c in $childElems return f:seat2xqxRC($c, $request),
                            attribute ex {"$v"}
                        ) else attribute ex {"{$v}"}
                
                    else if ($childElems) then (
                        for $c in $childElems return f:seat2xqxRC($c, $request)
                    )           
                    else ()
                }                    
            )
        )
    case attribute() return ()

    case text() return
        if ($n/../* and not(matches($n, '\S'))) then () else $n
    default return $n
            
};
