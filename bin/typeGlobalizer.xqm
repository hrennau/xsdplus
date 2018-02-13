(:~
 : -------------------------------------------------------------------------
 :
 : typeGlobalizer.xqm - operation and public function for globalizing local types
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="globalizeTypes" type="element()?" func="globalizeTypesOp">
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="odir" type="directory?" fct_dirExists="true"/>
         <pgroup name="in" minOccurs="1"/>    
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
    "locationTreeComponents.xqm",
    "locationTreeNormalizer.xqm",
    "occUtilities.xqm",
    "substitutionGroups.xqm";
    
declare namespace c="http://www.xsdplus.org/ns/xquery-functions";    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";
declare namespace ns0="http://www.xsdr.org/ns/structure";
declare namespace xsdplus="http://www.xsdplus.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `globalizeTypes`. The operation transforms local types
 : in global types.
 :
 : @param request the operation request
 : @return a modified schema, if there is only one schema and parameter
 :    $odir has not been specified, the empty sequence otherwise
 :) 
declare function f:globalizeTypesOp($request as element())
        as element()? {
    let $schemas := app:getSchemas($request)
    let $odir := tt:getParam($request, 'odir')
    return
        f:globalizeTypes($odir, $schemas)
};     

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `globalizeTypes`. The operation transforms local types
 : in global types.
 :
 : @param request the operation request
 : @return a modified schema, if there is only one schema and parameter
 :    $odir has not been specified, the empty sequence otherwise
 :) 
declare function f:globalizeTypes($odir as xs:string?,
                                  $schemas as element(xs:schema)+)
        as element()? {                         
    
    let $ltypes := $schemas//(xs:simpleType, xs:complexType)[not(@name)]
    return
        if (not($ltypes)) then f:writeXsds($odir, $schemas)
        else
      
    (: take care that each xs:schema has an explicit @xml:base :)
    let $schemas01 :=
        for $schema in $schemas return
            if ($schema/@xml:base) then $schema
            else 
                element {node-name($schema)} {
                    $schema/@*, 
                    attribute xml:base {$schema/base-uri(.)}, 
                    $schema/node()
                }
    
    (: attach @xspdlus:lgtypeName, @xsdplus:lgtypeNamespace to all anonymous types
       with an element or attribute parent :)
    let $schemas02 :=
        let $schemasContainer := <schemas>{$schemas01}</schemas>
        return
            copy $schemasContainer_ := $schemasContainer     
            modify
                let $ltypes := $schemasContainer_
                               //(xs:simpleType, xs:complexType)
                               [not((@name, @ref))]
                               [../(self::xs:element, self::xs:attribute)]
                for $ltype in $ltypes
                let $parent := $ltype/..
                let $parentKind := $parent/local-name()                
                let $parentName := app:getComponentName($parent)
                let $parentUri := namespace-uri-from-QName($parentName)
                let $parentLocalName := local-name-from-QName($parentName)

                let $ident := $parentUri || ' ~~~ ' || $parentLocalName || ' ~~~ ' || $parentKind
                group by $ident
                for $ltypeInstance at $pos in $ltype
                let $typeLocalName := $parentLocalName[1] || '___' || $parentKind[1] || 'Type' || '___' || $pos 
                return (
                    insert node attribute xsdplus:lgtypeName {$typeLocalName} into $ltypeInstance,
                    insert node attribute xsdplus:lgtypeNamespace {$parentUri} into $ltypeInstance
                )
            return
                $schemasContainer_/xs:schema
                
    (: To.Do - schemas03 - lgtypeName and lgtypeNamespace for simple types contained by
                           @restriction, @list, @union child of xs:simpleType;
                           this requires a function for determining the name, as recursive
                           calls are necessary if the simple type above @restriction etc.
                           is itself a local-global type which does not yet have a name.
                           
    return
        f:writeXsds($odir, $schemas02)    
};

(:~
 : Writes a set of schemas into a folder, or returns the schema
 : if no folder has been specified and the number of schemas
 : is greater than 1.
 :
 : @param odir output folder
 : @param schemas the schemas to be written
 : @return either the only schemas there is, or nothing as
 :     the schemas are written into the folder
 :)
declare function f:writeXsds($odir as xs:string?,
                             $schemas as element(xs:schema)+)
        as element(xs:schema)? {
    if ($odir) then        
        for $schema in $schemas
        let $docuri := $schema/base-uri(.)
        let $fname := replace($docuri, '.+(/|\\)', '')
        let $qfname := concat($odir, '/', $fname)
        return
            file:write($qfname, $schema)
    else if (count($schemas) eq 1) then $schemas
    else error()
};
        
