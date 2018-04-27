(:
 : -------------------------------------------------------------------------
 :
 : baseTreeReporter.xqm - functions reporting the contents of base trees
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
    <operations>
      <operation name="btreeDependencies" type="node()" func="btreeDependencies">
         <param name="btree" type="docFOX+" sep="SC" fct_minDocCount="1"/>
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
    "componentFinder.xqm",
    "constants.xqm",
    "util.xqm";
    
declare namespace z2="http://www.xsdr.org/ns/structure";
declare namespace z="http://www.xsdplus.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `btreeDependencies`.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:btreeDependencies($request as element())
        as element() {
    let $btree := tt:getParams($request, 'btree')/*
    
    let $types :=
        distinct-values(
            for $bt in $btree//z2:baseTree
            let $nsMap := $bt/z2:nsMap
            for $zt in $bt//@z2:type
            let $lname := replace($zt, '.*:', '')
            let $uri := 
                if (not(contains($zt, ':'))) then () 
                else $nsMap/*[@prefix eq substring-before($zt, ':')]/@uri 
            where not($uri eq $app:URI_XSD)
            order by $lname
            return QName($uri, $lname)
        )
    let $groups := ()
    let $agroups := ()
    let $elems := ()
    let $dependencies :=
        map{
            'types': $types,
            'groups': $groups,
            'agroups': $agroups,
            'elems': $elems
        }
    let $dependenciesElem := app:depsMap2Elem($dependencies)
    return
        <btreeDependencies>{
            $dependenciesElem
        }</btreeDependencies>
};     

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)
