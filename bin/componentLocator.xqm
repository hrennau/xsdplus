(:
 : -------------------------------------------------------------------------
 :
 : componentLocator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)

(:~@operations
   <operations>
      <operation name="locators" type="item()*" func="locatorsOp">     
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="enames" type="nameFilter?"/>
         <param name="gnames" type="nameFilter?"/>         
         <param name="hnames" type="nameFilter?"/>         
         <param name="addFname" type="xs:boolean?" default="false"/>    
         <param name="format" type="xs:string?" default="text" fct_values="text, xml"/>
         <pgroup name="in" minOccurs="1"/>
      </operation>
      <operation name="rlocators" type="item()" func="rlocatorsOp">     
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="locators" type="linesFOX*"/>
         <param name="skipAnno" type="xs:boolean?" default="true"/>
         <param name="mode" type="xs:string?" fct_values="resolve, check" default="resolve"/>
         <pgroup name="in" minOccurs="1"/>
      </operation>
    </operations>  
:)  

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_namespaceTools.xqm";    

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at 
    "targetNamespaceTools.xqm",
    "treeNavigator.xqm",
    "utilities.xqm";    

declare namespace z="http://www.xsdplus.org/ns/structure";

declare variable $f:USE_OLD_COMPONENT_LOCATORS as xs:boolean := false();

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)
 
 (:~
 : Implements operation 'locators'.
 :)
declare function f:locatorsOp($request as element())
        as item()* {
    let $schemas as element(xs:schema)* := app:getSchemas($request)        
    let $fname := tt:getParam($request, 'addFname')
    let $format := tt:getParam($request, 'format')
    let $enames := tt:getParam($request, 'enames')
    let $gnames := tt:getParam($request, 'gnames')    
    let $hnames := tt:getParam($request, 'hnames')    

    let $comps :=
        if (not(($enames, $gnames, $hnames))) then $schemas/descendant-or-self::*
        else (
            let $scomps := 
                if (not($enames)) then ()
                else $schemas//xs:element
                    [@name and tt:matchesNameFilter(@name, $enames) or
                     @ref and tt:matchesNameFilter(replace(@ref, '.+:', ''), $enames)]
            let $scomps := (
                $scomps,
                if (not($gnames)) then ()
                else (
                    $schemas/xs:group[tt:matchesNameFilter(@name, $gnames)],
                    $schemas/*//xs:group[tt:matchesNameFilter(replace(@ref, '.*:', ''), $gnames)]
                )
            )
            let $scomps := (
                $scomps,
                if (not($hnames)) then ()
                else (
                    $schemas/xs:attributeGroup[tt:matchesNameFilter(@name, $hnames)],
                    $schemas/*//xs:attributeGroup[tt:matchesNameFilter(replace(@ref, '.*:', ''), $hnames)]
                )
            )
            return
                $scomps
    )            
    let $nsmap := app:getTnsPrefixMap($schemas)        
    let $locs := 
        for $comp in $comps
        let $loc := app:getComponentLocator($comp, $nsmap, $schemas)
        let $check := $comp is app:resolveComponentLocator($loc, $nsmap, $schemas)
        return
            <z:loc value="{$loc}">{
                if (not($fname)) then () else attribute fname {$comp/root()/replace(document-uri(.), '.*/', '')},
                if ($check) then () else attribute ERROR {'CANNOT-RESOLVE'}
            }</z:loc>
    let $reportXml := 
        <z:locs count="{count($locs)}">{           
            for $loc in $locs
            order by $loc/@value 
            return $loc          
        }</z:locs>
    return
        if ($format eq 'xml') then $reportXml
        else $reportXml//z:loc/@value/string()
};

 (:~
 : Implements operation 'rlocators'.
 :)
declare function f:rlocatorsOp($request as element())
        as element() {
    let $schemas as element(xs:schema)* := app:getSchemas($request)
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $locators := tt:getParam($request, 'locators')
    let $skipAnno := tt:getParam($request, 'skipAnno')
    let $mode := tt:getParam($request, 'mode')
    
    let $comps :=
        for $locator in $locators
        let $comp := app:resolveComponentLocator($locator, $nsmap, $schemas)
        return 
            if ($mode eq 'check') then
                let $rloc := $comp/app:getComponentLocator(., $nsmap, $schemas)
                let $check := ($rloc eq $locator, false())[1]
                return
                    <z:comp check="{$check}" loc="{$locator}">{
                        if ($check) then () else
                            attribute rloc {$rloc}
                    }</z:comp>
            else
                let $ecomp := 
                    if (not($skipAnno) or $comp/self::xs:annotation) then $comp 
                    else app:editComponent($comp, $request)
                return
                    <z:comp loc="{$locator}">{$ecomp}</z:comp>
    return
        <z:comps xmlns:xs="http://www.w3.org/2001/XMLSchema">{$comps}</z:comps>
};

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(: ###################################################################################################################
   #                                                                                                                 #
   #   section:    c o m p o n e n t    l o c a t o r s                                                              #
   #                                                                                                                 #   
   ###################################################################################################################
:) 

(:~
 : Returns the locator string of a schema component, which unambiguously identifies
 : the component. A component locator can be resolved to the component element using 
 : function 'resolveComponentLocator'. Some locator examples:
 :
 :   complexType(a:CombinatoricsType) 
 :   complexType(a:CombinatoricsType)/xs:sequence/xs:choice/a:ExcludePriceItemClasses
                 /xs:sequence/a:ExcludePriceItemClass/@Component 
 :   simple(a:AccommodationCategory) 
 :   simple(a:AccommodationCategory)/xs:annotation/xs:documentation[2] 
 :   simple(a:AccommodationCategory)/xs:restriction/xs:pattern 
 :   group(a:AtomicCombinableWhenGroup)
 :   group(a:AtomicCombinableWhenGroup)/xs:choice/a:CombinationCode/xs:sequence/a:Level
 :   attributeGroup(a:ApplyAttributeGroup)
 :   attributeGroup(a:ApplyAttributeGroup)/@Component
 :   schema(/path/to/docs/doc.xml)
 :   schema(/path/to/docs/doc.xml)/xs:include[2] 
 :
 : The locator string consists of 
 : * an initial step - identifies a top-level component
 : * a declaration path (optional) - declarations leading towards the component
 : * a trailing path (optional) - ordinary XPath steps connecting the component to
 :       the tail of the declaration path, or to the initial step (if there is 
 :       no declaration path)
 :
 : initial step
 : ------------
 : The initial step identifies the top-level component (declaration or definition), or 
 :     the schema document if the component is not equal to or contained by a top-level 
 :     component (examples: schema element, top-level annotation, include element,
 :     import element); specifically, an initial step is one of these:
 : * schema(uri)                       example: schema(/user/hugo/docs/mydoc.xml)
 : * complexType(type-name)            example: complexType(a:CombinatoricsType)
 : * simpleType(type-name)             example: simpleType(a:AccommodationCategory)
 : * element(elem-name)                example: element(a:Otds)
 : * attribute(att-name)               example: attribute(a:Market)
 : * group(group-name)                 example: group(a:AtomicCombinableWhenGroup)
 : * attributeGroup(att-group-name)    example: attributeGroup(a:ApplyAttributeGroup)
 :
 : If the initial step contains a name, it is the lexical QName of a top-level component,
 : using a normalized namespace prefix. 
 :
 : declaration path
 : ----------------
 : A declaration path consists of steps identifying all element and attribute declarations
 : which are equal to or containing the component; the declaration path consists of steps 
 : which are one of these:
 : * declaration step
 : -   lexical QName - identifies an element declaration with corresponding @name or @ref
 : -   lexical QName preceded by '@' - identifies an attribute declaration with corresponding 
 :       @name or @ref
 : * compositor step
 : -   xs:sequence - identifies a "sequence" compositor within a complex type definition 
 : -   xs:choice - identifies a "choice" compositor within a complex type definition 
 : -   xs:all - identifies an "all" compositor within a complex type definition
 : The type definition containing the compositor may be the top-level type definition 
 : (identified by the initial step) or a local type contained by an element declaration.
 :
 : A declaration step contains a trailing index (e.g. [2]) if it identifies a declaration 
 : with a preceding sibling with the same declaration name. Likewise, a compositor step 
 : contains a trailing index if it identifies a compositor element with a preceding sibling 
 : which is the same compositor kind. Examples: a:foo[3], xs:choice[2]
 :
 : trailing path
 : -------------
 : A "trailing path" is used if the component is none of these: element declaration,
 : attribute declaration, type definition, group definition, attribute group definition.
 :     The trailing path consists of all navigation steps leading from the last step of
 : the declaration path (or the initial step, if there is no declaration path) to the 
 : component itself. Examples: xs:extension, xs:enumeration.
 :
 : A step contains a trailing index if it has a preceding sibling with the same element 
 : name (e.g. xs:enumeration[5]).
 :
 : All lexical QNames use normalized prefixes. The normalization is described by the 
 : $nsmap parameter, or implied by the $schemas parameter if no $nsmap is supplied.
 :
 : The lexical QNames used as declaration path steps are the names which instance 
 : elements or attributes governed by the respective declaration have (dependent 
 : on the target namespace and the element/attribute form setting, in the case of 
 : declarations with a @name attribute, and on the namespace context in the case of 
 : declarations with a @ref attribute.
 :
 : Note that subsequent element declaration steps are separated by at least one 
 : compositor step.
 :
 : @param comp the schema component
 : @param nsmap a map associating namespace URIs with prefixes
 : @param schemas the schema elements currently considered
 : @return the component locator string
 :)
declare function f:getComponentLocator($comp as node(),
                                       $nsmap as element(z:nsMap)?, 
                                       $schemas as element(xs:schema)+)
      as xs:string { 
(:      
    if ($f:USE_OLD_COMPONENT_LOCATORS) then f:getComponentLocator_old($comp, $nsmap, $schemas) else
:)    
    let $nsmap := ($nsmap, app:getTnsPrefixMap($schemas))[1]
    
    (: lastDeclaration - after 'lastDeclaration', every navigation step is 
       recorded, not only the declaration and compositor steps :) 
    let $lastDeclaration := $comp/ancestor-or-self::*[
        self::xs:attribute, 
        self::xs:element, 
        self::xs:group[@ref],
        self::xs:attributeGroup[@ref]][1]
    return
    
    (: case: component = schema element :)
    if ($comp/self::xs:schema) then
        concat('schema(', $comp/root()/document-uri(.), ')') else
        
    string-join(
        for $anc in $comp/ancestor-or-self::*[not(self::xs:schema)]
        return
            (: case: top level component :)
            if ($anc/parent::xs:schema) then
            
                if ($anc/self::xs:include) then
                    let $index :=
                        let $pre := 1 + count($anc/preceding-sibling::xs:include)
                        return if ($pre eq 1) then () else concat('[', $pre, ']')
                    return
                        concat('schema(', $comp/root()/document-uri(.), ')/xs:include', $index)
                else if ($anc/self::xs:import) then
                    let $index :=
                        let $pre := 1 + count($anc/preceding-sibling::xs:import)
                        return if ($pre eq 1) then () else concat('[', $pre, ']')
                    return
                        concat('schema(', $comp/root()/document-uri(.), ')/xs:import', $index)
                else if ($anc/self::xs:annotation) then
                    let $index :=
                        let $pre := 1 + count($anc/preceding-sibling::xs:annotation)
                        return if ($pre eq 1) then () else concat('[', $pre, ']')
                    return
                        concat('schema(', $comp/root()/document-uri(.), ')/xs:annotation', $index)
                else
                    let $compType := local-name($anc)
                    let $compName := tt:normalizeQName(
                        QName($anc/parent::xs:schema/@targetNamespace, $anc/@name), $nsmap)
                    let $compName := ($anc/@z:normalizedName, $compName)[1]                          
                    return
                        concat($compType, '(', $compName, ')')                
            else
            
            (: case: compositor :)
            typeswitch($anc)
            case element(xs:sequence) return 
                let $index := if (empty($anc/preceding-sibling::xs:sequence)) then () else
                    concat('[', 1 + count($anc/preceding-sibling::xs:sequence), ']')
                return concat('xs:sequence', $index)
            case element(xs:choice) return 
                let $index := if (empty($anc/preceding-sibling::xs:choice)) then () else
                    concat('[', 1 + count($anc/preceding-sibling::xs:choice), ']')
                return concat('xs:choice', $index)
            case element(xs:all) return 
                let $index := if (empty($anc/preceding-sibling::xs:all)) then () else
                    concat('[', 1 + count($anc/preceding-sibling::xs:all), ']')
                return concat('xs:all', $index)
                    
            (: case: attribute declaration :)                    
            case element(xs:attribute) return concat('@', app:getComponentName($anc))

            (: case: element declaration :)
            case element(xs:element) return 
                let $name := app:getComponentName($anc)
                let $normalizedName := tt:normalizeQName($name, $nsmap)
                let $lname := local-name-from-QName($name)
                let $similar := $anc/preceding-sibling::xs:element[@name eq $lname or @ref/replace(., '.+:', '') eq $lname]
                let $index :=
                    if (not($similar)) then () else
                        let $same := $similar[app:getComponentName(.) eq $name]
                        return if (not($same)) then () else concat('[', 1 + count($same), ']')
                return concat($normalizedName, $index)
 
            (: case: group reference :) 
            case element(xs:group) return
                let $name := $anc/@ref/resolve-QName(., ..)
                let $normalizedName := tt:normalizeQName($name, $nsmap)
                let $lname := local-name-from-QName($name)
                let $similar := $anc/preceding-sibling::xs:group[@ref/replace(., '.+:', '') eq $lname]
                let $index :=
                    if (not($similar)) then () else
                        let $same := $similar[@ref/resolve-QName(., ..) eq $name]
                        return if (not($same)) then () else concat('[', 1 + count($same), ']')
                return concat('group(', $normalizedName, ')', $index)

            (: case: attribute group reference :)
            case element(xs:attributeGroup) return
                let $name := $anc/@ref/resolve-QName(., ..)
                let $normalizedName := tt:normalizeQName($name, $nsmap)
                return concat('attributeGroup(', $normalizedName, ')')

            (: case: trailing elements 
                 (e.g. .../a:foo/xs:complexType - identifies the local type definition) 
             :) 
            default return
                if ($anc >> $lastDeclaration or not($lastDeclaration)) then
                    let $nname := node-name($anc)
                    let $uri := namespace-uri-from-QName($nname)
                    let $useName :=
                        if ($nsmap/*/@uri = $uri) then tt:normalizeQName($nname, $nsmap)
                        else local-name($anc)
                    let $indexPostfix :=
                        let $index := 1 + count($anc/preceding-sibling::*[node-name(.) eq $nname])
                        return
                            if ($index eq 1) then () else concat('[', $index, ']')
                    return                            
                        concat($useName, $indexPostfix)
                else ()
    , '/')        
};
(:~
 : Resolves a component locator to the component element. 
 :
 : Note. A component locator can be created using function
 : 'getComponentLocator'.
 :
 : @param loc the component locator
 : @param nsmap a map associating namespace URIs with prefixes
 : @param schemas the schema elements currently considered
 : @return the component identified by the component locator
 :)
declare function f:resolveComponentLocator($loc as xs:string,
                                           $nsmap as element(z:nsMap)?, 
                                           $schemas as element(xs:schema)+)
      as element()? {
    if (matches($loc, '^\i\c*\[')) then 
        f:getComponentLocator_old($loc, $nsmap, $schemas) 
    else
        let $nsmap := ($nsmap, app:getTnsPrefixMap($schemas))[1]      
        return f:_resolveComponentLocatorRC((), $loc, $nsmap, $schemas)
};

 (:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)
 
(:~
 : Recursive helper function of 'resolveComponentLocator2'.
 :
 : @param loc the component locator
 : @param nsmap a map associating namespace URIs with prefixes
 : @param schemas the schema elements
 : @return the component identified by the component locator
 :)
declare function f:_resolveComponentLocatorRC($context as node()?, 
                                              $path as xs:string,
                                              $nsmap as element(z:nsMap), 
                                              $schemas as element(xs:schema)+)
      as element()? {
        (: locator starts with "schema(uri) (note that uri may contain slashes) :)      
    if (starts-with($path, 'schema(')) then
        let $uriAndRest := replace($path, 'schema\((.*)\)(/(.*))?', '$1#$3')
        let $uri := substring-before($uriAndRest, '#')
        let $rest := substring-after($uriAndRest, '#')
        let $newContext := doc($uri)/xs:schema
        return
            if (not($rest)) then $newContext
            else f:_resolveComponentLocatorRC($newContext, $rest, $nsmap, $schemas)
    
    else
    
    let $step := replace($path, '/.*', '')
    let $rest := substring-after($path, '/')[string()]
    let $newContext :=
                
        (: top level component - e.g. complexType(a:FooType) :)
        if (contains($step, '(') and (not($context) or $context/self::xs:schema)) then
            let $root := replace($step, '/.*', '')
            let $compKind := substring-before($step, '(')
            let $compName := replace($step, '.*\(|\).*', '')
            let $compQName := tt:resolveNormalizedQName($compName, $nsmap)
            return
                if ($compKind eq 'element') then $schemas/xs:element[QName(../@targetNamespace, @name) eq $compQName]
                else if ($compKind eq 'attribute') then $schemas/xs:attribute[QName(../@targetNamespace, @name) eq $compQName]
                else if ($compKind eq 'simpleType') then $schemas/xs:simpleType[QName(../@targetNamespace, @name) eq $compQName]
                else if ($compKind eq 'complexType') then $schemas/xs:complexType[QName(../@targetNamespace, @name) eq $compQName]
                else if ($compKind eq 'group') then $schemas/xs:group[QName(../@targetNamespace, @name) eq $compQName]
                else if ($compKind eq 'attributeGroup') then $schemas/xs:attributeGroup[QName(../@targetNamespace, @name) eq $compQName]
                else
                    error(QName($tt:URI_ERROR, 'SYSTEM_ERROR'), concat("Unexpected schema component kind: ", $compKind))

        (: local type definition :)
        else if ($step = 'xs:simpleType') then $context/xs:simpleType[1]
        else if ($step = 'xs:complexType') then $context/xs:complexType

        (: element or attribute declaration :)
        else    
            let $container :=
                if ($context/self::xs:element) then
                    $context/xs:complexType/(
                        (xs:simpleContent, xs:complexContent)/(xs:restriction, xs:extension),
                        .[not((xs:simpleContent, xs:complexContent))]
                    )
                else if ($context/self::xs:complexType) then
                    $context/(
                        (xs:simpleContent, xs:complexContent)/(xs:restriction, xs:extension),
                        .[not((xs:simpleContent, xs:complexContent))]
                    )
                else if (not($context)) then
                    $schemas
                else $context       
            return
                (: compositor element :)
                if (starts-with($step, 'xs:sequence')) then 
                    let $index := if (not(contains($step, '['))) then 1 else xs:integer(replace($step, '.+\[(\d+).*', '$1'))
                    return $container/xs:sequence[$index] 
                else if (starts-with($step, 'xs:choice')) then        
                    let $index := if (not(contains($step, '['))) then 1 else xs:integer(replace($step, '.+\[(\d+).*', '$1'))
                    return $container/xs:choice[$index] 
                else if (starts-with($step, 'xs:all')) then        
                    let $index := if (not(contains($step, '['))) then 1 else xs:integer(replace($step, '.+\[(\d+).*', '$1'))
                    return $container/xs:all[$index]
                    
                (: attribute declaration :)                    
                else if (starts-with($step, '@')) then
                    let $name := substring($step, 2)
                    let $qname := tt:resolveNormalizedQName($name, $nsmap)
                    let $lname := local-name-from-QName($qname)
                    let $attPerName := 
                        let $candidate := $container/xs:attribute[@name eq $lname]
                        return
                            if (not($candidate)) then ()
                            else
                                let $attributeForm :=
                                    ($candidate/@attributeForm, $candidate/ancestor::xs:schema/@attributeFormDefault)[1]
                                let $uri :=
                                    if (not($attributeForm eq 'qualified')) then () else
                                        $context/ancestor-or-self::xs:schema/@targetNamespace
                                return
                                    $candidate[QName($uri, $lname) eq $qname]
                    return
                        if ($attPerName) then $attPerName
                        else $container/xs:attribute[@ref/resolve-QName(., ..) eq $qname]
                        
                (: group(...) :)                        
                else if (starts-with($step, 'group(')) then
                    let $groupName := replace($step, '.*\(\s*|\s*\).*', '')
                    let $groupQName := tt:resolveNormalizedQName($groupName, $nsmap)
                    let $index := if (not(contains($step, '['))) then 1 else 
                        xs:integer(replace($step, '.+\[(.+)\].*', '$1'))
                    return
                        $container/xs:group[@ref/resolve-QName(., ..) eq $groupQName][$index]
                        
                (: attributeGroup(...) :)                        
                else if (starts-with($step, 'attributeGroup(')) then
                    let $agroupName := replace($step, '.*\(\s*|\s*\).*', '')
                    let $agroupQName := tt:resolveNormalizedQName($agroupName, $nsmap)
                    return
                        $container/xs:attributeGroup[@ref/resolve-QName(., ..) eq $agroupQName]
                        
                (: component != compositor, element or attribute declaration :)                        
                else if (starts-with($step, 'xs:')) then
                    let $compName := replace(replace($step, '\[.*', ''), '.+:', '')
                    let $index := if (not(contains($step, '['))) then 1 else xs:integer(replace($step, '.+\[(.+)\].*', '$1'))
                    return
                        $context/*[local-name(.) eq $compName][namespace-uri(.) eq $tt:URI_XSD][$index]
                        
                (: element declaration (or non-xs element descendant of xs:annotation :)                            
                else
                    let $name := replace($step, '\[.*', '')
                    let $index := if ($name eq $step) then 1 else xs:integer(replace($step, '.+\[(\d+).*', '$1'))
                    let $qname := tt:resolveNormalizedQName($name, $nsmap)
                    let $lname := local-name-from-QName($qname)
                    return
                        if ($context/ancestor-or-self::xs:annotation) then
                            $context/*[local-name(.) eq $lname][$index]
                        else
                            let $elemPerName := 
                                for $candidate in $container/xs:element[@name eq $lname]
                                return
                                    let $elementForm :=
                                        ($candidate/@elementForm, $candidate/ancestor::xs:schema/@elementFormDefault)[1]
                                    let $uri :=
                                        if (not($elementForm eq 'qualified')) then () else
                                            $context/ancestor-or-self::xs:schema/@targetNamespace
                                    return
                                        $candidate[QName($uri, $lname) eq $qname]
                            let $elemPerRef := $container/xs:element[@ref/resolve-QName(., ..) eq $qname]
                        return
                            ($elemPerName | $elemPerRef)[$index]
    return
        if (not($newContext)) then ()
        else if (not($rest)) then $newContext
        else f:_resolveComponentLocatorRC($newContext, $rest, $nsmap, $schemas)
};

(:~
 : Returns the locator string of a schema component. The locator
 : string consists of 
 : - a first step identifying the top-level component within which
 :      the component is found
 : - ordinary XPath steps leading to the component, starting from
 :      the top-level component
 :
 : Note. A component locator can be resolved to the component 
 : using function 'resolveComponentLocator'. 
 : Examples:
 : element[a:foo]
 : element[a:foo]/xs:sequence[1]/xs:element[3]
 : complexType[a:bar]/xs:sequence[1]/xs:element[3]
 : attributeGroup[a:foobar]/xs:attribute[2]
 :
 : @param comp the schema component
 : @param nsmap an element providing namespace mappings to be used
 : @param schemas the schemas currently evaluated 
 :)
declare function f:getComponentLocator_old($comp as node(),
                                       $nsmap as element(z:nsMap)?, 
                                       $schemas as element(xs:schema)+)
      as xs:string {
    let $nsmap := ($nsmap, app:getTnsPrefixMap($schemas))[1]      
    let $anchor := $comp/ancestor-or-self::*[last() - 1]
    let $anchorType := local-name($anchor)
    let $anchorName := tt:normalizeQName(
                          QName($anchor/ancestor::xs:schema/@targetNamespace, $anchor/@name), $nsmap)
    let $anchorName := ($anchor/@z:normalizedName, $anchorName)[1]                          
    let $anchorPrefix := concat($anchorType, '[', $anchorName, ']')
    return
       if ($comp is $anchor) then $anchorPrefix
       else 
          let $anchorPath := app:getPath($anchor, $comp, $nsmap)
          return concat($anchorPrefix, '/', $anchorPath)
};

(:~
 : Resolves a component locator to the component element. 
 :
 : Note. A component locator can be created using function
 : 'getComponentLocator'.
 :
 : @param loc the component locator
 : @param nsmap a map associating namespace URIs with prefixes
 : @param schemas the schema elements
 : @return the component identified by the component locator
 :)
declare function f:resolveComponentLocator_old($loc as xs:string,
                                           $nsmap as element(z:nsMap)?, 
                                           $schemas as element(xs:schema)+)
      as element()? {
   let $nsmap := ($nsmap, app:getTnsPrefixMap($schemas))[1]      
   let $root := replace($loc, '/.*', '')
   let $path := substring-after($loc, '/')
   let $compKind := substring-before($root, '[')
   let $compName := replace($root, '.*\[|\].*', '')
   let $compQName := tt:resolveNormalizedQName($compName, $nsmap)
   let $anchor :=
      if ($compKind eq 'element') then app:findElem($compQName, $schemas)
      else if ($compKind eq 'attribute') then app:findAtt($compQName, $schemas)
      else if ($compKind eq 'simpleType') then app:findType($compQName, $schemas)
      else if ($compKind eq 'complexType') then app:findType($compQName, $schemas)
      else if ($compKind eq 'group') then app:findGroup($compQName, $schemas)
      else if ($compKind eq 'attributeGroup') then app:findAttGroup($compQName, $schemas)
      else
         error(QName($tt:URI_ERROR, 'SYSTEM_ERROR'), concat("Unexpected schema component kind: ", $compKind))
   return 
      if (not($path)) then $anchor else
         f:_resolveComponentLocatorRC_old($anchor, $path, $nsmap, $schemas)
};

(:~
 : Recursive helper function of 'resolveComponentLocator'.
 :
 : @param loc the component locator
 : @param nsmap a map associating namespace URIs with prefixes
 : @param schemas the schema elements
 : @return the component identified by the component locator
 :)
declare function f:_resolveComponentLocatorRC_old($context as node(), 
                                              $path as xs:string,
                                              $nsmap as element(z:nsMap), 
                                              $schemas as element(xs:schema)+)
      as element()? {
    let $step := replace($path, '/.*', '')
    let $rest := substring-after($path, '/')[string()]

    let $name := substring-before($step, '[')
    let $index := replace($step, '.*\[|\].*', '')
    let $qname := tt:resolveNormalizedQName($name, $nsmap)
    let $nextNode := $context/*[node-name(.) eq $qname][xs:int($index)]
    return
       if (empty($rest)) then $nextNode else
          f:_resolveComponentLocatorRC_old($nextNode, $rest, $nsmap, $schemas)
};






