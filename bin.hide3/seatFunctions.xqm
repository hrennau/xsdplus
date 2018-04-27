(:
 : -------------------------------------------------------------------------
 :
 : seatFunctions.xqm - a function translating SEAT function calls into FLWOR clauses
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
    "factTreeUtilities.xqm",
    "locationTreeWriter.xqm",
    "schemaLoader.xqm",
    "treesheetWriter.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";

(:~
 : Translates a post processing annotation (@post=...) into one
 : or several FLWOR let clauses.
 :
 : @TO.DO - genuinbe parsing, allowing the nesting of function calls.
 :
 
 :
 : @param post string value of the processing directive
 : @param varNamer the name of the variable holding the value to be processed
 : @return an XQuery expression capturing the intended processing
 :)
declare function f:resolvePost($post as xs:string, 
                               $varName as xs:string)
        as xs:string {
    let $func := replace($post, '^\s*%|\s*\(.*', '')
    let $params := 
        let $paramString := replace($post, '.+?\(\s*(.*?)\)\s*$', '$1')[not(. eq $post)]    
        let $paramString := replace($paramString, ',,', '&amp;comma;')
        let $items := tokenize($paramString, ',\s*')
        for $item in $items return replace($item, '&amp;comma;', ',')
    return
    
        if ($func eq 'dateFromDateTime') then 
            concat('xs:date(replace(', $varName, ', "T.*", ""))')
            
        else if ($func eq 'item1') then 
            concat($varName, '[1]')
            
        else if ($func eq 'lowercase') then 
            concat('lower-case(', $varName, ')[string()]')
            
        else if (matches($func, '^map-')) then
            let $mapName := replace($func, '^map-', '')
            return concat('f:map-', $mapName, '(', $varName, ')')
                
        else if ($func eq 'maxDateTime') then
            concat('max(for $item in ', $varName, ' return xs:dateTime($item))')
            
        else if ($func eq 'minDateTime') then
            concat('min(for $item in ', $varName, ' return xs:dateTime($item))')
            
        else if ($func eq 'minutesFromTime') then 
            concat($varName, '[1] ! xs:time(.) ! (hours-from-time(.) + minutes-from-time(.))')
                   
        else if ($func eq 'someTrue') then
            concat('some $item in ', $varName, ' satisfies xs:boolean($item) eq true()')
            
        else if ($func eq 'stringJoin') then 
            concat('string-join(', $varName, ', "', $params[1], '")')
            
        else if ($func eq 'stringJoinDistinct') then 
            let $sep := replace($params[1], '\\s', ' ')
            return
                concat('string-join(distinct-values(', $varName, '), "', $sep, '")')
                
        else if ($func eq 'sum') then 
            if ($params[1]) then
                let $picture := $params[1]
                return
                    concat('format-number(sum(for $i in ', $varName, ' return number($i)), "', $picture, '")')
            else
                concat('sum(for $i in ', $varName, ' return number($i))')
                
        else if ($func eq 'uppercase') then 
            concat('upper-case(', $varName, ')[string()]')
                
        else
            error(QName((), 'UNKNOWN-POST-PROCESSING'), concat('processing mode=', $post))
};