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
                               [not(@name)]
                               [../(self::xs:element, self::xs:attribute)]
                for $ltype in $ltypes
                let $parent := $ltype/..
                let $parentKind := $parent/local-name()                
                let $parentName := app:getComponentName($parent)
                let $parentUri := namespace-uri-from-QName($parentName)
                let $parentLocalName := local-name-from-QName($parentName)

                let $ident := $parentUri || ' ~~~ ' || $parentLocalName || ' ~~~ ' || $parentKind
                group by $ident
                let $parentUri1 := $parentUri[1]
                let $parentLocalName1 := $parentLocalName[1]
                let $parentKind1 := $parentKind[1]
                for $ltypeInstance at $pos in $ltype
                let $typeLocalName := $parentLocalName1 || '___' || $parentKind1 || 'Type' || '___' || $pos 
                return (
                    insert node attribute xsdplus:lgtypeName {$typeLocalName} into $ltypeInstance,
                    insert node attribute xsdplus:lgtypeNamespace {$parentUri1} into $ltypeInstance
                )
            return
                $schemasContainer_/xs:schema
    
    (: attach @xspdlus:lgtypeName, @xsdplus:lgtypeNamespace to all anonymous types
       with an xs:union, xs:list or xs:restriction parent :)
    let $schemas03 :=
        let $schemasContainer := <schemas>{$schemas02}</schemas>
        return
            copy $schemasContainer_ := $schemasContainer     
            modify
                let $ltypes := $schemasContainer_//xs:simpleType[not(@name)][not(@xsdplus:lgtypeName)]
                for $ltype in $ltypes
                let $ltypeQName := f:getLgtypeNameForStypeInStype($ltype)
                let $ltypeLocalName := local-name-from-QName($ltypeQName)
                let $ltypeNamespace := namespace-uri-from-QName($ltypeQName)
                return (
                    insert node attribute xsdplus:lgtypeName {$ltypeLocalName} into $ltype,
                    insert node attribute xsdplus:lgtypeNamespace {$ltypeNamespace} into $ltype
                )
            return
                $schemasContainer_/xs:schema
    return 
        f:writeXsds($odir, $schemas03)     
};

(:~
 : Determines the pseudo global type name of a simple type locally
 : defined within a simple type definition (as child of xs:union,
 : xs:list or xs:restriction).
 :
 : @param ltype an anonymous type definition
 : @return the pseudo global type name
 :)
declare function f:getLgtypeNameForStypeInStype($ltype as element())
        as xs:QName {            
    let $masterType := $ltype/ancestor::xs:simpleType[1]
    return if (empty($masterType)) then
        error(QName((), 'PROGRAM_ERROR'),
            concat('function must not be called with an xs:simpleType which is ',
            'not descendant of an xs:simpleType.')) else
        
    let $masterTypeName := 
        if ($masterType/@name) then f:getComponentName($masterType)
        else if ($masterType/@xsdplus:lgtypeName) then 
            QName($masterType/@xsdplus:lgtypeNamespace, $masterType/@xsdplus:lgtypeName)
        else f:getLgtypeNameForStypeInStype($masterType)

    let $role := $ltype/parent::*/local-name(.)   (: union, list, restriction :)
    let $middlePart :=
        if ($role eq 'restriction') then 'simpleTypeRestrictionType'
        else if ($role eq 'list') then 'simpleTypeItemType'
        else if ($role eq 'union') then 'simpleTypeMemberType'
        else error()
    let $suffix :=
        if ($role eq 'union') then concat('___', count($ltype/preceding-sibling::xs:simpleType) + 1)
        else ()
    let $prefix :=
        let $masterTypeLocalName := local-name-from-QName($masterTypeName)
        return $masterTypeLocalName
    return
        QName($ltype/ancestor::xs:schema/@targetNamespace,
            concat($prefix, '_', $middlePart, $suffix))
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
        
