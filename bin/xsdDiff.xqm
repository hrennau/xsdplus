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
         <param name="format" type="xs:string?" default="base" fct_values="base, std"/>
         <param name="tpath" type="xs:boolean?" default="false"/>
         <param name="igroup" type="xs:boolean?" default="false"/>
         <param name="changeDetails" type="xs:string?" fct_values="all, long, short, none, vsn, vsn2, vsnTypes" default="all"/>         
         <param name="ignNamespaces" type="xs:boolean?" default="false"/>
         <param name="ignChanges" type="xs:string*" fct_values="changedType"/>
         <param name="vocabulary" type="xs:string?" default="new" fct_values="new, legacy"/>
         <param name="addedDeeperItems" type="xs:string?" default="count" fct_values="ignore, count, list"/>
         <param name="removedDeeperItems" type="xs:string?" default="count" fct_values="ignore, count, list"/>         
      </operation>
    </operations>  
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

import module namespace diff="http://www.xsdplus.org/ns/xquery-functions/xsddiff" at 
    "xsddiffTools.xqm",
    "xsdDiff_std.xqm",
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
    let $format := tt:getParam($request, 'format')
    let $tpath := tt:getParam($request, 'tpath')
    let $igroup := tt:getParam($request, 'igroup')
    let $changeDetails := tt:getParam($request, 'changeDetails')
    let $global := tt:getParam($request, 'global')
    let $ignNamespaces := tt:getParam($request, 'ignNamespaces')
    let $ignChanges := tt:getParam($request, 'ignChanges')
    let $vocabulary := tt:getParam($request, 'vocabulary')
    let $addedDeeperItems := tt:getParam($request, 'addedDeeperItems')    
    let $removedDeeperItems := tt:getParam($request, 'removedDeeperItems')
    
    let $options :=
        <options format="{$format}"
                 tpath="{$tpath}"
                 igroup="{$igroup}"                 
                 changeDetails="{$changeDetails}"
                 ignNamespaces="{if ($ignNamespaces) then 'true' else 'false'}"
                 ignChanges="{$ignChanges}"
                 vocabulary="{$vocabulary}"
                 addedDeeperItems="{$addedDeeperItems}"
                 removedDeeperItems="{$removedDeeperItems}"
        />
    
    return f:xsdDiff($xsds1, $xsds2, $enames, $global, $options)
};

(:~
 : Creates an XSD diff report. First produces an XSD base diff
 : report and maps it to the requested report type.
 :)
declare function f:xsdDiff($schemas1 as element(xs:schema)+,
                           $schemas2 as element(xs:schema)+,
                           $enames as element()?,
                           $global as xs:boolean?,
                           $options as element(options)?)
        as item()* {
    let $format := $options/@format/string()        
    let $baseDiff := f:xsdBaseDiff($schemas1, $schemas2, $enames, $global, $options)
    return
        if ($format eq 'base') then $baseDiff
        else if ($format eq 'std') then f:xsdBaseDiff2Std($baseDiff, $options)
        else error()            
}; 

(:~
 : Creates an XSD base diff report.
 :)
declare function f:xsdBaseDiff($schemas1 as element(xs:schema)+,
                               $schemas2 as element(xs:schema)+,
                               $enames as element()?,
                               $global as xs:boolean?,
                               $options as element(options)?)
        as item()* {
    let $ignNamespaces := $options/@ignNamespaces/xs:boolean(.)
    let $vocabulary := $options/@vocabulary/string()
    let $useElemNames :=
        if ($vocabulary eq 'legacy') then 
            <useElemNames componentsAdded="z:onlyIn1" componentsRemoved="z:onlyIn2" componentsChanged="z:changed"/>
        else
            <useElemNames componentsAdded="z:componentsAdded" componentsRemoved="z:componentsRemoved" componentsChanged="z:componentsChanged"/>
    
    (: retrieve components :)
    let $comps1 := $schemas1/xs:element[empty($enames) or @name/tt:matchesNameFilter(., $enames)]
    let $comps2 := $schemas2/xs:element[empty($enames) or @name/tt:matchesNameFilter(., $enames)]
    
    (: namespace maps :)
    let $nsmap1 := app:getTnsPrefixMap($schemas1)
    let $nsmap2 := app:getTnsPrefixMap($schemas2)
    let $nsmap3 := app:getTnsPrefixMap(($schemas1, $schemas2))

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
        let $diff := diff:ltreeDiff($comp1, $comp2, $schemas1, $schemas2, $nsmap1, $nsmap2, $nsmap3, $options)   
        let $nsInfoAtts :=
            if ($ignNamespaces) then (
                attribute namespace1 {$comp1/namespace-uri(.)},
                attribute namespace2 {$comp2/namespace-uri(.)}
            ) else 
                attribute namespace {$comp1/namespace-uri(.)}
        order by $lname, $uri
        return
            if (empty($diff/*)) then 
                <z:component name="{$lname}">{$nsInfoAtts}</z:component>
            else 
                <z:component name="{$lname}">{$nsInfoAtts, $diff/*}</z:component>       
      
    let $namespaceBindings :=
        <z:namespaceBindings>{
            <zz:nsMap_version1>{$nsmap1/*}</zz:nsMap_version1>,
            <zz:nsMap_version2>{$nsmap2/*}</zz:nsMap_version2>,
            <zz:nsMap_versions_merged>{$nsmap3/*}</zz:nsMap_versions_merged>
        }</z:namespaceBindings>

    let $xsdsChanged := f:xsdsChanged($compDiffs, $nsmap1, $nsmap2, $schemas1, $schemas2)
    
    let $compsRemoved :=
        element {$useElemNames/@componentsAdded} {
            attribute count {count($compNamesOnly1)},
            for $n in $compNamesOnly1
            let $lname := local-name-from-QName($n)
            let $uri := namespace-uri-from-QName($n)
            order by $lname, $uri                
            return <z:component name="{$lname}" namespace="{$uri}"/>                
        }
    let $compsAdded :=
        element {$useElemNames/@componentsRemoved} {
            attribute count {count($compNamesOnly2)},
            for $n in $compNamesOnly2
            let $lname := local-name-from-QName($n)
            let $uri := namespace-uri-from-QName($n)
            order by $lname, $uri                
            return <z:component name="{$lname}" namespace="{$uri}"/>                
        }
    let $compsChanged := 
        element {$useElemNames/@componentsChanged} {
            attribute count {count($compDiffs)},
            $compDiffs
        }
       
    let $baseDiffRaw :=
        <z:xsdDiff format="base">{
            namespace zz {'http://www.ttools.org/structure'},
            <z:meta>{
                $namespaceBindings,
                $xsdsChanged
            }</z:meta>,
            $compsRemoved,
            $compsAdded,
            $compsChanged
        }</z:xsdDiff>
        
    let $baseDiff := f:finalizeXsdBaseDiff($baseDiffRaw, $options)
    return $baseDiff
        
}; 

(:~
 : Finalizes a base diff. Actions are controlled by $request. Possible
 : actions:
 : noprefix=true => path representations without name rpefixes
 : ignChanges not empty => ignore changes of the specified kind (e.g. "changedType")
 :)  
declare function f:finalizeXsdBaseDiff($report as element(), $options as element(options)?)
        as element() {
    let $noprefix := $options/@noprefix/xs:boolean(.)
    let $ignChanges := $options/@ignChanges/tokenize(.)
    return
        f:finalizeBaseDiffRC($report, $noprefix, $ignChanges)
};

declare function f:finalizeBaseDiffRC($n as node(), 
                                      $noprefix as xs:boolean?,
                                      $ignChanges as xs:string*)
        as node()* {
    typeswitch($n)
    case element(z:xsdDiff) return
        element {node-name($n)} {
            attribute format {"base"},
            for $a in $n/(@* except @format) return f:finalizeBaseDiffRC($a, $noprefix, $ignChanges),
            for $c in $n/node() return f:finalizeBaseDiffRC($c, $noprefix, $ignChanges)            
        }
        
    case element(z:changed) | element(z:componentsChanged) return
        let $children := $n/node()/f:finalizeBaseDiffRC(., $noprefix, $ignChanges)
        return if (empty($children)) then () else 
            element {node-name($n)} {
                attribute count {count($children)},
                for $a in $n/(@* except @count) return f:finalizeBaseDiffRC($a, $noprefix, $ignChanges),
                $children
            }
         
    case element(z:component) return
        let $children := $n/node()/f:finalizeBaseDiffRC(., $noprefix, $ignChanges)
        return if (empty($children)) then () else 
            element {node-name($n)} {
                for $a in $n/@* return f:finalizeBaseDiffRC($a, $noprefix, $ignChanges),
                $children
            }
            
    case element(z:items) return
        let $children := $n/node()/f:finalizeBaseDiffRC(., $noprefix, $ignChanges)
        return if (count($children) le 1 and 
                (every $name in $children/node-name(.) satisfies $name eq QName($app:URI_LTREE, 'unchangedItems'))) then () else 
            <z:items>{
                for $a in $n/@* return f:finalizeBaseDiffRC($a, $noprefix, $ignChanges),
                $children
            }</z:items>
         
    case element(z:changedItems) return
        let $children := $n/node()/f:finalizeBaseDiffRC(., $noprefix, $ignChanges)
        return if (empty($children)) then () else 
            <z:changedItems count="{count($children)}">{
                for $a in $n/(@* except @count) return f:finalizeBaseDiffRC($a, $noprefix, $ignChanges),
                $children
            }</z:changedItems>
         
    case element(z:changedItem) return
        let $children := $n/node()/f:finalizeBaseDiffRC(., $noprefix, $ignChanges)
        return if (empty($children)) then () else 
            element {node-name($n)} {
                for $a in $n/@* return f:finalizeBaseDiffRC($a, $noprefix, $ignChanges),
                $children
            }
            
    case element() return
        if (exists($ignChanges) and local-name($n) = $ignChanges and $n/self::z:*) then () 
        else f:finalizeBaseDiffRC_copyElem($n, $noprefix, $ignChanges) 
    case attribute() return
        let $value :=
(:        
            if (local-name($n) = 'apath') then
                string-join(for $step in tokenize($n, '/') return replace($step, '^\i\c+:', ''), '/')
            else if (local-name($n) = ('fr', 'to') and $n/parent::*/local-name() = ('changedType')) then
                replace($n, '^\i\c+:', '')
            else string($n)
:)
            string($n)
        return
            attribute {node-name($n)} {$value}
         
    default return $n         
};

declare function f:finalizeBaseDiffRC_copyElem($elem as element(),
                                               $noprefix as xs:boolean?,
                                               $ignChanges as xs:string*) as element() {
    element {node-name($elem)} {
        for $a in $elem/@* return f:finalizeBaseDiffRC($a, $noprefix, $ignChanges),
        for $c in $elem/node() return f:finalizeBaseDiffRC($c, $noprefix, $ignChanges)
    }
};

declare function f:xsdsChanged($ltreeDiffs as element(),
                               $nsmap1 as element(zz:nsMap),
                               $nsmap2 as element(zz:nsMap),
                               $schemas1 as element(xs:schema)*,
                               $schemas2 as element(xs:schema)*) 
        as element() {
    <z:xsdsChanged>{
        let $locs := distinct-values(( 
            $ltreeDiffs//(@loc, @parentTypeLoc)[string()]/replace(., '\).*', ')') ! concat('1#', .)
        ))
                
        for $loc in $locs
        let $locator := substring($loc, 3)
        let $context := substring($loc, 1, 1)
        let $comp := if ($context eq '2') then app:resolveComponentLocator($locator, $nsmap2, $schemas2)
                     else app:resolveComponentLocator($locator, $nsmap1, $schemas1)
        let $uri := $comp/root()/(document-uri(.), */@xml:base)[1]
        group by $uri
        let $fname := replace($uri, '.*[/\\]', '')        
        order by $fname
        return
            <z:xsd>{
                attribute fileName {$fname},
                for $loc in $locator order by $loc return $loc ! <z:change xsdPath="{.}"/>
            }</z:xsd>
    }</z:xsdsChanged>
};


