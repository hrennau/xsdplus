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
                    app:copyNamespaces($schema),
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
                let $parentLocalName := trace(local-name-from-QName($parentName) , 'PARENT_LNAME: ')
                let $tns := $ltype/ancestor::xs:schema/@targetNamespace/string()

                let $ident := $tns || ' ~~~ ' || $parentLocalName || ' ~~~ ' || $parentKind
                group by $ident
                let $tns1 := $tns[1]
                let $parentLocalName1 := $parentLocalName[1]
                let $parentKind1 := $parentKind[1]
                for $ltypeInstance at $pos in $ltype
                let $typeLocalName := $parentLocalName1 || '___' || $parentKind1 || 'Type' || '___' || $pos 
                return (
                    insert node attribute xsdplus:lgtypeName {$typeLocalName} into $ltypeInstance,
                    insert node attribute xsdplus:lgtypeNamespace {$tns1} into $ltypeInstance
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
                
    let $schemas04 :=
        for $schema in $schemas03
        return
            f:addGlobalTypeReferences($schema)
    return 
        f:writeXsds($odir, $schemas04)     
};

(:~
 : Determines the pseudo global type name of a simple type locally
 : defined within another simple type definition (as child of 
 : xs:union, xs:list or xs:restriction).
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
 : Edits a schema by replacing a contained local type definition by a
 : reference (@type, @base, @itemType or @unionType, as appropriate).
 :
 : @param xsd a schema element to be edited
 : @return the edited schema element
 :)
declare function f:addGlobalTypeReferences($xsd as element(xs:schema))
        as element(xs:schema) {
    let $lgTypes := $xsd//(xs:simpleType, xs:complexType)[@xsdplus:lgtypeName]
    
    (: step #1 - append new global type definition elements mirroring
     :    the local types contained by this schema :)
    let $xsdExtended :=
        element {node-name($xsd)} {
            app:copyNamespaces($xsd),
            $xsd/@*,
            $xsd/node(),
            for $lgType in $lgTypes
            return
                element {node-name($lgType)} {
                    attribute name {$lgType/@xsdplus:lgtypeName},
                    $lgType/@*,
                    $lgType/node()
                }
        }
    (: step #2 - replace local type child elements by an attribute
     :    referencing the corresponding pseudo global type
     :    (@type, @xs:list, @xs:union, as appropriate) :)
    let $xsdFinalized :=
        $xsdExtended/f:insertLgtypeReferences(.) 
    return
        $xsdFinalized
};  

(:~
 : Inserts type references (@type, @memberTypes, @itemType) and
 : removes local type definitions.
 :
 : @param n the node currently processed
 : @return the edited node
 :)
declare function f:insertLgtypeReferences($n as node())
        as node()? {
    typeswitch($n)
    case element(xs:union) return 
        if ($n/xs:simpleType) then
            let $localTypes := $n/xs:simpleType
            let $typeNameRefs := f:getTypeRefsForLocalTypes($n, $localTypes)
            return
                element {node-name($n)} {
                    $typeNameRefs?namespace-nodes,
                    $n/(@* except memberTypes),
                    attribute memberTypes {string-join(($n/@memberTypes, $typeNameRefs?names), ' ')},
                    $n/(node except xs:simpleType)
                }
        else
            element {node-name($n)} {
                for $a in $n/@* return f:insertLgtypeReferences($a),
                for $c in $n/node() return f:insertLgtypeReferences($c)
            }
    case element(xs:list) | element(xs:restriction) return 
        if ($n/xs:simpleType) then
            let $attName := if ($n/self::xs:list) then 'itemType' 
                            else if ($n/self::xs:restriction) then 'base'
                            else error()
            let $typeNameRef := f:getTypeRefsForLocalTypes($n, $n/simpleType)
            return
                element {node-name($n)} {
                    $typeNameRef?namespace-nodes,
                    for $a in $n/@* return f:insertLgtypeReferences($a),
                    attribute {$attName} {$typeNameRef?names},
                    for $c in $n/(node() except xs:simpleType) return f:insertLgtypeReferences($c)
                }
        else
            element {node-name($n)} {
                for $a in $n/@* return f:insertLgtypeReferences($a),
                for $c in $n/node() return f:insertLgtypeReferences($c)
            }
            
    case element() return
        let $localType := $n[not(self::xs:schema)]/(xs:simpleType, xs:complexType)
        return
            if ($localType) then
                let $typeNameRef := f:getTypeRefsForLocalTypes($n, $n/(xs:simpleType, xs:complexType))
                return
                    element {node-name($n)} {
                        $typeNameRef?namespace-nodes,
                        $n/@*,
                        attribute type {$typeNameRef?names},
                        $n/(node() except (xs:simpleType, xs:complexType))
                    }
            else
                element {node-name($n)} {
                    app:copyNamespaces($n),
                    for $a in $n/@* return f:insertLgtypeReferences($a),
                    for $c in $n/node() return f:insertLgtypeReferences($c)
                }
    default return $n                        
};

(:~
 : Returns for a given context and a sequence of local type elements
 : a map providing the names of the type references resolvable in the
 : context $context. Any required additional namespace nodes are
 : provided by map entry 'namespace-nodes'. The names (whitespace-
 : separated list of lexical names) are provided by map entry
 : 'names'.
 :
 : @param context the element in whose context the references must
 :    be resolvable
 : @param the local types for which references shall be found
 : @return a map with two entries, 'names' providing the reference
 :    names, and 'namespace-nodes' any additional namespace nodes
 :    required
 :)
declare function f:getTypeRefsForLocalTypes($context as element(),
                                            $localTypes as element()+)
        as map(*)+ {
        (: as map(xs:string, item()+) :)
    f:getTypeRefsForLocalTypesRC($context, $localTypes, ())
};

declare function f:getTypeRefsForLocalTypesRC($context as element(),
                                              $localTypes as element()+,
                                              $intermediateMap as map(xs:string, item()*)?)
        as map(*) {                                              
        (: as map(xs:string, item()+) { :)
    let $DUMMY := trace($localTypes, 'RECEIVE_LOCAL_TYPES: ')
    let $head := head($localTypes)
    let $tail := tail($localTypes)
    let $localName := trace( trace($head, 'HEAD: ')/@xsdplus:lgtypeName , 'LOCAL_NAME: ')
    let $namespace := $head/@xsdplus:lgtypeNamespace
    let $newMap := f:getQNameRefForContext($context, $localName, $namespace)
    let $newIntermediateMap :=
        if (empty($intermediateMap)) then 
            map{'names': $newMap?name, 'namespace-nodes': $newMap?namespace-node}
        else 
            let $map := map:put($intermediateMap, 'names', $intermediateMap?names || ' ' || $newMap?name)
            let $map := map:put($map, 'namespace-nodes', ($intermediateMap?namespace-nodes, $newMap?namespace-node))
            return $map
    return
        if (empty($tail)) then $newIntermediateMap
        else
            let $newContext :=
                let $newNamespaceNode := $newMap?namespace-node
                return
                    if (not($newNamespaceNode)) then $context
                    else
                        element {node-name($context)} {
                            app:namespaceNodes($context),
                            $newNamespaceNode
                        }
            return
                f:getTypeRefsForLocalTypesRC($newContext, $tail, $newIntermediateMap)
};          
        

(:~
 : Returns a map providing a lexical QName to be used as a resolvable reference 
 : in the context of an element $context. If the required namespace binding is 
 : not among the in-scope namespace bindings of $context, the map contains a
 : second entry whose value is the required namespace node. Map keys are
 : 'name' and 'namespace-node'.
 :
 : @TO.DO - how to deal with the case (a) no namespace, (b) context has a default namespace ?
 :)
declare function f:getQNameRefForContext($context as element(), 
                                         $localName as xs:string, 
                                         $namespace as xs:string?)
        as map(xs:string, item()) {
    if (not($namespace)) then map{'name': $localName} else
    
    map:merge(        
        let $prefixes := in-scope-prefixes($context)
        let $prefix :=
            $prefixes[namespace-uri-for-prefix(., $context) eq $namespace][1]
        return
            if ($prefix) then map:entry('name', string-join(($prefix[string()], $localName), ':'))
        else
            let $prefix := f:getNewPrefix($prefixes, 'ns', 1)
            return (
                map:entry('name', string-join(($prefix[string()], $localName), ':')),
                map:entry('namespace-node', namespace {$prefix} {$namespace})
            )
    )            
};

(:~
 : Finds a prefix not found in a given set of prefixes.
 :
 : @param prefixes the prefixes which must not contain the prefix returned by this function
 : @param base sequence of characters with which the prefix must begin
 : @param number if the concatenation of $base and $number is not found in $prefixes,
 :    return that value, otherwise try the number which is $number + 1
 : @param return a prefix which is not found in $prefixes and is equal to the concatenation 
 :   of $base and a natural number
 :) 
declare function f:getNewPrefix($prefixes as xs:string*, $base as xs:string, $suffix as xs:integer)
        as xs:string {
    let $prefix := concat($base, $suffix)
    return
        if ($prefix = $prefixes) then f:getNewPrefix($prefixes, $base, $suffix + 1)
        else $prefix        
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
        let $qfname := trace( concat($odir, '/', $fname) , 'QFNAME: ')
        return
            file:write($qfname, $schema)
    else if (count($schemas) eq 1) then $schemas
    else error()
};
        
