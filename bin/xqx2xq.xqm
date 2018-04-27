(:
 : -------------------------------------------------------------------------
 :
 : xqx2xq.xqm - Document me!
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
    "seatx.xqm",
    "seatFunctions.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zprev="http://www.xsdr.org/ns/structure";

(:~
 : Transforms an extended SEAT documednt into XQuery code.
 :
 : @param xqx XML representation of an XQuery query
 : @return XQuery code
 :) 
declare function f:seatx2xq($seatx as element(z:xquery))
        as item()* {
    let $codeWrapped :=

    <_>{
        text {string-join((
        "(:", 
        " ==============================================================",
        "   XQuery code generated by xsdplus.",
        "   ", concat("   Generation time: ", current-dateTime()),
        "",
        "   Do not edit this document.",
        "",
        "   Copyright xsdplus 2018",
        " ==============================================================",
        ":)",
        "",
        for $ns in $seatx/z:namespaces/z:namespace
        return text {concat("declare namespace ", $ns/@prefix, "='", $ns/@uri, "';")},

        for $param in $seatx/z:parameters/z:parameter 
        return
            concat("declare variable $", replace($param/@name, '.*\s+', ''), " as ", replace($param/@type, '\s.*', ''), ' external;')
        ,
        "",
        f:xqx2xq_valueMappers($seatx),
        f:xqx2xq_functions($seatx)
        ), '&#xA;')},
        text {'&#xA;'},   
        f:seatx2xqRC($seatx/descendant::z:set-context[1], 0)
    }</_>
    return
        $codeWrapped/node()
};

(:~
 : Recursive helper function of `seat2xq`.
 :
 : @param n the node to be processed
 : @return the XQuery code represented by this node
 :) 
declare function f:seatx2xqRC($n as node(), $level as xs:integer)
        as item()* {
    typeswitch($n)        
    case document-node() return
        document {
            for $c in $n/node() return f:seatx2xqRC($c, $level)
        }

    case element(z:sequence) return
        let $indent := f:xq_indent($level)
        let $children := $n/*
        return (
            concat($indent, '(&#xA;'),
            let $countChildren := count($children)
            for $child at $pos in $children return (
                f:seatx2xqRC($child, $level),
                text {',&#xA;'}[$pos lt $countChildren]
            ),                
            concat('&#xA;', $indent, ')')
        )

    case element(z:choice) return
        let $indent := f:xq_indent($level)
        return (
            let $branches := $n/*
            for $branch at $pos in $branches
            let $prefix := if ($pos eq 1) then () else 'else '
            let $line := concat($indent, $prefix, 'if (', $branch/@expr,  ') then')
            let $branchContent := $branch/* ! f:seatx2xqRC(., $level + 1)
            return (
                text {$line || '&#xA;'},
                $branchContent,
                text {'&#xA;'}
            )
            , 
            text {concat($indent, 'else ()')}
        )

    case element(z:set-var-context) return
        let $indent := f:xq_indent($level)
        let $children := $n/(* except z:var-context)
        let $returnNow := exists($children except $n/z:*)
        let $suffix := if ($returnNow) then ' return' else ()
        let $lines :=
            let $countVars := count($n/z:var-context/z:set-var)
            for $v at $pos in $n/z:var-context/z:set-var 
            let $name := $v/@name
            let $value := $v/@value
            return concat($indent, 'let $', $name, ' := ', $value,  $suffix[$pos eq $countVars])        
        let $following := $children ! f:seatx2xqRC(., $level)
        return (
            $lines ! text {. || '&#xA;'},
            $following
        )
        
    case element(z:set-context) return
        let $indent := f:xq_indent($level)
        let $children := $n/*
        let $returnNow := not($children/self::z:set-value)
        let $suffix := if ($returnNow) then ' return' else ()
        let $line := concat($indent, 'let $c := ', $n/@expr,  $suffix)        
        let $following := $children ! f:seatx2xqRC(., $level)
        return (
            text {$line || '&#xA;'},
            $following
        )
        
    case element(z:set-value) return
        let $nextLevel := $level + 1
        let $indent := f:xq_indent($level)
        let $nextIndent := f:xq_indent($nextLevel)
        let $children := $n/*
        let $returnNow := not($children/self::z:set-context)
        let $suffix := if ($returnNow) then ' return' else ()

        let $line := concat($indent, 'let $v := ', $n/@expr,  $suffix)
        let $following := $children ! f:seatx2xqRC(., $level)
        return (
            text {$line || '&#xA;'},
            $following
        )

    case element(z:if-value) return
        let $nextLevel := $level + 1
        let $indent := f:xq_indent($level)
        let $nextIndent := f:xq_indent($nextLevel)
        
        let $children := $n/*
        let $line := concat($indent, 'if (empty($v)) then () else')
        let $following := for $c in $children return f:seatx2xqRC($c, $level)
        return (
            text {$line || '&#xA;'},
            $following
        )

    case element(z:if-context) return
        let $nextLevel := $level + 1
        let $indent := f:xq_indent($level)
        let $nextIndent := f:xq_indent($nextLevel)
        
        let $children := $n/*
        let $line := concat($indent, 'if (empty($c)) then () else')
        let $following := $children ! f:seatx2xqRC(., $level)
        return (
            text {$line || '&#xA;'},
            $following
        )

    case element(z:for-each) return
        let $nextLevel := $level + 1
        let $indent := f:xq_indent($level)
        let $nextIndent := f:xq_indent($nextLevel)
        
        let $children := $n/*
        let $ex := $n/@expr
        let $line := text {concat($indent, 'for $c in ', $ex, ' return ')}
        let $following := for $c in $children return f:seatx2xqRC($c, $level)
        return (
            text {$line || '&#xA;'},
            $following
        )

    case element(z:attributes) return
        for $c in $n/* return f:seatx2xqRC($c, $level)
        
    case element() return
        let $nextLevel := $level + 1
        let $indent := f:xq_indent($level)
        let $nextIndent := f:xq_indent($nextLevel)
        
        let $isAttribute := $n/ancestor::z:attributes
        let $nname := $n/name()
        let $children := $n/(z:attributes/*, * except z:attributes)
        let $hasAttributes := exists($n/z:attributes/*)
        let $src := $n/@src/string()
        let $post := $n/@post/string()
        let $default := $n/@default/string()
        
        (: $code_scontent - code used to set simple content :)
        let $code_scontent :=
            let $string :=
                if ($src) then
                    if (not($post) and not($default)) then 
                        concat($nextIndent[$hasAttributes], $src)
                    else
                        string-join((
                            concat($nextIndent, "let $v := ", $src),
                            $post ! concat($nextIndent, "let $v := ", .),
                            if (not($default)) then concat($nextIndent, 'return $v')
                            else concat($nextIndent, 'return if (exists($v)) then $v else ', $default) 
                        ), '&#xA;')
                else if ($n/ancestor::z:set-value) then
                    if ($post) then concat($nextIndent[$hasAttributes], $post)
                    else concat($nextIndent[$hasAttributes], '$v')
                else ()
        return text {$string} [$string]                
            
        (: $code_ccontent - code used to set complex content :)
        let $code_ccontent := 
            if ($isAttribute) then () 
            else if (not($children)) then ()
            else (
                let $countChildren := count($children)
                for $c at $pos in $children 
                return (
                    f:seatx2xqRC($c, $level + 1),
                    text {',&#xA;'}[$pos lt $countChildren] 
                )
            )
                
        return
            (: attribute node 
               -------------- :)
            if ($isAttribute) then
                if (not(matches($code_scontent, '&#xA;'))) then
                    text {concat($indent, 'attribute ', $nname, ' {', $code_scontent, '}')}
                else
                    text {
                        string-join((
                            concat($indent, 'attribute ', $nname, ' {'),
                            $code_scontent,
                            concat($indent, '}')
                        ), '&#xA;')
                    }                   
                
            (: element node 
               ------------ :)
            else
                let $contentInline :=
                    empty($code_ccontent) and not(matches($code_scontent, '&#xA;'))
                let $sepComplexFromSimpleContent :=
                    if ($code_ccontent and $code_scontent) then ',&#xA;'
                    else ()
                let $node :=
                    element {node-name($n)} {
                        if ($contentInline) then concat('{', $code_scontent, '}')
                        else (
                            text {'{&#xA;'},
                            $code_ccontent,
                            $sepComplexFromSimpleContent,
                            $code_scontent,
                            text {concat('&#xA;', $indent, '}')}
                        )                            
                    }
                return (
                    text {$indent},
                    $node
                )
                    
    default return $n
};        

(:~
 : Transforms the XML representation of an XQuery into XQuery code.
 :
 : @param xqx XML representation of an XQuery query
 : @return XQuery code
 :) 
declare function f:xqx2xq($xqx as element(z:xquery))
        as item()* {
    let $codeWrapped :=

    <_>{
        text {string-join((
        "(:", 
        " ==============================================================",
        "   XQuery code generated by xsdplus.",
        "   ", concat("   Generation time: ", current-dateTime()),
        "",
        "   Do not edit this document.",
        "",
        "   Copyright xsdplus 2018",
        " ==============================================================",
        ":)",
        "",
        for $ns in $xqx/z:namespaces/z:namespace
        return text {concat("declare namespace ", $ns/@prefix, "='", $ns/@uri, "';")},

        for $param in $xqx/z:parameters/z:parameter 
        return
            concat("declare variable $", replace($param/@name, '.*\s+', ''), " as ", replace($param/@type, '\s.*', ''), ' external;')
        ,
        "",
        f:xqx2xq_valueMappers($xqx),
        f:xqx2xq_functions($xqx)
        ), '&#xA;')},
        text {'&#xA;'},   
        f:xqx2xqRC($xqx/descendant::z:set-context[1], 0)
    }</_>
    return
        $codeWrapped/node()
};

(:~
 : Recursive helper function of `xqx2xq`.
 :
 : @param n the node to be processed
 : @return the XQuery code represented by this node
 :) 
declare function f:xqx2xqRC($n as node(), $level as xs:integer)
        as item()* {
    typeswitch($n)        
    case document-node() return
        document {
            for $c in $n/node() return f:xqx2xqRC($c, $level)
        }

    case element(z:sequence) return
        let $indent := f:xq_indent($level)
        let $children := $n/*
        return (
            concat($indent, '(&#xA;'),
            let $countChildren := count($children)
            for $child at $pos in $children return (
                f:xqx2xqRC($child, $level),
                text {',&#xA;'}[$pos lt $countChildren]
            ),                
            concat($indent, ')')
        )

    case element(z:choice) return
        let $indent := f:xq_indent($level)
        return (
            let $branches := $n/*
            for $branch at $pos in $branches
            let $prefix := if ($pos eq 1) then () else 'else '
            let $line := concat($indent, $prefix, 'if (', $branch/@expr,  ') then')
            let $branchContent := $branch/* ! f:xqx2xqRC(., $level + 1)
            return (
                text {$line || '&#xA;'},
                $branchContent,
                text {'&#xA;'}
            )
            , 
            text {concat($indent, 'else ()')}
        )

    case element(z:let) return
        let $indent := f:xq_indent($level)
        let $withReturn :=
            $n/following-sibling::*[1][self::z:let, self::z:for, self::z:group-by] or
            $n/following-sibling::*[1]/self::z:return/*[1][self::z:let, self::z:for, self::z:group-by]
        return
            concat($indent, 'let $', $n/@name, ' := ', $n/@expr, ' return'[$withReturn])

    case element(z:for) return
        let $indent := f:xq_indent($level)
        let $withReturn :=
            $n/following-sibling::*[1][self::z:let, self::for, self::group-by] or
            $n/following-sibling::*[1]/self::return/*[1][self::let, self::for, self::group-by]
        return
            concat($indent, 'for $', $n/@name, ' in ', $n/@expr, ' return'[$withReturn])

    case element(z:if) return
        let $indent := f:xq_indent($level)
        let $ifCondThen := concat($indent, 'if (', $n/@cond, ') then ')
        return
            if (not($n/z:then/*)) then
                if (not($n/z:else/*)) then
                    concat($ifCondThen, $n/z:then, ' else ', $n/z:else)
                else (
                    concat($ifCondThen, $n/z:then, ' else'),
                    for $c in $n/z:else/* return f:xqx2xqRC(., $level)
                )
            else (
                $ifCondThen,
                for $c in $n/z:then/* return f:xqx2xqRC(., $level + 1),
                concat($indent, 'else'),
                for $c in $n/z:then/* return f:xqx2xqRC(., $level + 1)
            )
            
    case element(z:attributes) return
        for $c in $n/* return f:xqx2xqRC($c, $level)
        
    case element(z:attribute) return
        let $indent := f:xq_indent($level)    
        let $expr := $n/@expr
        let $attributeName := concat($indent, 'attribute ', $n/@name, ' {')
        return
            if ($expr) then concat($attributeName, $expr, '}')
            else (
                $attributeName,
                for $c in $n/* return f:xqx2xqRC(., $level +1),
                concat($indent, '}')                
            )

    case element(z:expr) return
        let $indent := f:xq_indent($level)
        return
            concat($indent, $n/@text)

    case element() return
        let $expr := $n/@expr
        return
            element {node-name($n)} {
                if ($expr) then concat('{', $expr, '}')
                else (
                    '{',
                    for $c in $n/* return f:xqx2xqRC($c, $level + 1),
                    '}'
                ) 
            }
    default return $n
};        

(:~
 : Helper function of `xqx2xq`, transforms value mapper functions into code.
 :
 : @param xqx XML representation of an XQuery query
 : @return XQuery code
 :) 
declare function f:xqx2xq_valueMappers($xqx as element(z:xquery))
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
declare function f:xqx2xq_functions($xqx as element(z:xquery))
        as xs:string* {
    $xqx//z:functions/concat(., '&#xA;')        
};        

(:~
 : Writes XQuery code - returns the whitespace string producing
 : indentation.
 :
 : @param level hierarchical level of the code line to be indented (>= 0)
 : @return an XQuery query
 :) 
declare function f:xq_indent($level as xs:integer)
      as xs:string {
   string-join(for $i in 1 to $level return '   ', '')
};
