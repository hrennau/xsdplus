xquery version "3.0";

(:~
 : This module provides functions to accomplish various namespace-related
 : tasks.
 :
 : Uses modules: -
 :  
 : Public functions:
 : <ul>
 :    <li>addNSB - adds a namespace binding to an element</li>
 :    <li>addNSBs - adds namespace bindings to an element.</li>
 :    <li>changeTns - changes the target namespace of a schema document</li>
 :    <li>copyDeepNSB - copies namespace bindings from a source fragment a target node</li>
 :    <li>copyNSB - copies namespace bindings from a source node a target node</li>
 :    <li>createNsMap - creates a namespace bindings map capturing the 
             namespace bindings of a supplied element.</li>
 :    <li>findPrefix - finds for a given namespace a prefix not yet used in a document</li>
 :    <li>namespaceBindings - reports the namespace bindings found in a set of XML fragments</li>
 :    <li>normalizeQName - normalizes a QName according to a supplied mapping 
 :           of namespace URIs to prefixes.</li>
 : </ul>
 :
 : Private functions: -
 :
 : Global variables: -
 :
 : @author Hans-Juergen Rennau
 : @author Xia Lxi
 :
 : @version 20121202-1
 :)   
(: ######################################################################### :)

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_errorAssistent.xqm"
;    

declare copy-namespaces preserve, inherit;

declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

(:~
 : Adds an in-scope namespace to an element, if it does not already have it.
 : In the latter case, the element is returned unchanged. Special case: 
 : if the namespace URI of the in-scope namespace is empty, the element 
 : is returned with the default namespace removed, in order to allow 
 : referencing namespace-less elements from within the element. 
 :
 : Note: this function requires that copy namespaces modes contains 
 : 'inherited'.
 :
 : @param e the element to be modified
 : @param uri the namespace URI
 : @param prefix the prefix to be used
 :
 : @version: 20121202-1
 :)
declare function f:addNSB($e as element()?,
                          $uri as xs:string,
                          $prefix as xs:string) 
                 as element()? {
   if ($uri eq "") then 
      <_tmp xmlns="">{$e}</_tmp>/*   (: remove default namespace :)
   else if ($uri eq namespace-uri-for-prefix($prefix, $e)) then      
      $e                             (: return unchanged :) 
   else      
      let $ename := QName($uri, string-join(($prefix[.], "_"), ":"))                        
      let $copy := element {$ename} {$e}/*
      return
         document {$copy}/*
};

(:~
 : Adds namespace bindings to an element. The namespace bindings
 : are supplied as a namespace bindings map.
 :
 : @param elem the element
 : @param nsmap a map associating namespace prefixes with URIs
 : @return a copy of the element with namespace bindings added
 :
 : @version: 20121202-1
:)
declare function f:addNSBs($elem as element()?, 
                           $nsmap as element(zz:nsMap)) 
      as element()? {
(: COPY_NAMESPACE_FIX

   let $copy :=
      <z:mp>{
         $nsmap/*[@prefix/string()]/attribute {QName(@uri, concat(@prefix, ':', '_'))} {}, $elem
      }</z:mp>/*
   return
      document {$copy}/*
:)
    element {node-name($elem)} {
        for $ns in $nsmap/* return       
            namespace {$ns/@prefix} {$ns/@uri},
        $elem/@*,
        $elem/node()
    }   
};

(:~
 : Adds the "used" namespace bindings to an element. These are defined as
 : follows: for each prefix found in the element and its descendant,
 : the first-in-document-order namespace binding is used; if the
 : element has a default namespace, this is also added to the
 : namespace bindings.
 :
 : @param elem the element
 : @return a copy of the element with namespace bindings added
 :
 : @version: 20121215-1
:)
declare function f:addUsedNSBs($elem as element()?) 
      as element()? {
   let $prefixes :=  distinct-values($elem/descendant-or-self::*/in-scope-prefixes(.))
   let $nsmap :=
      <zz:nsMap>{
         for $prefix in $prefixes[not (. eq 'xml')]
         let $uri := 
            $elem/descendant-or-self::*[in-scope-prefixes(.) = $prefix][1]/
            namespace-uri-for-prefix($prefix, .)
         order by lower-case($prefix)
         return
            <zz:ns prefix="{$prefix}" uri="{$uri}"/>
         ,
         let $defaultNs := namespace-uri-for-prefix('', $elem)
         return
            if (string($defaultNs)) then <zz:ns prefix="" uri="{$defaultNs}"/>
            else ()
      }</zz:nsMap>
   return f:addNSBs($elem, $nsmap)
};

(:~
 : Changes the target namespace of a schema to a new value. If the
 : new value is the empty string, the target namespace is removed.
 : Note that 'import' elements are transformed into 'include', if the
 : imported namespace matches the new namespace.
 :
 : @param n a node of the schema to be transformed
 : @param $uri the new target namespace
 : @param $prefix the prefix to be used for the new target namespace
 : @return the transformed schema node
 :
 : @version 20121202-2
 :)
declare function f:changeTns($n as node(), 
                             $uri as xs:string, 
                             $prefix as xs:string?) 
as node() 
{
   typeswitch ($n)
   case document-node() return f:changeTns($n/*, $uri, $prefix)

   case $e as element(xs:schema) return      
      let $usePrefix := f:findPrefix($e, $uri, $prefix, ())
      let $useNsmap := <zz:nsMap><zz:ns prefix="{$usePrefix}" uri="{$uri}"/></zz:nsMap>
      
      let $changed :=
         <xs:schema>{
	        if ($uri) then attribute targetNamespace {$uri} else (),
            attribute xml:base {base-uri($n)},
            attribute z:isChameleon {true()},
	        for $a in $n/(@* except (@targetNamespace, @xml:base), node()) 
            return 
               f:changeTns($a, $uri, $usePrefix)
	     }</xs:schema>
      let $copyNs := f:copyNSB($n, $changed)
      let $addTns := f:addNSBs($copyNs, $useNsmap)
      return
         $addTns
      
(:      
         f:addNSB(
            f:copyNSB($n, 
               <xs:schema>{
	          if ($uri) then attribute targetNamespace {$uri} else (),
                  attribute xml:base {base-uri($n)},
                  attribute z:isChameleon {true()},
	          for $a in $n/(@* except (@targetNamespace, @xml:base), node()) 
              return 
                 f:changeTns($a, $uri, $usePrefix)
	       }</xs:schema>) 
	       , $uri, $usePrefix)
:)
   (: do not change xs:include :)
   case element(xs:include) return $n

   (: transform xs:import into xs:include, if ncessary :)
   case element(xs:import) return
      if (not($n/@namespace eq $uri)) then $n 
      else
         <xs:include>{
	   $n/((@* except @namespace), node())
         }</xs:include>

   case $e as element() return
      element {node-name($e)} {
         for $ac in $e/(@*, node()) return f:changeTns($ac, $uri, $prefix)
      }

   case $a as attribute() return
   (: 
    : if the attribute has no namespace sensitive value, it is returned as is;
    : else any qname referencing the changed tns is adapted by replacing the
    : prefix by the prefix to be used for the new namespace. 
    :)
      if (namespace-uri-from-QName(node-name($a))) then $a else

      let $prevTns := string($a/ancestor::xs:schema/@targetNamespace) 
      let $newPrefixPart := if ($prefix) then concat($prefix, ":") else ""
      return
         attribute {node-name($a)} {
            if ($a/local-name() = ("type", "ref", "base", "itemType")) 
            then
	       if (namespace-uri-from-QName(resolve-QName($a, $a/..)) eq $prevTns)
               then string-join(($newPrefixPart, replace($a, ".*:", "")), "")
               else $a
            else if ($a/local-name() eq "memberTypes") then
                string-join(
	           for $name in tokenize($a, "\s+")
                   return
                      if (namespace-uri-from-QName(resolve-QName($name, $a/..)) eq $prevTns)
                      then string-join(($newPrefixPart, replace($name, ".*:", "")), "")
                      else $name
                , ' ')
            else $a
      }
   default return $n
};

(:~
 : Exchanges one namespace by another namespace. The namespace may, but need not be
 : the target namespace. If the new namespace is the empty string, the namespace is removed.
 : Note that 'import' elements are transformed into 'include', if the
 : imported namespace matches the new namespace.
 :
 : @param n a node of the schema to be transformed
 : @param $from namespace to be replaced
 : @param $to namespace replacing another namespace 
 : @param $prefix the prefix to be used for the new target namespace
 : @return the transformed schema node
 :
 : @version 20121202-2
 :)
declare function f:changeSchemaNS($n as node(), 
                                  $from as xs:string,
                                  $to as xs:string,
                                  $prefix as xs:string?) 
as node() 
{
    typeswitch ($n)
    case document-node() return f:changeSchemaNS($n/*, $from, $to, $prefix)

    case $e as element(xs:schema) return
        if (not($from eq $n/@targetNamespace)) then
            element {node-name($n)} {
                for $a in $n/@* return f:changeSchemaNS($a, $from, $to, $prefix),
                for $c in $n/node() return f:changeSchemaNS($c, $from, $to, $prefix)                
            }
        else    
            let $usePrefix := f:findPrefix($e, $to, $prefix, ())
            return 
                f:addNSB(
                    f:copyNSB($n, 
                        <xs:schema>{
                            attribute targetNamespace {$to},
                            attribute xml:base {base-uri($n)},
                            attribute z:isChameleon {true()},
                            for $a in $n/(@* except (@targetNamespace, @xml:base), node()) 
                                return f:changeSchemaNS($a, $from, $to, $usePrefix)
                        }</xs:schema>) 
	               , $to, $usePrefix)

   (: do not change xs:include :)
   case element(xs:include) return $n

   (: transform xs:import into xs:include, if ncessary :)
   case element(xs:import) return
      if (not($n/@namespace eq $to and $n/ancestor::xs:schema/@targetNamespace eq $from)) then $n 
      else
         <xs:include>{
	        $n/((@* except @namespace), node())
         }</xs:include>

   case $e as element() return
      element {node-name($e)} {
         for $ac in $e/(@*, node()) return f:changeSchemaNS($ac, $from, $to, $prefix)
      }

   case $a as attribute() return
   (: 
    : if the attribute has no namespace sensitive value, it is returned as is;
    : else any qname referencing the changed tns is adapted by replacing the
    : prefix by the prefix to be used for the new namespace. 
    :)
        if (namespace-uri-from-QName(node-name($a))) then $a else
        let $usePrefix := f:findPrefix($n, $to, $prefix, ())
        let $newPrefixPart := concat($usePrefix, ":")
        return
            attribute {node-name($a)} {
                if ($a/local-name() = ("type", "ref", "base", "itemType")) 
                then
                    if (namespace-uri-from-QName(resolve-QName($a, $a/..)) eq $from)
                    then string-join(($newPrefixPart, replace($a, ".*:", "")), "")
                    else $a
                    else if ($a/local-name() eq "memberTypes") then
                        string-join(
	                        for $name in tokenize($a, "\s+")
                            return
                                if (namespace-uri-from-QName(resolve-QName($name, $a/..)) eq $from)
                                then string-join(($newPrefixPart, replace($name, ".*:", "")), "")
                                else $name
                            , ' ')
                else $a
        }
   default return $n
};

(:~
 : Copy namespace bindings from the source node (element or document) to the
 : target node (element or document. If parameter $deepCopy is true, all
 : bindings found within the fragment rooted in $source are copied, else 
 : only the bindings found in $source. 
 :
 : Note that in case of a deep copy, a prefix may be bound within $source to more
 : than one namespace URI. In such a case, the first binding encountered (in
 : document order) is used.
 :
 : @param source the source node
 : @param target the target node
 : @param $deepCopy unless true, only top-level bindings are considered
 : @param excludedPrefixes prefixes that must not be used
 :)
declare function f:copyDeepNSB($source as node()*, 
                               $target as node(),
                               $excludedPrefixes as xs:string*)
   as node()? {
   let $bindings := f:namespaceBindings($source, true())/*
         [let $p := @p return empty(preceding-sibling::nsBinding[@p eq $p])]
         [not(@p = $excludedPrefixes)]
   let $wrapperNs := $bindings[@p eq ""][1]/@uri
   return
      element {QName($wrapperNs, "_")} {
         for $b at $pos in $bindings[@p ne ""] 
         return 
            attribute
               {QName($b/@uri, 
                   string-join(($b/@p[string()], concat("_", $pos)), ":"))}
               {},
         $target
      }/*
};

(:~
 : Copy namespace bindings from the source node (element or document) to the
 : target node (element or document.e. 
 :
 : @param source the source node
 : @param target the target node
 :)
declare function f:copyNSB($source as node()*, 
                           $target as node())
   as node()? 
{
(:  COPY_NAMESPACE_FIX        20141104 hjr :)
(:
   let $bindings := f:namespaceBindings($source, false())/*
   let $wrapperNs := $bindings[@p eq ""][1]/@uri
   return
      element {QName($wrapperNs, "_")} {
         for $b at $pos in $bindings[@p ne ""] 
         return 
            attribute
               {QName($b/@uri, 
                   string-join(($b/@p[string()], concat("_", $pos)), ":"))}
               {},
         $target
      }/*
:)

   let $bindings := f:namespaceBindings($source, false())/*
   return
       element {node-name($target)} {
          for $b in $bindings return
              namespace {$b/@p} {$b/@uri},
          $target/@*,
          $target/node()
       }
       
};

(:~
 : Creates a namespace bindings map capturing the namespace bindings
 : of a supplied element.
 :
 : @param elem the element
 : @return a map of namespace bindings
 :)
declare function f:createNsMap($elem as element())
      as element(zz:nsMap) {
   <zz:nsMap>{
      for $prefix in in-scope-prefixes($elem) return
         <zz:ns prefix="{$prefix}" uri="{namespace-uri-for-prefix($prefix, $elem)}"/>
   }</zz:nsMap>
};

(:~
 : Edits a namespace map, inserting or replacing the default namespace.
 :
 : @param nsmap a namespace map
 : @param defaultNs the new default namespace
 : @return the edited namespace map, containing the required default namespace
 :)
declare function f:setNsMapDefaultNs($nsmap as element(zz:nsMap), $defaultNs as xs:string)
      as element(zz:nsMap) {
    <zz:nsMap>{
        <zz:ns prefix="" uri="{$defaultNs}"/>,
        $nsmap/zz:ns[@prefix/string()]
    }</zz:nsMap>
};


(:~
 : Edits a data path by discarding all prefixes if $noprefix
 : is true, and returns the original path string otherwise.
 :
 : @path the path string
 : @noprefix indicates whether prefixes must be removed
 : @return the string to be used as rendering
 :)
declare function f:editDataPath($path as xs:string, $noprefix as xs:boolean?)
      as xs:string {
   if (not($noprefix)) then $path
   else replace($path, '(^|/)[^/]+?:', '$1')
};

(:~
 : Edits a normalized QName by discarding the prefix
 : if $noprefix is true and the namespace name is not
 : the XSD namespace name.
 :
 : @param name a normalized QName
 : @param noprefix if true, the prefix shall be discarded,
 :    provided the namespace name is not the XSD namespace name
 : @param nsmap a table associating namespaces with normalized
 :    prefixes
 :) 
declare function f:editNormalizedQName($name as xs:string?, 
                                       $noprefix as xs:boolean?,
                                       $nsmap as element(zz:nsMap))
      as xs:string? {
   if (empty($name)) then ()
   else if (not($noprefix)) then $name
   else
      let $qname := f:resolveNormalizedQName($name, $nsmap)
      let $uri := namespace-uri-from-QName($qname)
      return
         if ($uri eq $tt:URI_XSD) then $name
         else replace($name, '.*:', '')
};

(:~
 : Finds a prefix for a given namespace in the context of a given document.
 : The prefix returned has not yet been used in the document.
 :
 : @param n a node from the document in whose context the prefix is sought
 : @param uri namespace URI for which a prefix is sought
 : @prefixProposal a proposed prefix
 : @recursiveAttempt is set, indicates the recursion level above the initial call
 :
 : @version 20100105 
 :)
declare function f:findPrefix($n as node(),
                              $uri as xs:string,
		                      $prefixProposal as xs:string?,
	                          $recursiveAttempt as xs:integer?) 
                 as xs:string {
   let $currentPrefixes := distinct-values($n/root()/descendant-or-self::*/in-scope-prefixes(.))
   return
      if ($prefixProposal and not($prefixProposal = $currentPrefixes))
      then $prefixProposal
      else
         let $nextRecursiveAttempt := ($recursiveAttempt + 1, 1)[1]
         return
            f:findPrefix($n, $uri,
                          concat("ns", $nextRecursiveAttempt),
                          $nextRecursiveAttempt)
};

(:~
 : Returns copies of the namespace nodes of an element.
 :
 : @param elem the element whose namespace nodes shall be copied
 : @return copies of the namespace nodes of $elem
 :)
declare function f:namespaceNodes($elem as element()) 
        as namespace-node()+ {
    for $prefix in in-scope-prefixes($elem) return
        namespace {$prefix} {namespace-uri-for-prefix($prefix, $elem)}
};

(:~
 : Reports the namespace bindings found in a set of XML fragments 
 : (one or more elements or documents). The fragment roots are received 
 : as function parameter $roots.
 :
 : If $deep is false, only the bindings in the root element(s) are
 : considered, else all bindings found within the fragments.
 :
 : The report describes the bindings by stating a) all bindings found
 : at the root nodes, b) all bindings found at descendants provided the parent
 : node does not contain the same bindings. In other words, the report
 : shows the root bindings and all changes of binding within the fragment.
 :
 : (Note however that removals of bindings (possible in XML 1.1) are not 
 : reported.)
 :
 : Each bindings is described by a 'nsBinding' element whose @p, @uri and
 : @pa attributes contain the prefix, the namespace URI and the path
 : relative to the respective root node.
 :
 : Possible uses: a namespaceProfile can be used in order to transfer the
 : bindings of one fragment to another.
 :
 : @param $roots the fragment roots
 : @param $deep  if false, only the bindings occurring in the fragment roots
 :               are considered; otherwise, all bindings occurring withint the
 :               fragments are considered
 :
 : @version 0.1-20091212
 :)
declare function f:namespaceBindings($roots as node()*,
                                     $deep as xs:boolean) 
                 as element() {

   (: $roots = root elements :)
   let $roots := $roots/(self::document-node()/*, .)[1] return

   <nsBindings deep="{$deep}" baseUri="{$roots/base-uri(.)}">{
      if ($deep) then 
         let $allBindings := 
            <allBindings>{     
               for $root at $index in $roots,
                  $d in $root/descendant-or-self::*,
                  $p in in-scope-prefixes($d)[. ne "xml"] 
               let $uri := namespace-uri-for-prefix($p, $d)
               let $parentElem := $d/../self::*
               let $path := 
                  string-join(
                     $d/ancestor-or-self::*[not($d << $root)]/name(), "/")
               where not($parentElem) or
                     not($p = $parentElem/in-scope-prefixes(.)) or
                     not($uri eq $parentElem/namespace-uri-for-prefix($p, .))
               return
                  <nsBinding>{
                     attribute i {$index},
                     attribute p {$p},
                     attribute uri {$uri},
                     attribute pa {$path}
                  }</nsBinding>
            }</allBindings>
         return
            $allBindings/*[
               let $i := @i
               let $p := @p
               let $uri := @uri
               let $pa := @pa
               return
                  empty(preceding-sibling::nsBinding[@i eq $i and @p eq $p and @uri eq $uri and @pa eq $pa])
            ]   
      else
         for $root at $index in $roots,
             $p in in-scope-prefixes($root)[. ne "xml"] 
         let $uri := namespace-uri-for-prefix($p, $root)
         return 
            <nsBinding i="{$index}" p="{$p}" uri="{$uri}" />

   }</nsBindings>
};

(:~
 : Normalizes a QName according to a supplied binding of namespace prefixes.
 :
 : @param qname the QName to be normalized
 : @param nsmap a map representing the binding of namespace prefixes
 : @return the normalized QName
 :)
declare function f:normalizeQName(
                        $qname as xs:QName, 
                        $nsmap as element(zz:nsMap)?) 
        as xs:QName {
        
   if (empty($nsmap)) then $qname
   else
      let $uri := namespace-uri-from-QName($qname)[string()]
                    (: 20150327 - if no namespace, the URI must be empty sequence :)
      return
         if (empty($uri)) then $qname
         else
            let $prefix := $nsmap/zz:ns[@uri eq $uri]/@prefix
            return
               if (empty($prefix)) then $qname else
                  let $lexName := string-join(($prefix, local-name-from-QName($qname)), ':')
                  return QName($uri, $lexName)
};

(:~
 : Returns the string representation of a QName normalized according to a supplied binding of 
 : namespace prefixes.
 :
 : @param qname the QName to be normalized
 : @param nsmap a map representing the binding of namespace prefixes
 : @return the normalized QName
 :)
declare function f:normalizedQNameString(
                        $qname as xs:QName, 
                        $nsmap as element(zz:nsMap)?) 
        as xs:string {
    string(if (empty($nsmap)) then $qname else f:normalizeQName($qname, $nsmap))
};

(:~
 : Resolves a normalized QName, using the namespace map which had been used
 : for the normalization.
 :
 : @param name the name string to be resolved
 : @nsmap  a map associating namespace URIs with prefixes
 :)
declare function f:resolveNormalizedQName($name as xs:string?, $nsmap as element(zz:nsMap))
      as xs:QName? {
   if (empty($name)) then () else
   
   let $prefix := substring-before($name, ':')
   let $lname := if (string-length($prefix)) then substring-after($name, ':') 
                 else $name
   return
      QName($nsmap/*[@prefix eq $prefix]/@uri, $lname)                      
};

(:
   D E P R E C A T E D    F U N C T I O N S
:)

(:~
 : DEPRECATED - use 'addNSBs' instead.
 :
 : Adds namespace bindings to an element. The namespace bindings
 : are supplied as a namespace bindings map.
 :
 : @param elem the element
 : @param nsmap a map associating namespace prefixes with URIs
 : @return a copy of the element with namespace bindings added
:)
declare function f:addNSB($elem as element()?, $nsmap as element(zz:nsMap)) as element()? {
   <z:mp>{
      $nsmap/*[@prefix/string()]/attribute {QName(@uri, concat(@prefix, ':', '_'))} {}, $elem
   }</z:mp>/*
};

(:~
 : DEPRECATED - 'addNSB' instead.
 :
 : Adds an in-scope namespace to an element, if it does not already have it.
 : In the latter case, the element is returned unchanged. Special case: 
 : if the namespace URI of the in-scope namespace is empty, the element 
 : is returned with the default namespace removed, in order to allow 
 : referencing namespace-less elements from within the element. 
 :
 : Note: this function requires that copy namespaces modes contains 
 : 'inherited'.
 :
 : @param e the element to be modified
 : @param nsUri the namespace URI
 : @param prefix the prefix to be used
 :
 : @version: 20091212
 :)
declare function f:addInscopeNamespace($e as element()?,
                                       $nsUri as xs:string,
                                       $prefix as xs:string) 
                 as element()? {
   if ($nsUri eq "") then 
      <_tmp xmlns="">{$e}</_tmp>/*   (: remove default namespace :)
   else if ($nsUri eq namespace-uri-for-prefix($prefix, $e)) then      
      $e                             (: return unchanged :) 
   else                              
      element {QName($nsUri, string-join(($prefix[.], "_"), ":"))} 
	          {$e}/*                 (: add binding via transient wrapper :)                                        
};

(:~
 : Returns a modified Clark representation of a qualified name. 
 :)
declare function f:getClarkName($name as xs:QName, $useWellknownPrefixes as xs:boolean)
        as xs:string {
    let $uri := namespace-uri-from-QName($name)
    let $ln := local-name-from-QName($name)
    let $uriDesc :=
        if (not($uri)) then ()
        else if ($useWellknownPrefixes) then
            if ($uri eq 'http://www.w3.org/2001/XMLSchema') then 'xs:'
            else concat('{', $uri, '}')
        else            
            concat('{', $uri, '}')
    return
        concat($uriDesc, $ln)
};        
