(:
 : -------------------------------------------------------------------------
 :
 : jsonSchema.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="jschema" type="item()" func="jschema_old">     
         <param name="btree" type="docURI*" fct_rootElem="baseTrees" sep="WS"/>
         <param name="ename" type="nameFilter?"/>         
         <param name="format" type="xs:string?" fct_values="xml, json" default="json"/>         
         <param name="mode" type="xs:string?" default="rq" fct_values="rq,rs, ot"/>        
         <param name="skipRoot" type="xs:boolean?" default="false"/>         
         <param name="top" type="xs:boolean?" default="true"/>
         
      </operation>
      <operation name="jschemas" type="item()" func="jschemas_old">     
         <param name="dir" type="xs:string"/>      
         <param name="btree" type="docURI*" fct_rootElem="baseTrees" sep="WS"/>
         <param name="ename" type="nameFilter?"/>         
         <param name="format" type="xs:string?" fct_values="xml, json" default="json"/>         
         <param name="mode" type="xs:string?" default="rq" fct_values="rq,rs, ot"/>       
         <param name="skipRoot" type="xs:boolean?" default="false"/>         
         <param name="top" type="xs:boolean?" default="true"/>        
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

import module namespace ap="http://www.xsdplus.org/ns/xquery-functions" at 
    "baseTreeInspector.xqm";    

declare namespace z="http://www.xsdplus.org/ns/structure";

declare variable $f:debugDir := (); (:  '/projects/gateway/json-schema'; :)
declare variable $f:debugSerMethodText := map { "method": "text"};

declare variable $f:typeDictionary :=
        <types>
            <type x="boolean" j="boolean"/>
            <type x="integer" j="integer"/>            
            <type x="nonPositiveInteger" j="integer">
                <constraint name="maximum" value="0"/>
            </type>
            <type x="negativeInteger" j="integer">
                <constraint name="maximum" value="-1"/>
            </type>
            <type x="long" j="integer"/>
            <type x="int" j="integer"/>
            <type x="short" j="integer"/>
            <type x="byte" j="integer"/>
            <type x="nonNegativeInteger" j="integer">
                <constraint name="minimum" value="0"/>
            </type>
            <type x="positiveInteger" j="integer">
                <constraint name="minimum" value="1"/>
            </type>
            <type x="unsignedLong" j="integer">
                <constraint name="minimum" value="0"/>
            </type>
            <type x="unsignedInt" j="integer">
                <constraint name="minimum" value="0"/>
            </type>
            <type x="unsignedShort" j="integer">
                <constraint name="minimum" value="0"/>
            </type>
            <type x="unsignedByte" j="integer">
                <constraint name="minimum" value="0"/>
            </type>
            <type x="float" j="number"/>
            <type x="double" j="number"/>            
            <type x="decimal" j="number"/>            
        </types>;

declare variable $f:constraintTypes :=
    <constraints>
        <enum type="array"/>    
        <maxItems type="integer"/>
        <minItems type="integer"/>
        <maxLength type="integer"/>
        <minLength type="integer"/>
        <multipleOf type="number"/>
        <minimum type="number"/>
        <maximum type="number"/>
        <minimumExclusive type="boolean"/>
        <maximumExclusive type="boolean"/>
        <pattern type="string"/>        
    </constraints>;
    
(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)
    
(:~
 : Transforms an XSD schema into a JSON schema.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:jschema_old($request as element())
        as item() {
    (: $f:debugDir ! file:write(concat(., '/log.xml'), '<log>', $f:debugSerMethodText),:)        
    let $btree := tt:getParams($request, 'btree')
    let $ename := tt:getParams($request, 'ename')    
    let $top := tt:getParams($request, 'top')
    let $skipRoot := tt:getParams($request, 'skipRoot')    
    let $format := tt:getParams($request, 'format')

    let $btreeRootElem := 
        let $btreeRootElems := trace( $btree/descendant::z:baseTree/f:getBtreeRoot(.) , 'BTREE: ')
        return
            if ($ename) then                
                if ($top) then $btreeRootElems[tt:matchesNameFilter(local-name(.), $ename)][1]
                else ($btreeRootElems/descendant-or-self::*[tt:matchesNameFilter(local-name(.), $ename)])[1]            
            else    
                $btree/descendant::z:baseTree[1]/f:getBtreeRoot(.)
    return
        f:getJschema($btreeRootElem, $skipRoot, $format)
(:        
    let $broot := 
        let $broots := $btree/*/*/f:getBtreeRoot(.)
        return
            if ($ename) then                
                if ($top) then $broots[tt:matchesNameFilter(local-name(.), $ename)][1]
                else ($broots/descendant-or-self::*[tt:matchesNameFilter(local-name(.), $ename)])[1]            
            else    
                $btree/*/z:baseTree[1]/f:getBtreeRoot(.)
    return
    if (not($broot)) then
        tt:createError('INVALID_ARG', 'No element found.', ())
        else
    
    let $jsx := f:_xsd2Jschema($broot)
    return (
        if ($format eq 'xml') then $jsx
        else json:serialize($jsx)
    )
:)
(:
    return 
        , if (1 eq 2) then () else
            let $mode := tt:getParams($request, 'mode')
            let $fname := 
                if ($mode eq 'rq') then 'regionrq-jschema.json' 
                else if ($mode eq 'rs') then 'regionrs-jschema.json' 
                else 'otds-jschema.json'
            return (
                file:write(concat('d:/ws01/json-validation/json/', $fname), json:serialize($jsx)),
                file:write(concat('c:/projects/gateway/json-schema/', $fname), json:serialize($jsx))
            )                
    )
:)    
};      

(:~
 : Creates for each top level element descriptor of a base tree a JSON schema.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:jschemas_old($request as element())
        as element() {
    let $dir := tt:getParams($request, 'dir')    
    let $btree := tt:getParams($request, 'btree')/*
    let $skipRoot := tt:getParams($request, 'skipRoot')    
    let $format := tt:getParams($request, 'format')
    let $ename := trace(tt:getParams($request, 'ename') , 'ENAME: ')
    let $top := tt:getParams($request, 'top')    
    (:
    let $btreeElems := $btree//z:baseTree/f:getBtreeRoot(.)
    :)
    let $btreeElems :=
        let $btreeRootElems := $btree/descendant::z:baseTree/f:getBtreeRoot(.)
        return
            if ($ename) then
                if ($top) then $btreeRootElems[tt:matchesNameFilter(local-name(.), $ename)][1]
                else ($btreeRootElems/descendant-or-self::*[tt:matchesNameFilter(local-name(.), $ename)])[1]            
            else    
                $btreeRootElems

    let $jschemas :=
        for $btreeElem in $btreeElems
        let $elemName := trace($btreeElem/local-name(.), 'create json schema for elem: ')
        let $jschema := f:getJschema($btreeElem, $skipRoot, $format)
        let $fname := concat($dir, '/', $elemName, '_schema.json')
        return ( 
            (: file:write($fname, $jschema), :)
            <z:jschema elem="{$elemName}" uri="{$fname}"/>
        )
    return
        <z:jschemas count="{count($jschemas)}">{
            $jschemas
        }</z:jschemas>
};

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Transforms a base tree element descriptor into a JSON schema.
 :
 : @param btreeElem the base tree element descriptor for which a JSON schema is requested
 : @return the JSON schema representing the base tree element descriptor
 :) 
declare function f:getJschema($btreeElem as element(),
                              $skipRoot as xs:boolean?,
                              $format as xs:string?)
        as item() {       
    let $jsx := f:_xsd2Jschema($btreeElem, $skipRoot)
    return (
        if ($format eq 'xml') then $jsx
        else json:serialize($jsx)
    )
};      

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Transforms a base tree into a JSON schema.
 :
 : @param broot the root element of the base tree
 : @return a JSON schema capturing the constraints of the source XSD
 :)
declare function f:_xsd2Jschema($broot as element(), $skipRoot as xs:boolean?)
        as element() {
    let $contents := f:_xsd2JschemaRC($broot)
    let $raw :=
        <json type="object">{
            <_0024schema>http://json-schema.org/draft-04/schema#</_0024schema>,
            if (not($skipRoot)) then (
                <type>object</type>,
                <properties type="object">{$contents}</properties>
            ) else $contents/*
(:            
            $contents/*   (: currently, the root element is NOT represented in JSON :) 
            (:  $contents   (: root element now included :) :)
            (: <additionalProperties type="boolean">false</additionalProperties> :)
:)            
        }</json>
    let $jschema := f:_finalizeJschema($raw)
    return
        $jschema
};

(:~
 : Finalizes the a JSON schema provided and delivered in the xjson format.
 :)
declare function f:_finalizeJschema($jschema as element(json))
        as element(json) {
    let $stypeElems := $jschema//*[@___stype]
    return
        if (empty($stypeElems)) then $jschema else
        
    let $definitions :=
        <definitions type="object">{
            for $stypeElem in $stypeElems
            group by $stype := $stypeElem/@___stype
            let $stypeElem1 := $stypeElem[1]
            let $useName := replace(replace($stype, '_', '__'), ':', '_003a')
            order by lower-case($stype)
            return
                element {$useName} {
                    $stypeElem1/(@* except @___stype),
                    $stypeElem1/node()
                }                
        }</definitions>
    return
        f:_finalizeJschemaRC($jschema, $definitions)        
};

(:~
 : Recursive helper function of '_finalizeSchema'. Models with
 : @___stype are edited - type contents are replaced by type reference
 :)
declare function f:_finalizeJschemaRC($n as node(), $definitions as element(definitions))
        as node()? {
    typeswitch($n)        
    case document-node() return
        document {for $c in $n/node() return f:_finalizeJschemaRC($c, $definitions)}
    case element(json) return   
        element {node-name($n)} {
            for $a in $n/@* return f:_finalizeJschemaRC($a, $definitions),
            for $c in $n/node() return f:_finalizeJschemaRC($c, $definitions),
            $definitions
        }
    case element() return
        if ($n/@___stype) then
            let $typeName := $n/@___stype
            return
                element {node-name($n)} {
                    $n/(@* except @___stype),
                    <_0024ref>{concat('#/definitions/', $typeName)}</_0024ref>
                }
        else
            element {node-name($n)} {
                for $a in $n/@* return f:_finalizeJschemaRC($a, $definitions),
                for $c in $n/node() return f:_finalizeJschemaRC($c, $definitions)
            }
    default return $n            
};

(:~
 : Recursive helper function of '_xsd2Jschema.
 :)
declare function f:_xsd2JschemaRC($n as node())
        as element()* {
    if ($n/(z:_attributes_ or z:_choice_ or z:_sequence_ or z:_all_ or (* except z:*))) then f:_xsd2JschemaRC_complex($n)
    else f:_xsd2JschemaRC_simple($n)
};        

(:~
 : Creates a JSON schema for a complex element. Called during recursion over a base tree.
 : The sub schemas for attributes and child elements are contributed by calls of 
 : '_simpleItemSonSchema' (simple content) and recursive calls of this function (complex 
 : content).
 :
 : @param n a base tree node descriptor
 : @return a JSON schema
 :)
declare function f:_xsd2JschemaRC_complex($n as node())
        as element()* {
    let $elemName := $n/local-name(.)  
    let $elemNameJ := f:_xname2Jname($elemName)
    let $minOccurs := ($n/@minOccurs, '1')[1]
    let $maxOccurs := ($n/@maxOccurs, '1')[1]
    let $typeVariant := $n/@z:typeVariant
    let $itemType := if ($maxOccurs ne '1') then 'array' else 'object'  
    
    let $atts := $n/z:_attributes_/z:_attribute_
    let $childElems := ap:getBnodeChildElemDescriptors($n)
    
    (: JSON cannot handle duplicate keys - skip child elems with a repeated name :)
    let $childElems :=
        let $names := $childElems/local-name()
        let $namesD := distinct-values($names)
        return
            if (count($names) eq count($namesD)) then $childElems
            else
                let $duplicates := 
                    for $name in $namesD
                    where count($names[. eq $name]) gt 1
                    return
                        tail($childElems[local-name(.) eq $name])
                 return
                    $childElems except $duplicates
    
    let $attSchemas :=
        for $att in $atts return f:_xsd2Jschema_simpleItem($att, ())
            
    let $textContentSchema :=
        if (not($typeVariant eq 'cs')) then () else f:_xsd2Jschema_simpleItem($n, xs:NCName('value'))
        
    let $elemSchemas :=
        for $c in $childElems
        let $isComplex := 
            $c/(z:_attributes_, z:_choice_, z:_sequence_, z:_all_) 
                or $c/(* except z:*)   (: TODO - INSPECTOR FUNCTION :)
        return
            if ($isComplex) then f:_xsd2JschemaRC_complex($c)
            else f:_xsd2Jschema_simpleItem($c, ())

    let $childSequence := $n/*[not(self::z:*) or self::z:_choice_ or self::z:_sequence_ or self::z:_all_]
    let $childSeqDesc := 
        if (empty($childSequence)) then () else
            f:_sequenceDescriptor($childSequence)           
    let $childSeqDesc := ($childSeqDesc
        , if (not($childSeqDesc)) then () else $f:debugDir ! file:append(concat(., '/log.xml'), serialize($childSeqDesc), $f:debugSerMethodText))       
    let $required :=
        let $mand := $childSeqDesc/mandatory/tokenize(., ' ')
        return
            if (empty($mand)) then () else
                <required type="array">{
                    for $name in $mand return <_>{$name}</_>
                }</required>
                
    let $choiceEnforcers:=
        if ($childSeqDesc/choices/
            (@count eq '0' or @choiceElemsOverlapChoiceElems eq 'true' or @choiceElemsOverlapNonChoiceElems eq 'true')) then ()
        else (        
            for $choice in $childSeqDesc/choices/*
            let $branches := $choice/branch
            let $mandatoryBranches := $branches[@mandatoryElems ne '']
            let $optionalBranches := $branches[@mandatoryElems eq '']            
            return
                <oneOf type="array">{
                    (: mandatory branches :)
                    for $branch in $mandatoryBranches
                    let $mandatoryElems := $branch/@mandatoryElems/tokenize(., ' ')
                    return
                        <_ type="object">{                    
                            <required type="array">{
                                for $elem in $mandatoryElems return <_>{$elem}</_>
                            }</required>
                        }</_>,
                        
                    (: optional branches - for each branch a schema which applies if the branch has been used :)
                    for $branch in $optionalBranches
                    let $optionalElems := $branch/@elems/tokenize(., ' ')
                    return
                        <_ type="object">{              
                            <anyOf type="array">{
                                for $elem in $optionalElems
                                return
                                    <_ type="object">{                                
                                        <required type="array">{
                                            <_>{$elem}</_>
                                        }</required>
                                    }</_>
                            }</anyOf>                                
                        }</_>,
                    
                    if (empty($optionalBranches) and $choice/@isOptional eq 'false') then () else
                    
                    (: case: optional choice not used :)
                    let $allChoiceElems := distinct-values($branches/@elems/tokenize(., ' '))
                    return
                        <_ type="object">{
                            <not type="object">{
                                <anyOf type="array">{
                                    for $elem in $allChoiceElems return
                                        <_ type="object">{
                                            <required type="array">{
                                                <_>{$elem}</_>
                                            }</required>
                                        }</_>
                                }</anyOf>
                            }</not>
                        }</_>                            
                }</oneOf>       
        )
    let $choiceEnforcers :=
        if (count($choiceEnforcers) le 1) then $choiceEnforcers
        else <allOf type="array">{$choiceEnforcers/<_ type="object">{.}</_>}</allOf>
            
    let $properties :=
        <properties type="object">{
            $attSchemas,
            $textContentSchema,
            $elemSchemas
        }</properties>
            
    return
        element {$elemNameJ} {
            attribute type {'object'},
            
            (: case: maxOccurs=1 => object :)
            if ($itemType eq 'object') then (
                <type>object</type>,            
                $properties,
                <additionalProperties type="boolean">false</additionalProperties>,
                $required,
                $choiceEnforcers
            )                
            (: case: maxOccurs>1 => array :)            
            else
                let $occConstraints := (
                    if ($minOccurs eq "0") then () else 
                        <minItems type="number">{xs:integer($minOccurs)}</minItems>,
                    if ($maxOccurs eq "1") then () else
                        let $useMaxOccurs := if ($maxOccurs eq 'unbounded') then 999 else xs:integer($maxOccurs)
                        return
                            <maxItems type="number">{$useMaxOccurs}</maxItems>
                )
                return (
                    <type>array</type>,
                    $occConstraints,          (: hjr, 20151222 :)          
                    <items type="object">{
                        <type>object</type>,
                        (: $occConstraints, :)       (: hjr, 20151222 :)
                        $properties,
                        <additionalProperties type="boolean">false</additionalProperties>
                    }</items>
                )                
        }       
};        

(:~
 : Creates a JSON schema for a base tree item with a simple type. The type
 : can be atomic, a list type or a union type. In the case of built-in types,
 : type information is retrieved from the @z:type attribute of the base
 : tree node descriptor; in the case of a user-defined type, type information
 : is retrieved from the z:_stypeInfo_ child element of the node descriptor.
 :
 : Note. The item is described as an array if (a) maxOccurs != 1, (b) the
 : parameter 'propName' is not set to the value 'value'. Conditions (b)
 : refers to the use of this function for the text content of a complex
 : element with simple content. 
 :
 : Note. The 'propName' parameter should only be used when dealing wth the
 : text content of a complex element with simple content. In this case,
 : the value specified should be 'value'.
 :
 : @param item base tree descriptor of an attribute or element with simple content
 : @param propName if specified, the JSON property set to the JSON schema has this
 :   name; default name is the name of the supplied attribute or element
 : @return a JSON schema describing the item
 :)
declare function f:_xsd2Jschema_simpleItem($item as element(), 
                                           $propName as xs:NCName?)
        as element() {
    let $usePropName :=
        if ($propName) then $propName 
        else if ($item/self::z:_attribute_) then $item/@name 
        else $item/local-name(.)
    let $usePropName := f:_xname2Jname($usePropName) ! xs:NCName(.)
    let $maxOccurs := ($item/@maxOccurs, '1')[1]
    let $minOccurs := ($item/@minOccurs, '1')[1]    
    
    let $isArray := $maxOccurs ne '1' and not($propName eq 'value')    
    let $typeInfo := $item/z:_stypeInfo_
    let $typeName := $item/@z:type/string()
    
    let $itemSchema :=
        (: no type specified => no constraints :)
        if (empty(($typeInfo, $typeName))) then  element {$usePropName} {attribute type {'object'}}
        (: a type is specified :)             
        else 
            let $component := f:_xsd2Jschema_simpleTypeOrTypeMember($usePropName, $typeInfo, $typeName)
            return
                if (not($typeName) or $typeName eq 'z:_LOCAL_' or 0) then $component
                else
                    element {node-name($component)} {attribute ___stype {$typeName}, $component/@*, $component/node()}
    return
        (: case: maxOccurs=1 => simple item :)
        if (not($isArray)) then $itemSchema
        
            (: case: maxOccurs>1 => array :)        
        else
            let $occConstraints := (
                if ($minOccurs eq "0") then () else 
                    <minItems type="number">{xs:integer($minOccurs)}</minItems>,
                if ($maxOccurs eq "1") then () else
                    let $useMaxOccurs := if ($maxOccurs eq 'unbounded') then 999 else xs:integer($maxOccurs)
                    return
                        <maxItems type="number">{$useMaxOccurs}</maxItems>
            )
            return 
                element {$usePropName} {
                    attribute type {'object'},
                    <type>array</type>,                    
                    $occConstraints,          
                    <items type="object">{
                        $itemSchema/(@___stype, *)
                    }</items>
            }                
};

(:~
 : Creates a JSON schema for a simple type. The type may be a complete type, or
 : a union member type.
 :
 : @param typeInfo an element describing the details of a simple type
 :    or of a union member type
 : @param propName the name of the property set to the JSON schema 
 :    (attribute or element name, or '_' if dealing with a union member)
 : @return an xjson element representing a name value pair whose value is
 :    a JSON schema
 :)
declare function f:_xsd2Jschema_simpleTypeOrTypeMember($propName as xs:NCName, 
                                                       $typeInfo as element()?, 
                                                       $typeName as xs:string?)
        as element() {
    if ($typeInfo/z:_list_) then 
        f:_xsd2Jschema_simpleType_list($propName, $typeInfo)
    else if ($typeInfo/z:_union_) then 
        f:_xsd2Jschema_simpleType_union($propName, $typeInfo)           
    else 
        f:_xsd2Jschema_simpleType_atom($propName, $typeInfo, $typeName)
};

(:~
 : Creates a JSON schema for a simple atomic type. The type may be a complete
 : type or a union member type. The supplied type information is either a type 
 : descriptor (z:_typeInfo_ element), or a type descriptor fragment describing 
 : a union member (z:_member_ element), or the name of a built-in type.
 :
 : @param propName the name of the property set to the JSON schema 
 :    (attribute or element name, or '_' if dealing with a union member)
 : @param typeInfo an element describing the details of a simple type
 :    or of a union member type
 : @param typeName the name of the type, which is a built-in type
 : @return an xjson element representing a name value pair whose value is
 :    a JSON schema
 :)
declare function f:_xsd2Jschema_simpleType_atom($propName as xs:NCName, 
                                                $typeInfo as element()?, 
                                                $typeName as xs:string?)
        as element() {
            
    let $baseType := 
        if ($typeInfo) then $typeInfo/z:_sbType_/@name else replace($typeName, '.+:', '')    
    let $typeAndConstraints :=  f:_getTypeAndConstraints_atomicItem($typeInfo, $baseType)    
    let $jsonModel :=
        element {$propName} {           
            attribute type {'object'},
            $typeAndConstraints
        }            
    return
        $jsonModel 
};

(:~
 : Creates a JSON schema for a list type. The type may be a complete type, or
 : a union member type.
 :
 : @param propName the name of the property set to the JSON schema 
 :    (attribute or element name, or '_' if dealing with a union member)
 : @param typeInfo an element describing the details of a simple type
 :    or of a union member type
 : @param typeName the name of the type
 : @return an xjson element representing a name value pair whose value is
 :    a JSON schema
 :)
declare function f:_xsd2Jschema_simpleType_list($propName as xs:NCName, 
                                                $typeInfo as element())
        as element() {            
    let $baseType := $typeInfo/z:_list_/z:_sbType_/@name
    let $unionType := $typeInfo/z:_list_/z:_union_
    let $itemTypeAndConstraints :=  
        if ($baseType) then f:_getTypeAndConstraints_atomicItem($typeInfo, $baseType)
            (: union: no self-contained property => use the child elem :)        
        else if ($unionType) then f:_xsd2Jschema_simpleType_union(xs:NCName('DUMMY'), $typeInfo)/*            
        else error(QName((), 'DATA_ERROR'), 'Unexpected type descriptor - list items must be atomic or union')
        
    let $listConstraints :=  f:_getListConstraints($typeInfo)    
    let $jsonModel :=
        element {$propName} {
            attribute type {'object'},
            <type>array</type>,
            <items type="object">{$itemTypeAndConstraints}</items>,
            $listConstraints,
            <additionalItems type="boolean">false</additionalItems>
        }        
    return
        $jsonModel
};

(:~
 : Creates a JSON schema for an item with a union type. The type might be the type of a
 : base tree item, or a union member type.
 :
 : @param propName the name of the property set to the JSON schema 
 :    (attribute or element name, or '_' if dealing with a union member)
 : @param typeInfo an element describing the details of a simple type
 :    or of a union member type
 : @param typeName the name of the type
 : @return an xjson element representing a name value pair whose value is
 :    a JSON schema
 :)
declare function f:_xsd2Jschema_simpleType_union($propName as xs:NCName, 
                                                 $typeInfo as element())
        as element() {
    element {$propName} {
        attribute type {'object'},
        <anyOf type="array">{
            for $member in $typeInfo/descendant::z:_union_[1]/z:_member_
            return
                f:_xsd2Jschema_simpleTypeOrTypeMember(xs:NCName('_'), $member, ())
        }</anyOf>
    }
};        

(:~
 : Maps an XML name to a name used in the XML representation of JSON, as
 : defined by BaseX.
 :
 : @param name an XML name
 : @return the name used in the XML representation of JSON
 :)
declare function f:_xname2Jname($name as xs:string)
        as xs:string {
    replace($name, '_', '__')        
};

declare function f:_xsdPattern2JsonPattern($pattern as xs:string) {
    let $p := $pattern
    let $p := 
        if (contains($p, '|')) then concat('^(', $pattern, ')$')
        else concat('^', $p, '$')
    return 
        $p
};


(:~
 : Creates the JSON schema for an atomic item, which may be a complete type or a union member type.
 : The type is described either by a type descriptor or the type name. A type descriptor is
 : either a z:_typeInfo_ element, or a z:_member_ element, depending if the type is a complete type
 : or a union member type.
 :
 : @param typeInfo an element describing the details of a simple type
 :    or of a union member type
 : @param typeName the name of the built-in type
 : @return the content of the JSON model, consisting of a type element and optional contraint elements
 :)
declare function f:_getTypeAndConstraints_atomicItem($typeInfo as element()?, $typeName as xs:string)
        as element()* {

    let $restrictions :=
        if ($typeInfo/z:_list_) then $typeInfo/z:_list_/z:_restriction_
        else $typeInfo/z:_restriction_
        
    (: typeMeta provides the JSON types as well as type implied constraints :)
    let $baseTypeName :=
        let $typeInfoName :=
            if ($typeInfo/z:_list_) then $typeInfo/z:_list_/z:_sbType_/@name/string()
            else $typeInfo/z:_sbType_/@name/string()
        return ($typeInfoName, $typeName)[1]
        
    let $typeMeta := $f:typeDictionary/(type[@x eq $baseTypeName], <type x="other" j="string"/>)[1]
    let $jsonType := $typeMeta/@j/string()
    
    (: type element expressing the JSON type :)
    let $typeElem := <type>{$jsonType}</type>

    (: constraints implied by the XSD type (e.g. 'positiveInteger' => minimum=1) :)
    let $typeConstraints := (
        for $c in $typeMeta/constraint
        let $name := $c/@name
        let $type := $f:constraintTypes/*[local-name(.) eq $name]/@type
        return
            element {$name} {
                if ($type ne 'string') then attribute type {$type} else (),
                $c/@value/string()
            }
    )
    
    (: constraints implied by user-defined facets :)    
    let $facetConstraints := (
    
        (: minInclusive :)
        let $minInclusive :=
            (: JSON does not support non-numeric minimum :)
            if (not($jsonType = ('integer', 'number'))) then () else                   
                ($restrictions/z:_minInclusive_)[last()]/@value/string()                    
        return        
             if (empty($minInclusive)) then () else <minimum type="number">{$minInclusive}</minimum>
        ,            
        (: minExclusive :)
        let $minExclusive :=
            (: JSON does not support non-numeric minimum :)
            if (not($jsonType = ('integer', 'number'))) then () else                   
                ($restrictions/z:_minExclusive_)[last()]/@value/string()                    
        return        
             if (empty($minExclusive)) then () else <minimum type="number" exclusive="true">{$minExclusive}</minimum>
        ,            
        (: maxInclusive :)
        let $maxInclusive :=
            (: JSON does not support non-numeric minimum :)
            if (not($jsonType = ('integer', 'number'))) then () else                   
                ($restrictions/z:_maxInclusive_)[last()]/@value/string()                    
        return        
            if (empty($maxInclusive)) then () else <maximum type="number">{$maxInclusive}</maximum>
        ,
        (: maxExclusive :)
        let $maxExclusive :=
            (: JSON does not support non-numeric minimum :)
            if (not($jsonType = ('integer', 'number'))) then () else                   
                ($restrictions/z:_maxExclusive_)[last()]/@value/string()                    
        return        
            if (empty($maxExclusive)) then () else <maximum type="number" exclusive="true">{$maxExclusive}</maximum>
        ,
        (: minLength :)
        let $minLength := max(($restrictions/z:_minLength_)/@value/xs:integer(.))                    
        return if (empty($minLength)) then () else <minLength type="number">{$minLength}</minLength>
        ,
        (: maxLength :)
        let $maxLength := min(($restrictions/z:_maxLength_)/@value/xs:integer(.))                    
        return if (empty($maxLength)) then () else <maxLength type="number">{$maxLength}</maxLength>
        ,
        
        (: length :)
        let $length := distinct-values($restrictions/z:_length_/@value/xs:integer(.))                    
        return if (empty($length)) then () else for $lengthValue in $length return (
            <minLength type="number">{$lengthValue}</minLength>,        
            <maxLength type="number">{$lengthValue}</maxLength>            
        )
        ,
        
        (: pattern :)
        let $pattern := $restrictions[z:_pattern_][last()]/z:_pattern_[1]/@value/f:_xsdPattern2JsonPattern(.)                    
        return
            if (not($pattern)) then () else <pattern>{$pattern}</pattern>
        ,
        (: enumeration :)
        let $enums := $restrictions[z:_enumeration_][last()]/z:_enumeration_/@value/string()
        return
            if (empty($enums)) then () else 
                let $values :=
                    if ($jsonType = ('integer', 'number')) then
                        for $e in $enums return <_ type="number">{$e}</_>
                    else if ($jsonType = 'boolean') then
                        for $e in $enums return <_ type="boolean">{$e}</_>
                    else
                        for $e in $enums return <_>{$e}</_>
                return
                    <enum type="array">{$values}</enum> 
    )  
    
    (: finalize constraint elements:
       - discard constraints for which there is a sharper constraint of the same kind
       - remove attributes which had been added for processing reasons (@exclusive)
    :)
    let $allConstraints := ($typeConstraints, $facetConstraints)    
    let $constraintElems := (        
        (: minimum :)    
        let $minConstraints := $allConstraints[self::minimum]
        return if (empty($minConstraints)) then () else
        
        let $minConstraintsIn := $minConstraints[not(@exclusive eq 'true')]
        let $minConstraintsEx := $minConstraints[@exclusive eq 'true']
        let $minMinimumIn := min($minConstraintsIn)
        let $minMinimumEx := min($minConstraintsEx)        
        return
            if (empty($minMinimumIn) or ($minMinimumEx lt $minMinimumIn)) then (
                    $minConstraintsEx[. = $minMinimumEx][1]/
                        element {node-name(.)}{@* except @exclusive, node()},
                    <exclusiveMinimum type="boolean">true</exclusiveMinimum>
                ) else 
                    $minConstraintsIn[. = $minMinimumIn][1]                
        ,
        (: maximum :)    
        let $maxConstraints := $allConstraints[self::maximum]
        return if (empty($maxConstraints)) then () else
        
        let $maxConstraintsIn := $maxConstraints[not(@exclusive eq 'true')]
        let $maxConstraintsEx := $maxConstraints[@exclusive eq 'true']
        let $maxMaximumIn := max($maxConstraintsIn)
        let $maxMaximumEx := max($maxConstraintsEx)        
        return
            if (empty($maxMaximumIn) or ($maxMaximumEx gt $maxMaximumIn)) then (
                    $maxConstraintsEx[. = $maxMaximumEx][1]/
                        element {node-name(.)}{@* except @exclusive, node()},
                    <exclusiveMaximum type="boolean">true</exclusiveMaximum>
                ) else 
                    $maxConstraintsIn[. = $maxMaximumIn][1]                
        ,
        (: minLength :)
        let $minLengthConstraints := $allConstraints[self::minLength]
        return if (empty($minLengthConstraints)) then () else
        
        let $minLengthMax := max($minLengthConstraints)
        return $minLengthConstraints[. = $minLengthMax][1]
        ,
        (: maxLength :)
        let $maxLengthConstraints := $allConstraints[self::maxLength]
        return if (empty($maxLengthConstraints)) then () else
        
        let $maxLengthMin := min($maxLengthConstraints)
        return $maxLengthConstraints[. = $maxLengthMin][1]
        ,
        $allConstraints[not((self::minimum, self::maximum, self::minLength, self::maxLength))]        
    )
    return
        ($typeElem, $constraintElems)    
};        

(:~
 : Returns the constraints applied to a JSON array representing an XSD list type.
 : The XSD type may be a complete type or a union member type. 
 :
 : Processes facets 'length', 'minLength', 'maxLength' applied to the list (not the
 : list items).
 :
 : @param typeDescriptor a fragment of a z:_typeInfo_ type descriptor
 : @param baseTypeName the name of the built-in base type
 : @return the content of the JSON model, consisting of a type element and optional contraint elements
 :)
declare function f:_getListConstraints($typeDescriptor as element())
        as element()* {
    let $restrictions := $typeDescriptor/z:_restriction_
    
    (: constraints implied by user-defined facets :)    
    let $constraintLength :=
        (: length :)
        let $lengthConstraints := $restrictions/z:_length_/@value/xs:int(.)                    
        return        
            (: no such contraints :)             
            if (empty($lengthConstraints)) then ()
            (: conflicting constraints => valid docs not possible :)
            else if (count($lengthConstraints) ne count(distinct-values($lengthConstraints))) then (
                <minItems type="number">1</minItems>,
                <maxItems type="number">0</maxItems>
             )
             else (
                <minItems type="number">{$lengthConstraints[1]}</minItems>,
                <maxItems type="number">{$lengthConstraints[1]}</maxItems>
            )
    
    let $constraintMinLength :=
        if (exists($constraintLength)) then () else
        let $minLengthConstraints := $restrictions/z:_minLength_/@value/xs:int(.)                    
        return        
             if (empty($minLengthConstraints)) then () else             
                let $minMinLength := min($minLengthConstraints)
                return 
                    <minItems type="number">{$minMinLength}</minItems>
        
    let $constraintMaxLength :=
        if (exists($constraintLength)) then () else
        let $maxLengthConstraints := $restrictions/z:_maxLength_/@value/xs:int(.)                    
        return        
             if (empty($maxLengthConstraints)) then () else             
                let $maxMaxLength := min($maxLengthConstraints)
                return 
                    <maxItems type="number">{$maxMaxLength}</maxItems>
    return
        ($constraintLength, $constraintMinLength, $constraintMaxLength)    
};        

declare function f:_xsd2JschemaRC_simple($n as node())
        as element()* {
    ()
};    

(:~
 : Creates a descriptor informing about the contents of a sequence of base tree
 : particle nodes (element descriptors and model group descriptors (choice/sequence/all).
 :
 : @param content of an element or a model group, which is a sequence of particle
 :    descriptors
 : @return the sequence descriptor 
 :)
declare function f:_sequenceDescriptor($items as element()*)
        as element() {
    let $parentName := $items[1]/parent::*/local-name(.)
    let $mandatory := 
        distinct-values(
            for $qname in f:getBcontentMandatoryMemberNames($items) 
            return local-name-from-QName($qname))
    let $optional := 
        distinct-values(
            for $qname in f:getBcontentMemberNames($items) return local-name-from-QName($qname))[not(. = $mandatory)]
            
    let $choices := f:getBcontentTopLevelChoiceDescriptors($items)

    let $nonChoiceElems := f:getBcontentNonChoiceChildElemDescriptors($items)
    let $nonChoiceElemNames := $nonChoiceElems/local-name(.)

    let $choiceElems := $choices/f:getBnodeChildElemDescriptors(.)
    let $choiceElemNames := $choiceElems/local-name(.)    
    let $choiceElemNamesDistinct := distinct-values($choiceElemNames)
    
    let $choiceElemsOverlapNonChoiceElems := exists($choiceElemNames[. = $nonChoiceElemNames])    
    let $choiceElemsOverlapChoiceElems := count($choiceElemNames) ne count($choiceElemNamesDistinct)
    return
        <sequenceDescriptor root="{$parentName}">{
            <mandatory>{$mandatory}</mandatory>,
            <optional>{$optional}</optional>,            
            <choices count="{count($choices)}" choiceElemsOverlapChoiceElems="{$choiceElemsOverlapChoiceElems}" choiceElemsOverlapNonChoiceElems="{$choiceElemsOverlapNonChoiceElems}">{
                if ($choiceElemsOverlapChoiceElems) then () else
                
                for $choice at $nr in $choices
                let $singleElemBranches := empty($choice/z:*)
                let $branches :=                    
                        for $branch in $choice/*
                        let $branchElemNames :=
                            if ($branch/self::z:*) then
                                distinct-values(
                                    for $qname in f:getBcontentMemberNames($branch) return local-name-from-QName($qname))
                            else
                                $branch/local-name(.)
                        let $mandatoryBranchElemNames :=
                            if ($branch/self::z:*) then                        
                                distinct-values(
                                    for $qname in f:getBcontentMandatoryMemberNames($branch) return local-name-from-QName($qname))
                            else
                                $branch/local-name(.)
                        return                        
                            <branch elems="{$branchElemNames}" mandatoryElems="{$mandatoryBranchElemNames}" />
                let $isOptional := 
                    if ($branches[@mandatoryElems = '']) then true()
                    else $choice/string(@minOccurs) eq '0'                            
                return
                    <choice nr="{$nr}" isOptional="{$isOptional}" singleElemBranches="{$singleElemBranches}">{
                        $branches        
                    }</choice>
            }</choices>
        }</sequenceDescriptor>
};        