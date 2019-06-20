(:
 : -------------------------------------------------------------------------
 :
 : valueTreeWriter.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="xsdDiff" type="item()" func="xsdDiffOp">     
         <param name="xsd1" type="docFOX" fct_minDocCount="1" sep="WS"/>
         <param name="xsd2" type="docFOX" fct_minDocCount="1" sep="WS"/>     
         <param name="enames" type="nameFilter?"/> 
         <param name="global" type="xs:boolean?" default="true"/>
         <param name="ignNamespaces" type="xs:boolean?" default="false"/>
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
    "factTreeUtilities.xqm",
    "locationTreeWriter.xqm",
    "schemaLoader.xqm",
    "treesheetWriter.xqm";

import module namespace diff="http://www.xsdplus.org/ns/xquery-functions/xsddiff" at 
    "xsddiffTools.xqm",
    "ltreeDiff.xqm";

declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

(:~
 : Implements operation 'xsdDiff'. 
 :
 : @param request the operation request
 : @return a frequency tree
 :) 
declare function f:xsdDiffOp($request as element())
        as item()? {
    let $xsds1 := tt:getParam($request, 'xsd1')/* => app:schemaElems()
    let $xsds2 := tt:getParam($request, 'xsd2')/* => app:schemaElems()
    let $enames := tt:getParam($request, 'enames')
    let $global := tt:getParam($request, 'global')
    let $ignNamespaces := tt:getParam($request, 'ignNamespaces')
    
    let $options :=
        <options ignNamespaces="{if ($ignNamespaces) then 'true' else 'false'}"/>
    
    return f:xsdDiff($xsds1, $xsds2, $enames, $global, $options)
};

declare function f:xsdDiff($xsds1 as element(xs:schema)+,
                           $xsds2 as element(xs:schema)+,
                           $enames as element()?,
                           $global as xs:boolean?,
                           $options as element(options)?)
        as item()* {
    let $ignNamespaces := $options/@ignNamespaces/xs:boolean(.)
    
    (: retrieve components :)
    let $comps1 := $xsds1/xs:element[empty($enames) or @name/tt:matchesNameFilter(., $enames)]
    let $comps2 := $xsds2/xs:element[empty($enames) or @name/tt:matchesNameFilter(., $enames)]
    
    (: namespace maps :)
    let $nsmap1 := app:getTnsPrefixMap($xsds1)
    let $nsmap2 := app:getTnsPrefixMap($xsds2)
    let $nsmap3 := app:getTnsPrefixMap(($xsds1, $xsds2))

    (: perform diff :)
    let $compNames1 := $comps1/diff:componentName(., $ignNamespaces)
    let $compNames2 := $comps2/diff:componentName(., $ignNamespaces)

    let $compNamesBoth := $compNames1[. = $compNames2]    
    let $compNamesOnly1 := $compNames1[not(. = $compNames2)]
    let $compNamesOnly2 := $compNames2[not(. = $compNames1)]    

    let $compDiffs :=
        for $name in $compNamesBoth
        let $lname := local-name-from-QName($name)
        let $uri := namespace-uri-from-QName($name)
        let $comp1 := $comps1[diff:componentName(., $ignNamespaces) eq $name][1]
        let $comp2 := $comps2[diff:componentName(., $ignNamespaces) eq $name][1]        
        let $diff := diff:ltreeDiff($comp1, $comp2, $xsds1, $xsds2, $nsmap1, $nsmap2, $nsmap3, $options)   
        let $nsAtts :=
            if ($ignNamespaces) then (
                attribute namespace1 {$comp1/namespace-uri(.)},
                attribute namespace2 {$comp2/namespace-uri(.)}
            ) else 
                attribute namespace {$comp1/namespace-uri(.)}
        order by $lname, $uri
        return
            if (empty($diff/*)) then <z:component name="{$lname}">{$nsAtts}</z:component>
            else <z:component name="{$lname}">{$nsAtts, $diff/*}</z:component>                
       
        
    let $onlyIn1 :=
        <z:onlyIn1 count="{count($compNamesOnly1)}">{
            for $n in $compNamesOnly1
            let $lname := local-name-from-QName($n)
            let $uri := namespace-uri-from-QName($n)
            order by $lname, $uri                
            return <z:component name="{$lname}" namespace="{$uri}"/>                
        }</z:onlyIn1>
    let $onlyIn2 :=
        <z:onlyIn2 count="{count($compNamesOnly2)}">{
            for $n in $compNamesOnly2
            let $lname := local-name-from-QName($n)
            let $uri := namespace-uri-from-QName($n)
            order by $lname, $uri                
            return <z:component name="{$lname}" namespace="{$uri}"/>                
        }</z:onlyIn2>
    let $changed := <z:changed count="{count($compDiffs)}">{$compDiffs}</z:changed>
    let $baseReport :=
        <z:xsdDiff format="base">{
            <z:meta>{
                <z:namespaceBindings>{
                    $nsmap1,                
                    $nsmap2,                    
                    $nsmap3
                }</z:namespaceBindings>
            }</z:meta>,
            $onlyIn1,
            $onlyIn2,
            $compDiffs
        }</z:xsdDiff>
        
    return
        $baseReport
        
};   
