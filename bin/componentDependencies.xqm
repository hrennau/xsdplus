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
         <param name="global" type="xs:boolean?" default="true"/>      
         <param name="sgroupStyle" type="xs:string?" default="ignore" fct_values="expand, compact, ignore"/>         
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
    "substitutionGroups.xqm",
    "targetNamespaceTools.xqm",
    "typeInspector.xqm",
    "util.xqm";
    
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
 : Implements operation `deps`. Given a set of element declarations,
 : type definitions or group definitions, the result is a report
 : of all schema components on which the declarations or definitions 
 : directly or indirectly depends. These components include: element 
 : and attribute declarations, type definitions, group and attribute
 : group definitions.
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
    let $sgroupStyle := tt:getParam($request, 'sgroupStyle')    
    
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
        let $deps := f:deps($comp, $sgroupStyle, $schemas)
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
 : type or group definition) all direct and indirect dependencies on other 
 : components. Dependencies are grouped by component kind (element declarations,
 : attribute declarations, group definitions, attribute group definitions)
 : and represented by the component QName.
 :
 : @param comp a schema component
 : @param schemas the schema elements currently considered
 : @return a map providing the QNames of components identified as
 :     direct or indirect dependencies of the given component
 :)
declare function f:deps($comp as element(), 
                        $sgroupStyle as xs:string,
                        $schemas as element(xs:schema)+)
        as map(*) {
    let $sgroups := app:sgroupMembers($schemas)
    let $directDeps := f:directDeps($comp, $sgroups, $sgroupStyle)
    
    (: the initial value of 'analyzedSoFar' contains a single
       component, which is the component received as input :)
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
    let $depsRaw := f:_depsRC($directDeps, $analyzedSoFar, $sgroups, $sgroupStyle, $schemas)    
    
    let $deps :=        
        if (not($comp/self::xs:element)) then $depsRaw else
            let $compName := $comp/app:getComponentName(.)
            return
                map:merge((
                    (: map:entry('elems', $depsRaw?elems[not(. eq $compName)]), :)   
                    (: hjr, 20180112 - bugfix; revealed by XSD obtaind from Kaercher DTD :)
                    map:entry('elems', $depsRaw?elems),
                    $depsRaw
                    ),
                    map{'duplicates':'use-first'}
               )
    return
        $deps
};

(:~
 : Returns for a given schema components (element or attribute declarations, 
 : type or group definitions) all direct dependencies on other components. 
 : Dependencies are grouped by component kind and represented by component
 : QName.
 :
 : Note. The term "direct dependencies" means the dependencies caused
 : by references occurring in the XML element representing the component 
 : itself, rather than in the result of recursively resolving another 
 : dependence. Every direct dependence is represented by one of these 
 : attributes:
 :     @ref, @type, @base, @itemType, @memberTypes, @substitutionGroup 
 :
 : @param comp a schema component
 : @param schemas the schema elements currently considered
 : @return a map providing the QNames of components identified as
 :     direct or indirect dependencies of the given component
 :)
declare function f:directDeps($comp as element(),
                              $sgroups as map(xs:QName, xs:QName*)?,
                              $sgroupStyle as xs:string)
        as map(*) {
    (: a function item returning true if a given QName is not
       in the schema namespace :)
    let $isUserDefined :=
            function($compName as xs:QName) as xs:boolean 
                {not(namespace-uri-from-QName($compName) eq $app:URI_XSD)}
    
    let $types := distinct-values((
        $comp//(@type, @base, @itemType)[string(.)]/resolve-QName(., ..),            
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
    let $elems := distinct-values((
        $comp/descendant-or-self::xs:element/@ref/resolve-QName(., ..)
        [$isUserDefined(.)],

        if ($sgroupStyle eq 'ignore') then () else (
        
            (: add substitution groups of which this element is a member :)        
            $comp//@substitutionGroup
                 /(for $e in tokenize(normalize-space(.), ' ') return resolve-QName($e, ..)),
                 
            (: add the members of the substitution group of which this element is the head :)             
            if (empty($sgroups)) then () else $sgroups($comp/app:getComponentName(.))                
            ))[not(. eq $comp/app:getComponentName(.))]
        )            
    let $atts := distinct-values(
        $comp/descendant-or-self::xs:attribute/@ref/resolve-QName(., ..))
        [$isUserDefined(.)]        
    return
        map{
            'types': sort($types, (), local-name-from-QName#1), 
            'groups': sort($groups, (), local-name-from-QName#1),
            'agroups': sort($agroups, (), local-name-from-QName#1),            
            'elems': sort($elems, (), local-name-from-QName#1),
            'atts': sort($atts, (), local-name-from-QName#1)            
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
                           $sgroups as map(xs:QName, xs:QName*)?,
                           $sgroupStyle as xs:string,
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
    let $compsToBeAnalyzed := (
        $notYetAnalyzed?types ! app:findType(., $schemas),    
        $notYetAnalyzed?groups ! app:findGroup(., $schemas),
        $notYetAnalyzed?agroups ! app:findAttGroup(., $schemas),
        $notYetAnalyzed?elems ! app:findElem(., $schemas),
        $notYetAnalyzed?atts ! app:findAtt(., $schemas)        
    )        
    return
        if (empty(($compsToBeAnalyzed))) then $depsSoFar
        else
        
    let $directDeps := $compsToBeAnalyzed/f:directDeps(., $sgroups, $sgroupStyle)
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
        f:_depsRC($newDepsSoFar, $newAnalyzedSoFar, $sgroups, $sgroupStyle, $schemas)
};

