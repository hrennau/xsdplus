(:
 : -------------------------------------------------------------------------
 :
 : annotationUtilities.xqm - functions processing XSD annotations
 :
 : -------------------------------------------------------------------------
 :)

module namespace f="http://www.xsdplus.org/ns/xquery-functions/anno";

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" 
at "constants.xqm";    

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_constants.xqm";    

declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

(:~
 : Maps annotations to a compact string representation.
 :
 : @param n a location tree node
 : @param options processing options
 : @param lang a language selector
 : @return a concatenated representation of all documentation items
 :)
declare function f:reportAnno($n as node(), 
                              $options as element(options)?, 
                              $lang as xs:string?) 
        as xs:string* {
    let $maxLen := $options/@reportMaxLen[normalize-space()]/xs:integer(.)        
    let $preferElemAnno := $options/@preferElemAnno/xs:boolean(.)
    let $docums := $n/z:_annotation_/z:_documentation_
    let $docum :=
        if (count($docums) le 1) then $docums
        else 
            let $try := $docums[@xml:lang eq $lang]
            return
                if ($try) then $try
                else
                    let $try := 
                        if ($lang eq 'en') then () else $docums[@xml:lang eq 'en']
                    return
                        if ($try) then $try
                        else
                            let $try := $docums[not(@xml:lang)]
                            return
                                if ($try) then $try
                                else
                                    let $langs := distinct-values($docums/@xml:lang) => sort()
                                    return
                                        $docums[@xml:lang eq $langs[1]]
    (: Filter documentation:
       - if $preferElemAnno - use only element annotations, if present :)                                        
    let $docum :=
        if (count($docum) le 1) then $docum
        else if ($preferElemAnno) then
           let $elemDocum := $docum[../@z:annoParentName eq 'element']
           return if ($elemDocum) then $elemDocum else $docum
        else $docum
    return
        if (not($docum)) then () else 
        
        let $str := string-join($docum, ' ### ') ! normalize-space(.)
        return
            if (not($maxLen)) then $str
            else if (string-length($str) le $maxLen) then $str
            else substring($str, 1, $maxLen - 4)||' ...'
};

(:~
 : Maps SAP Integration Advisor documentation items to a compact string representation.
 :
 : The scope of reporting is controlled by $format:
 : - sapiadoc0 - omit items with @source=Name, as well as empty items
 : - sapiadoc - omit empty items
 : - sapiadoc2 - do not omit anything
 :
 : @param n a location tree node
 : @param options processing options
 : @param lang a language selector
 : @return a concatenated representation of all documentation items
 :)
declare function f:reportSapIaDoc($n as node(),
                                  $format as xs:string,
                                  $options as element(options)?, 
                                  $lang as xs:string?) 
        as xs:string* {
        
    let $docums := $n/z:_annotation_/z:_documentation_
    
    (: Exclude MessageName and MessageDefinition, if there is Name and Definition, repectively :)
    let $sources := $docums/@source
    let $excluded := (
        $docums[not(node())][$format ne 'sapiadoc2'],         
        $docums[@source eq 'Name'][$format eq 'sapiadoc0'],
        $docums[@source eq 'MessageName'][$sources = 'Name'],
        $docums[@source eq 'MessageDefinition'][$sources = 'Definition']
    )
    let $docums := $docums except $excluded        
    return if (not($docums)) then () else
    
    let $documsAug :=
        for $docum in $docums
        let $labelPrefix :=
            let $pname := $docum/parent::z:_annotation_/@z:annoParentName
            return
                switch($pname)
                case 'element' return ()
                case 'attribute' return ()
                case 'complexType' return 'ty'
                case 'simpleType' return 'ty'
                default return $pname 
        let $source := $docum/@source
        (: The label indicates the kind of annotation - nm, def, example, techinfo, ... :) 
        let $label :=
            switch($source)
            case 'Name' return 'nm'
            case 'Definition' return 'def'
            case 'Note' return 
                let $category := $docum/@*:category
                return
                    switch($category)
                    case 'Technical Information' return 'techinfo'
                    default return lower-case($category)
            default return 'etc'                   
        let $label := '#' || string-join(($labelPrefix, $label), '-')            
        return
            string-join(($label, $docum/normalize-space(.)), ': ')
    return
        string-join($documsAug, ' ')
};

