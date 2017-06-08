(:
 : -------------------------------------------------------------------------
 :
 : pathDictionary.xqm - functions creating a data path dictionary
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="pathDict" type="item()" func="pathDict">     
         <param name="ancFilter" type="nameFilter?"/>
         <param name="btree" type="docFOX" fct_minDocCount="1"/>
         <param name="ename" type="nameFilter?"/>         
         <param name="format" type="xs:string?" default="txt" fct_values="xml, txt"/>
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
declare function f:pathDict($request as element())
        as item() {       
    let $btree := tt:getParams($request, 'btree')/*
    let $ename := tt:getParams($request, 'ename') 
    let $format := tt:getParams($request, 'format   ')    
    let $ancFilter as element(nameFilter)? := tt:getParams($request, 'ancFilter')

    let $btreeRootElem := 
        let $btreeRootElems := $btree/descendant::z:baseTree/f:getBtreeRoot(.)
        return
            if ($ename) then $btreeRootElems[tt:matchesNameFilter(local-name(.), $ename)][1]
            else $btree/descendant::z:baseTree[1]/f:getBtreeRoot(.)
    let $btreeElem := $btreeRootElem/..

    let $paths := $btreeRootElem//*[not(self::z:*) or self::z:_attribute_]/f:getBnodePath(., $ancFilter) => distinct-values()
    let $items :=
        for $path in $paths
        group by $name := replace($path, '^.*/(.*)', '$1')
        order by replace($name, '^@', '')        
        return
            <item name="{$name}">{
                for $p in $path order by $p return <path p="{$p}"/>
            }</item>
    let $report := <items>{$items}</items>
    return
        if ($format eq 'xml') then $report
        else
            string-join(
                for $item in $report/item
                return (
                    $item/@name,
                    $item/*/@p ! concat('   ', .),
                    ''
                )
            , '&#xA;')
};
