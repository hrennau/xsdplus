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
 : or several FLWOR let clauses
 :
 : @param post string value of the processing directive
 : @param inputVar the variable name of the let clause(s) (e.g. '$v')
 : @param indent whitespace string to be inserted in order to 
 :     achieve the appropriate indentation
 : @return a FLWOR let clause representing the processing directive
 :)
declare function f:resolvePost($post as xs:string, 
                               $inputVar as xs:string, 
                               $indent as xs:string)
        as xs:string {
    let $func := replace($post, '^\s*%|\s*\(.*', '')
    let $paramString := replace($post, '.+?\(\s*(.*?)\)\s*$', '$1')
    let $paramString := replace($paramString, ',,', '&amp;comma;')
    let $params := tokenize($paramString, ',\s*')
    let $params := for $p in $params return replace($p, '&amp;comma;', ',')
    return
    
        if ($func eq 'dateFromDateTime') then 
            concat($indent, 'let ', $inputVar, ' := $v[1] ! xs:date(replace(., "T.*", ""))')
            
        else if ($func eq 'item1') then 
            concat($indent, 'let ', $inputVar, ' := $v[1]')
            
        else if ($func eq 'lowercase') then 
            concat($indent, 'let ', $inputVar, ' := lower-case($v)[string()]')
            
        else if (matches($func, '^map-')) then
            let $mapName := replace($func, '^map-', '')
            return
                concat($indent, 'let ', $inputVar, ' := f:map-', $mapName, '(', $inputVar, ')')
                
        else if ($func eq 'maxDateTime') then
            concat($indent, 'let ', $inputVar, ' := max(for $item in $v return xs:dateTime($item))')
            
        else if ($func eq 'minDateTime') then
            concat($indent, 'let ', $inputVar, ' := min(for $item in $v return xs:dateTime($item))')
            
        else if ($func eq 'minutesFromTime') then 
            concat($indent, 'let ', $inputVar, ' := $v[1] ! xs:time(.)&#xA;', 
                   $indent, 'let ', $inputVar, ' := 60 * hours-from-time(', $inputVar, ') + minutes-from-time(', $inputVar, ')')
                   
        else if ($func eq 'someTrue') then
            concat($indent, 'let ', $inputVar, ' := some $item in $v satisfies xs:boolean($item) eq true()')
            
        else if ($func eq 'stringJoin') then 
            concat($indent, 'let ', $inputVar, ' := string-join($v, "', $params[1], '")')
            
        else if ($func eq 'stringJoinDistinct') then 
            let $sep := replace($params[1], '\\s', ' ')
            return
                concat($indent, 'let ', $inputVar, ' := string-join(distinct-values($v), "', $sep, '")')
                
        else if ($func eq 'sum') then 
            if ($params[1]) then
                let $picture := $params[1]
                return
                    concat($indent, 'let ', $inputVar, ' := format-number(sum(for $i in $v return number($i)), "', $picture, '")')
            else
                concat($indent, 'let ', $inputVar, ' := sum(for $i in $v return number($i))')
                
        else if ($func eq 'uppercase') then 
            concat($indent, 'let ', $inputVar, ' := upper-case($v)[string()]')
                
        else
            error(QName((), 'UNKNOWN-POST-PROCESSING'), concat('processing mode=', $post))
};