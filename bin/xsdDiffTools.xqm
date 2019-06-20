(:
 : -------------------------------------------------------------------------
 :
 : xsdDiffTools.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.xsdplus.org/ns/xquery-functions/xsddiff";
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

declare function f:componentName($comp as element(), $ignNamespaces as xs:boolean?)
        as xs:QName {
    if ($ignNamespaces) then $comp/QName((), @name) 
    else $comp/QName(ancestor::xs:schema/@targetNamespace, @name)        
};
