(:
 : -------------------------------------------------------------------------
 :
 : baseTree.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="deps" type="node()" func="depsOp">
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="gnames" type="nameFilter?" pgroup="comps"/>         
         <param name="global" type="xs:boolean?" default="false"/>         
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <pgroup name="in" minOccurs="1"/>         
         <pgroup name="comps" maxOccurs="1"/>         
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
    "baseTypeFinder.xqm",
    "componentFinder.xqm",
    "componentLocator.xqm",
    "constants.xqm",
    "targetNamespaceTools.xqm",
    "typeInspector.xqm",
    "utilities.xqm";
    
declare namespace zz="http://www.xsdr.org/ns/structure";
declare namespace z="http://www.xsdplus.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `deps`.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:depsOp($request as element())
        as element() {
    let $schemas := app:getSchemas($request) (: tt:getParams($request, 'xsd xsds')/* :)
    let $enames := tt:getParams($request, 'enames')
    let $tnames := tt:getParams($request, 'tnames')    
    let $gnames := tt:getParams($request, 'gnames')  
    let $global := tt:getParams($request, 'global')
    
    let $comps :=
        if (empty(($enames, $tnames, $gnames))) then
            $schemas/xs:element[tt:matchesNameFilter(@name, $enames)]
        else (
            if (not($enames)) then () else (
                if ($global) then $schemas/xs:element
                else $schemas/descendant::xs:element
                )[tt:matchesNameFilter(@name, $enames)],
            if (not($tnames)) then () else 
                $schemas/(descendant::xs:simpleType, descendant::xs:complexType)
                [tt:matchesNameFilter(@name, $tnames)],
            if (not($gnames)) then () else 
                $schemas/descendant::xs:group
                [tt:matchesNameFilter(@name, $gnames)]
        )                
    let $compKind := 
        switch($comps[1]/local-name())
        case 'element' return 'elem'
        case 'simpleType' return 'type'
        case 'complexType' return 'type'
        case 'group' return 'group'
        default return ()
        
    let $report :=
        for $comp in $comps
        let $name := $comp/@name
        let $namespace := $comp/ancestor::xs:schema/@targetNamespace
        let $deps := f:deps($comp, $schemas)
        let $depsElem := app:depsMap2Elem($deps)
        return
            element {$compKind} {
                attribute name {$name},
                attribute namespace {$namespace},
                $depsElem
            }
    return
        <z:deps countXsds="{count($schemas)}">{
           $report
        }</z:deps>
};     

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns for a given schema component (element or attribute declaration, 
 : type or group definitions) all direct and indirect dependencies on other 
 : components. Each dependency is provided as a QName.
 :
 : @param comp a schema component
 : @param schemas the schema elements currently considered
 : @return a map providing the QNames of components identified as
 :     direct or indirect dependencies of the given component
 :)
declare function f:deps($comp as element(), 
                        $schemas as element(xs:schema)+)
        as map(*) {
    let $directDeps := f:directDeps($comp)
    let $analyzedSoFar :=
        map{
            'types': $comp/(self::xs:simpleType, self::xs:complexType)
                /QName(ancestor::xs:schema/@targetNamespace, @name), 
            'groups': $comp/self::xs:group
                /QName(ancestor::xs:schema/@targetNamespace, @name),
            'agroups': $comp/self::xs:attributeGroup            
                /QName(ancestor::xs:schema/@targetNamespace, @name),            
            'elems': $comp/self::element
                /QName(ancestor::xs:schema/@targetNamespace, @name),            
            'atts': $comp/self::attribute
                /QName(ancestor::xs:schema/@targetNamespace, @name)            
        }
    return
        f:_depsRC($directDeps, $analyzedSoFar, $schemas)
};

(:~
 : Returns for a given schema components (element or attribute declarations, 
 : type or group definitions) all direct dependencies on other components. 
 : Each dependency is provided as a QName.
 :
 : @param comp a schema component
 : @param schemas the schema elements currently considered
 : @return a map providing the QNames of components identified as
 :     direct or indirect dependencies of the given component
 :)
declare function f:directDeps($comp as element())
        as map(*) {
    let $isUserDefined :=
            function($compName as xs:QName) as xs:boolean 
                {not(namespace-uri-from-QName($compName) eq $app:URI_XSD)}
    let $types := distinct-values((
        $comp//(@type, @base, @itemType)/resolve-QName(., ..),            
        $comp//@memberTypes
            /(for $t in tokenize(normalize-space(.), ' ') return 
                resolve-QName($t, ..))))
        [$isUserDefined(.)]                        
    let $groups := distinct-values(
        $comp//xs:group/@ref/resolve-QName(., ..))
        [$isUserDefined(.)]        
    let $agroups := distinct-values(
        $comp//xs:attributeGroup/@ref/resolve-QName(., ..))
        [$isUserDefined(.)]        
    let $elems := distinct-values(
        $comp/descendant-or-self::xs:element/@ref/resolve-QName(., ..))
        [$isUserDefined(.)]        
    let $atts := distinct-values(
        $comp/descendant-or-self::xs:attribute/@ref/resolve-QName(., ..))
        [$isUserDefined(.)]        
    return
        map{
            'types': sort($types, (), local-name-from-QName#1), 
            'groups': sort($groups, (), local-name-from-QName#1),
            'agroups': sort($agroups, (), local-name-from-QName#1),            
            'elems': sort($elems, (), local-name-from-QName#1),
            'atts': sort($elems, (), local-name-from-QName#1)            
        }
}; 

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Recursive helper function of `deps`.
 :)
declare function f:_depsRC($depsSoFar as map(*), 
                           $analyzedSoFar as map(*),
                           $schemas as element(xs:schema)+)
        as map(*) {
    let $notYetAnalyzed :=
        map{
            'types': $depsSoFar?types[not(. = $analyzedSoFar?types)],
            'groups': $depsSoFar?groups[not(. = $analyzedSoFar?groups)],            
            'agroups': $depsSoFar?agroups[not(. = $analyzedSoFar?agroups)],
            'elems': $depsSoFar?elems[not(. = $analyzedSoFar?elems)],            
            'atts': $depsSoFar?atts[not(. = $analyzedSoFar?atts)]            
        }
    return
        if (empty((
            $notYetAnalyzed?types, 
            $notYetAnalyzed?groups, 
            $notYetAnalyzed?agroups, 
            $notYetAnalyzed?elems,
            $notYetAnalyzed?atts))) then
                $depsSoFar
        else
        
    let $compsToBeAnalyzed := (
        $notYetAnalyzed?types ! app:findType(., $schemas),    
        $notYetAnalyzed?groups ! app:findGroup(., $schemas),
        $notYetAnalyzed?agroups ! app:findAttGroup(., $schemas),
        $notYetAnalyzed?elems ! app:findElem(., $schemas),
        $notYetAnalyzed?atts ! app:findAtt(., $schemas)        
    )        
    let $directDeps := $compsToBeAnalyzed/f:directDeps(.)
    let $newDepsSoFar :=
        map{
            'types': distinct-values(($depsSoFar?types, $directDeps?types)),
            'groups': distinct-values(($depsSoFar?groups, $directDeps?groups)),            
            'agroups': distinct-values(($depsSoFar?agroups, $directDeps?agroups)),
            'elems': distinct-values(($depsSoFar?elems, $directDeps?elems)),            
            'atts': distinct-values(($depsSoFar?atts, $directDeps?atts))            
        }
    let $newAnalyzedSoFar :=
        map{
            'types': distinct-values(($analyzedSoFar?types, $notYetAnalyzed?types)),
            'groups': distinct-values(($analyzedSoFar?groups, $notYetAnalyzed?groups)),            
            'agroups': distinct-values(($analyzedSoFar?agroups, $notYetAnalyzed?agroups)),
            'elems': distinct-values(($analyzedSoFar?elems, $notYetAnalyzed?elems)),            
            'atts': distinct-values(($analyzedSoFar?atts, $notYetAnalyzed?atts))            
        }
    return
        f:_depsRC($newDepsSoFar, $newAnalyzedSoFar, $schemas)
};

