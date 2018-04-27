(:
 : -------------------------------------------------------------------------
 :
 : seat2xq_old.xqm - Document me!
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
    "seatFunctions.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zprev="http://www.xsdr.org/ns/structure";

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
            "    switch($v)",
            $valueMap/z:entry[@from] ! concat("        case '", @from, "' return '", @to, "'")
            ,
            let $default := ($valueMap/z:entry[not(@from)][last()]/@to, '')[1]
            return
                concat("        default return '", $default, "'")
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

        let $forEachEx :=
            let $attValue := $n/@for-each/string()
            return
                if (not($attValue)) then () 
                else
                    if (matches($attValue, '^[\d/=]')) then $attValue 
                    else if (matches($attValue, '^\s*~')) then 
                        replace($attValue, '^\s*~\s*', '')
                    else if (matches($attValue, '^\s*\$')) then 
                        replace($attValue, '\s+', '')            
                    else concat('$c/', $attValue)

        let $forEach :=
            $forEachEx !
            concat($indent, "for $c in ", ., " return", "&#xA;") 
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
                let $vname := replace($var, '\s*(.+?)\s*=.*', '$1')
                let $vvalue := replace($var, '^.+?=\s*', '')            
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
                let $expr := f:resolvePost($post, "$v")
                return
                    concat($indent, 'let $v := ', $expr, ' return&#xA;')

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

