(:
 : -------------------------------------------------------------------------
 :
 : factTreeUtilities.xqm - utilities supporting the creating of fact trees
 :
 : -------------------------------------------------------------------------
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
declare namespace zz="http://www.ttools.org/structure";
declare namespace ns0="http://www.xsdr.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Merges an observation tree into a location tree.
 :
 : @param ltree a location tree
 : @param otree an observation tree
 : @param ltreeAttNames the names of location tree attributes to be preserved
 : @param otreeAttNamesMap a map with keys providing the names of observation 
 :     tree attributes to be merged into the location tree, and values 
 :     providing default values; default values can be specified as atomic 
 :     item, or as a function item, consuming the location tree node and 
 :     returning the default value to be used
 : @param options options (not yet used)
 : @return the merged tree obtained by adding attributes from the
 :     observation tree to the location tree
 :) 
declare function f:mergeOtreeIntoLtree($ltree as element(),
                                       $otree as element(),
                                       $ltreeAttNames as xs:QName*,
                                       $otreeAttNamesMap as map(xs:QName, item()?),                                       
                                       $options as element(options)?)
        as element() {
    let $nsmap := $ltree/zz:nsMap
    let $otreePathMap := f:otreePathMap($otree, $nsmap)
    return f:mergeOtreeIntoLtreeRC
        ($ltree, $otreePathMap, $ltreeAttNames, $otreeAttNamesMap, $options)            
};

                                       
(:~
 : Implements operation `vtree`.
 :
 : @param a location tree node
 : @param otreePathMap a map associating observation paths with observation nodes
 : @param ltreeAttNames the names of location tree attributes to be preserved
 : @param otreeAttNamesMap a map with keys providing the names of observation 
 :     tree attributes to be merged into the location tree, and values 
 :     providing default values; default values can be specified as atomic 
 :     item, or as a function item, consuming the location tree node and 
 :     returning the default value to be used
 : @param options options (not yet used)
 : @return the merged tree obtained by adding attributes from the
 :     observation tree to the location tree
 :) 
declare function f:mergeOtreeIntoLtreeRC($n as node(),
                                         $otreePathMap as map(xs:string, element()),
                                         $ltreeAttNames as xs:QName*,
                                         $otreeAttNamesMap as map(xs:QName, item()?),
                                         $options as element(options)?)
        as element()? {
    typeswitch($n)
    
    case element(z:locationTree) return
        <z:locationTree>{
            $n/@*,
            for $c in $n/node() return f:mergeOtreeIntoLtreeRC
                ($c, $otreePathMap, $ltreeAttNames, $otreeAttNamesMap, $options)            
        }</z:locationTree>
        
    case element(z:_stypeTree_) return ()
    case element(zz:nsMap) return ()
    
    case element(z:_sequence_) | element(z:_choice_) | element(z:_all_) return
        element {node-name($n)} {
            $n/@z:occ,
            for $c in $n/node() return f:mergeOtreeIntoLtreeRC            
                ($c, $otreePathMap, $ltreeAttNames, $otreeAttNamesMap, $options)
        }

    case element(z:_attributes_) return 
        <z:_attributes_>{
            for $c in $n/node() return f:mergeOtreeIntoLtreeRC            
                ($c, $otreePathMap, $ltreeAttNames, $otreeAttNamesMap, $options)
        }</z:_attributes_>                
        
    case element() return
        let $lpath := f:lpath($n)
        let $otreeNode := $otreePathMap($lpath)
        let $obversationAtts := 
            if ($n/self::z:*) then () else
            
            let $attNames := map:keys($otreeAttNamesMap)
            for $attName in $attNames
            let $att := $otreeNode/@*[node-name(.) = $attName]
            return
                if ($att) then $att
                else
                    let $default := $otreeAttNamesMap($attName)
                    return
                        if (empty($default)) then () 
                        else
                            let $attValue := 
                                if ($default instance of function(node()) as item())
                                    then $default($n)
                                else $default
                            return attribute {$attName} {$attValue}
        return
            element {node-name($n)} {
                $n/@*[node-name(.) = $ltreeAttNames],
                $obversationAtts,
                for $c in $n/node() return f:mergeOtreeIntoLtreeRC
                    ($c, $otreePathMap, $ltreeAttNames, $otreeAttNamesMap, $options)
        }
    default return $n        
};

(:~
 : Transforms an observation tree into a map associating
 : instance item data paths with the relevant observation tree node.
 :
 : @param otree an observation tree
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @return a map associating observation paths with observation nodes
 :)
declare function f:otreePathMap($otree as element(), $nsmap as element(zz:nsMap))
        as map(xs:string, element()) {
    let $ot := f:normalizeNamespaces($otree, $nsmap) 
    return
        map:merge(
            f:otreePathMapRC($ot, $ot)
        )
};

(:~
 : Recursive helper function of function `otreePathMap`.
 :
 : @param n an element node from an observation tree
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @return map entries describing the input node and its descendants
 :)
declare function f:otreePathMapRC($n as element(), $otree as element())
        as map(xs:string, element())* {
    let $opath := f:otreePath($n, $otree)
    let $nextNodes := $n/((* except z:_attributes_), z:_attributes_/*)
    return (
        map:entry($opath, $n),
        for $node in $nextNodes return f:otreePathMapRC($node, $otree)
    )        
};

(:~
 : Transforms a node and its descendants recursively, normalizing the use
 : of name prefixes.
 :
 : Precondition: the normalized namespace bindings must include all namespaces 
 : occurring in the input node, its descendants and the attributes of these nodes.
 :
 : @param n a node to be transformed
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @return a copy of the node with all node names using normalized prefixes
 :)
declare function f:normalizeNamespaces($n as node(), $nsmap as element(zz:nsMap))
        as node()? {
    typeswitch($n)
    case document-node() return
        document {for $c in $n/node() return f:normalizeNamespaces($c, $nsmap)}
    case element() return
        let $name := node-name($n)
        let $uri := namespace-uri($n)
        let $nname :=
            if (not($uri)) then $name
            else
                let $nprefix := $nsmap/*[@uri eq $uri]/@prefix/string()
                return
                    if (not($nprefix)) then
                        error(QName((), 'INVALID_INPUT'), concat('Namespace ',
                            'not included in the normalized namespace bindings: ',
                            $uri))
                    else if ($nprefix eq prefix-from-QName($name)) then $name
                    else QName($uri, concat($nprefix, ':', local-name-from-QName($name)))
        return
            element {$nname} {
                for $a in $n/@* return f:normalizeNamespaces($a, $nsmap),
                for $c in $n/node() return f:normalizeNamespaces($c, $nsmap)
            }
    default return $n            
};      

(:~
 : Returns the data path of instance document items modelled by an 
 : element node from an observation tree.
 :
 : Note #1. The path steps consist of lexical node names as encountered 
 : in the observation tree. If the path returned by this function must
 : be compared with data paths obtained from a location tree, the
 : observation tree should be namespace normalized prior to caling
 : this function, in accordance to the location tree in question.
 : Consider using function `normalizeNamespaces` for performing
 : such normalization.
 :
 : Note #2. The data path does not include item indexes (like '[2]').
 :
 : @param e element node from an observation tree
 : @param otreeRoot the root element of the observation tree
 : @return the data path of instance document items
 :)
declare function f:otreePath($e as element(), $otreeRoot as element()) as xs:string {
  '/'||string-join((
       $e/ancestor::*[not(self::z:*)][not(. << $otreeRoot)]/name(),
       $e/concat(parent::z:_attributes_/'@', name())), '/')
};

(:~
 : Returns the lpath (location path) of a location element. The lpath
 : captures the data path of the instance nodes modelled by the location.
 :
 : Note #1. The path steps consist of lexical node names as encountered 
 : in the location tree. Note that lexical node names used by a location
 : tree are namespace normalized in accordance with the `nsmap` contained
 : by the location tree.
 :
 : Note #2. The data path does not include item indexes (like '[2]').
 :
 : @param e element node from an observation tree
 : @param otreeRoot the root element of the observation tree
 : @return the data path of instance document items
 :)
declare function f:lpath($e as element()) as xs:string {
  '/'||string-join((
       $e/ancestor::*[not(self::z:*)]/name(),
       $e/concat(parent::z:_attributes_/'@', name())), '/')
};

(:~
 : Creates an observation tree. An observation tree is the result of
 : evaluating a sequence of XML elements, which belong to one or
 : more documents. The tree represents each data path observed within 
 : the evaluated elements by an element whose data path within the
 : observation tree corresponds to the data path of the observed
 : nodes: if the data path points to an element, the data paths of
 : observed elements and of the observation element are identical;
 : if the data path points to an attribute, the data paths of the
 : observed attributes is equal to the data path of the observation
 : node, after replacing within the latter the string '/z:_attributes/'
 : by '/@'.
 :
 : @param n a set of nodes with equal name and appearing in equivalent locations
 : @param docs the documents whose content frequencies are reported
 : @param count the number of documents currently reported
 : @return a counts tree fragment representing the given nodes $n
 :)
declare function f:observationTree($rootElems as node()+, 
                                   $docs as element()*,
                                   $functionObserveAtts as function(attribute()*, element()*) as node()*,
                                   $functionObserveElems as function(element()*, element()*) as node()*)
        as node()? {
    f:observationTreeRC($rootElems, $docs, $functionObserveAtts, $functionObserveElems)        
};

(:~
 : Recursive helper function of 'observationTree'.
 :
 : @param n a set of nodes with equal name and appearing in equivalent locations
 : @param docs the documents whose content frequencies are reported
 : @param count the number of documents currently reported
 : @return a counts tree fragment representing the given nodes $n
 :)
declare function f:observationTreeRC($n as node()+, 
                                     $docs as element()*,
                                     $functionObserveAtts as function(attribute()*, element()*) as node()*,
                                     $functionObserveElems as function(element()*, element()*) as node()*)
        as node()? {
    let $atts :=
        for $att in $n/@*
        group by $aname := local-name($att)
        order by $aname
        return 
            element {$aname} {
                $functionObserveAtts($att, $docs)            
            }
    let $content :=
        for $child in $n/*
        let $name := local-name($child)
        group by $name
        order by $name
        return 
            f:observationTreeRC($child, $docs, $functionObserveAtts, $functionObserveElems)
    return 
        element {node-name($n[1])} {
            $functionObserveElems($n, $docs),
            if (empty($atts)) then () else
            <z:_attributes_ xmlns="">{$atts}</z:_attributes_>,
            $content
        }
};


