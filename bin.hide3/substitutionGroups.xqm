(:
 : -------------------------------------------------------------------------
 :
 : substitutionGroups.xqm - functions for reporting substitution groups
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="sgroups" type="node()" func="sgroupsOp">
         <param name="withMembers" type="xs:boolean?" default="false"/>
         <param name="snames" type="nameFilter?"/>
         <param name="snspaces" type="nameFilter?"/>
         <param name="mnames" type="nameFilter?"/>
         <param name="mnspaces" type="nameFilter?"/>
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
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
    "baseTypeFinder.xqm",
    "componentFinder.xqm",
    "componentLocator.xqm",
    "constants.xqm",
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
 : Implements operation `sgroups`.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:sgroupsOp($request as element())
        as element() {
    let $schemas := app:getSchemas($request)
    let $withMembers := tt:getParam($request, 'withMembers')
    let $snames := tt:getParam($request, 'snames')    
    let $snspaces := tt:getParam($request, 'snspaces')
    let $mnames := tt:getParam($request, 'mnames')    
    let $mnspaces := tt:getParam($request, 'mnspaces')
    return
        if (not($withMembers)) then
            let $sgroups := f:sgroups($schemas, $snames, $snspaces, $mnames, $mnspaces)
            return
                <sgroups count="{count($sgroups)}">{
                    for $sgroup in $sgroups
                    let $lname := local-name-from-QName($sgroup)
                    let $uri := namespace-uri-from-QName($sgroup)
                    order by lower-case($lname), lower-case($uri)
                    return
                        <sgroup name="{$lname}" namespace="{$uri}"/>
                }</sgroups>
        else
            let $sgroupsMap := f:sgroupMembers($schemas, $snames, $snspaces, $mnames, $mnspaces)
            let $sgroups := map:keys($sgroupsMap) => sort((), local-name-from-QName#1)
            let $sgroupInfos :=
                for $sgroup in $sgroups
                let $lname := local-name-from-QName($sgroup)
                let $uri := namespace-uri-from-QName($sgroup)
                let $members := $sgroupsMap($sgroup)
                order by lower-case($lname), lower-case($uri)
                return
                    <sgroup name="{$lname}" namespace="{$uri}" countMembers="{count($members)}">{
                        for $member in $members
                        let $lname := local-name-from-QName($member)
                        let $uri := namespace-uri-from-QName($member)
                        order by lower-case($lname), lower-case($uri)
                        return
                            <member name="{$lname}" uri="{$uri}"/> 
                    }</sgroup>
            let $report :=
                <sgroups count="{count($sgroups)}" 
                         countMembers="{count($sgroupInfos//member)}">{
                    if ($withMembers) then $sgroupInfos
                    else $sgroupInfos/element {node-name(.)} {@*}
                }</sgroups>
            return
                $report
};

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns the names of substitution groups, optionally filtered.
 :
 : @param schemas the schema elements currently considered
 : @param snames a filter to be applied to substitution group names
 : @param snspaces a filter to be applied to substitution group namespaces
 : @param mnames a filter to be applied to substitution group member names
 : @param mnspaces a filter to be applied to substitution group member namespaces
 : @return a list of qualified substitution group names
 :)
declare function f:sgroups($schemas as element(xs:schema)*,
                           $snames as element(nameFilter)?,
                           $snspaces as element(nameFilter)?,                           
                           $mnames as element(nameFilter)?,
                           $mnspaces as element(nameFilter)?)                           
        as xs:QName* {
    if ($mnames or $mnspaces) then
        f:sgroupMembers($schemas, $snames, $snspaces, $mnames, $mnspaces) => map:keys()
        else
        
    let $allGroups :=
        distinct-values(
            for $sgroupAtt in $schemas/xs:element/@substitutionGroup
            return
                tokenize(normalize-space($sgroupAtt), ' ') ! resolve-QName(., $sgroupAtt/..)
         )
    let $groups := $allGroups
    let $groups := if (not($snames)) then $groups else
            $groups[tt:matchesNameFilter(local-name-from-QName(.), $snames)]
    let $groups := if (not($snspaces)) then $groups else
            $groups[tt:matchesNameFilter(namespace-uri-from-QName(.), $snspaces)]
    return $groups                
};

declare function f:sgroupMembers($schemas as element(xs:schema)*)                           
        as map(xs:QName, xs:QName+) {
    f:sgroupMembers($schemas, (), (), (), ())        
};        

(:~
 : Returns the names and member names of substitution groups.  
 : Groups and group members are optionally filtered.
 :
 : @param schemas the schema elements currently considered
 : @param snames a filter to be applied to substitution group names
 : @param snspaces a filter to be applied to substitution group namespaces
 : @param mnames a filter to be applied to substitution group member names
 : @param mnspaces a filter to be applied to substitution group member namespaces
 : @return a map associating qualified group names with lists of qualified member names
 :) 
declare function f:sgroupMembers($schemas as element(xs:schema)*,
                           $snames as element(nameFilter)?,
                           $snspaces as element(nameFilter)?,                           
                           $mnames as element(nameFilter)?,
                           $mnspaces as element(nameFilter)?)                           
        as map(xs:QName, xs:QName+) {
    (: map: member name => group name(s) :)
    let $allMembers :=
        map:merge(
            for $sgroupAtt in $schemas/xs:element/@substitutionGroup
            let $elemName := app:getComponentName($sgroupAtt/..)
            let $inGroups := tokenize(normalize-space($sgroupAtt), ' ') 
                             ! resolve-QName(., $sgroupAtt/..)
            return map:entry($elemName, $inGroups)
        )
    let $allGroups := distinct-values($allMembers?*)
    
    let $groups := $allGroups
    let $groups := if (not($snames)) then $groups else
            $groups[tt:matchesNameFilter(local-name-from-QName(.), $snames)]
    let $groups := if (not($snspaces)) then $groups else
            $groups[tt:matchesNameFilter(namespace-uri-from-QName(.), $snspaces)]
            
    let $result :=
        map:merge(
            for $group in $groups 
            let $members := map:keys($allMembers)[$allMembers(.) = $group]
            where 
                (not($mnames) or (
                    some $member in $members satisfies 
                        tt:matchesNameFilter(local-name-from-QName($member), $mnames)))
                and                  
                (not($mnspaces) or (
                    some $member in $members satisfies 
                        tt:matchesNameFilter(namespace-uri-from-QName($member), $mnspaces)))
            return map:entry($group, $members)
        )
    return
        $result
};
