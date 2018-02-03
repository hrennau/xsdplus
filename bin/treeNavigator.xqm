(:
 : -------------------------------------------------------------------------
 :
 : treeNavigator.xqm - functions providing navigation.
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.xsdplus.org/ns/xquery-functions";

declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_namespaceTools.xqm";    

(:~
 : Returns an XPath string leading from a start node to a destination
 : node. The path steps use normalized prefixes to indicate the namespaces.
 :
 : @param from the node from which the XPath starts
 : @param to the node where the XPath leads
 : @nsMap a namespace prefix map
 : @return the XPath expression text
 :)
declare function f:getPath($from as element(), 
                           $to as node(), 
                           $nsMap as element(zz:nsMap)?)
      as xs:string {
   string-join(
      $to/ancestor-or-self::node()[. >> $from]/(
         if (self::attribute()) then
            concat('@', 
               if (not(contains(name(), ':'))) then name() else 
                  tt:normalizeQName(node-name(.), $nsMap))
         else
            concat(tt:normalizeQName(node-name(.), $nsMap), '[',
               let $nodeName := node-name(.) return 
                  1 + count(preceding-sibling::*[node-name(.) eq $nodeName])
               , ']'))

   , "/")
};
