(:
 : -------------------------------------------------------------------------
 :
 : mockWriter.xqm - operations and functions creating mocks
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="exportMocks" type="xs:integer" func="exportMocksOp">
         <param name="dir" type="directory" fct_dirExists="true"/>      
         <param name="mocks" type="docFOX" fct_minDocCount="1"/> 
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
    "locationTreeComponents.xqm",
    "occUtilities.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.xsdr.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `exportMocks`.
 :
 : @param request the operation request
 : @return the number of exported mocks
 :) 
declare function f:exportMocksOp($request as element())
        as xs:integer {
    let $mocks := tt:getParam($request, 'mocks')/*
    let $dir := tt:getParam($request, 'dir')
    let $_writes :=
        for $mock in $mocks/*
        let $mockExport := f:finalizeMock($mock)
        let $postfix := $mock/@zz:scenario[string()]
        let $extension :=
             if ($mockExport instance of node()) then '.xml'
             else '.json'
        let $fname := 
            concat(
                string-join((string-join(($dir, local-name($mock)), '/'), $postfix), '-'),
                $extension)
        
        return (
            1,
            file:write($fname, $mockExport)
        )            
    return
        sum($_writes) 
};

declare function f:finalizeMock($mock as element())
        as item() {
    if ($mock/*) then f:finalizeMockRC($mock)
    else replace($mock, '^\s+|\s+$', '')
};        

declare function f:finalizeMockRC($n as node())
        as node() {
    typeswitch($n)        
    case element() return
        element {node-name($n)} {
            $n/(@* except @zz:scenario),
            for $c in $n/node() return f:finalizeMockRC($c)
        }
    default return $n        
};        
