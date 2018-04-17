(:
 : -------------------------------------------------------------------------
 :
 : constants.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
module namespace f="http://www.xsdplus.org/ns/xquery-functions";

declare namespace c="http://www.xsdplus.org/ns/xquery-functions";

declare variable $c:LOG_LEVEL as xs:integer external := 0;
declare variable $c:TOLERATE_COMPONENT_DUPLICATES as xs:integer external := 1;
declare variable $c:URI_XSD as xs:string := 'http://www.w3.org/2001/XMLSchema';
declare variable $c:ANY_TYPE as xs:QName := QName($c:URI_XSD, 'anyType');
declare variable $c:URI_LTREE as xs:string := 'http://www.xsdplus.org/ns/structure';
declare variable $c:URI_BTREE as xs:string := 'http://www.xsdr.org/ns/structure';
declare variable $c:URI_ERROR as xs:string := 'http://www.xsdplus.org/ns/errors';
declare variable $c:_DEBUGFILE_RECURSION_PATHS as xs:string := 'LTREE_RECURSION_PATHS.txt';
(:~
 : Returns the items received, logging the value if the specified log level
 : is greater or equal the global constant $m:LOG_LEVEL.
 :
 : @param logLevel the log level of the log message
 : @param msg trace message, used if items are traced
 : @return the items received
 :)
declare function f:log($items as item()*, $logLevel as xs:integer, $msg as xs:string)
        as item()* {
    if ($logLevel le $c:LOG_LEVEL) then trace($items, $msg) else $items        
};        