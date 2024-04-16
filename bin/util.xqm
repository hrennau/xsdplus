(:
 : -------------------------------------------------------------------------
 :
 : util.xqm - miscellaneous utility functions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at
    "constants.xqm",
    "schemaLoader.xqm",
    "treeNavigator.xqm";
    
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_namespaceTools.xqm";    

declare namespace z="http://www.xsdplus.org/ns/structure";

(:~
 : Returns schema components (element declarations, type definitions, group 
 : definitions, attribute group definitions) matching name filters.
 :
 : @param enames a name filter for element declarations
 : @param tnames a name filter for type definitions 
 : @param gnames a name filter for group definitions
 : @param hnames a name filter for attribute group definitions
 : @param global only top-level element declarations are considered 
 : @return schema components matching the component type specific name filter 
 :)
declare function f:getComponents($enames as element(nameFilter)?,
                                 $anames as element(nameFilter)?,
                                 $tnames as element(nameFilter)?,
                                 $gnames as element(nameFilter)?,
                                 $hnames as element(nameFilter)?,                                 
                                 $global as xs:boolean?,
                                 $schemas as element(xs:schema)+)
        as element()* {
    if (not($enames)) then () else (
        if ($global) then $schemas/xs:element
        else $schemas/descendant::xs:element
        )[tt:matchesNameFilter(@name, $enames)],
    if (not($anames)) then () else (
        if ($global) then $schemas/xs:attribute
        else $schemas/descendant::xs:attribute
        )[tt:matchesNameFilter(@name, $anames)],
    if (not($tnames)) then () else 
        $schemas/(xs:simpleType, xs:complexType)
        [tt:matchesNameFilter(@name, $tnames)],
    if (not($gnames)) then () else 
        $schemas/xs:group
        [tt:matchesNameFilter(@name, $gnames)],
    if (not($hnames)) then () else 
        $schemas/xs:attributeGroup
        [tt:matchesNameFilter(@name, $hnames)]
};

(:~
 : Returns schema components (element declarations, type definitions, group 
 : definitions, attribute group definitions) matching name filters.
 :
 : @param enames a name filter for element declarations
 : @param tnames a name filter for type definitions 
 : @param gnames a name filter for group definitions
 : @param hnames a name filter for attribute group definitions
 : @param ens a name filter for the namespace of element declarations 
 : @param tns a name filter for the namespace of type definitions 
 : @param gns a name filter for the namespace of group definitions 
 : @param hns a name filter for the namespace of attribute group definitions 
 : @param global only top-level element declarations are considered 
 : @return schema components matching the component type specific name filter 
 :)
declare function f:getComponents($enames as element(nameFilter)*,
                                 $tnames as element(nameFilter)*,
                                 $gnames as element(nameFilter)*,
                                 $hnames as element(nameFilter)*,
                                 $ens as element(nameFilter)*,
                                 $tns as element(nameFilter)*,
                                 $gns as element(nameFilter)*,
                                 $hns as element(nameFilter)*,
                                 $global as xs:boolean?,                                 
                                 $schemas as element(xs:schema)+)
        as element()* {
        
    let $enames := if (not($enames) and $ens) then '*' else $enames
    let $tnames := if (not($tnames) and $tns) then '*' else $tnames
    let $gnames := if (not($gnames) and $tns) then '*' else $gnames    
    let $hnames := if (not($hnames) and $tns) then '*' else $hnames    
    return if (empty(($enames, $tnames, $gnames, $hnames))) then $schemas/xs:element else (

    if (not($enames)) then () else 
        let $fschemas := if (not($ens)) then $schemas else $schemas[tt:matchesNameFilter(@targetNamespace, $ens)]
        return (
            if ($global) then $fschemas/xs:element 
            else $fschemas/descendant::xs:element)[tt:matchesNameFilter(@name, $enames)],
    if (not($tnames)) then () else
        let $fschemas := if (not($tns)) then $schemas else $schemas[tt:matchesNameFilter(@targetNamespace, $tns)]
        return $fschemas/(descendant::xs:simpleType, descendant::xs:complexType)[tt:matchesNameFilter(@name, $tnames)],
    if (not($gnames)) then () else 
        let $fschemas := if (not($gns)) then $schemas else $schemas[tt:matchesNameFilter(@targetNamespace, $gns)]
        return $fschemas/descendant::xs:group[tt:matchesNameFilter(@name, $gnames)],
    if (not($hnames)) then () else 
        let $fschemas := if (not($hns)) then $schemas else $schemas[tt:matchesNameFilter(@targetNamespace, $hns)]
        return $fschemas/descendant::xs:attributeGroup[tt:matchesNameFilter(@name, $gnames)]
    )
};

(:~
 : Handles the situation that duplicate instances of a component are
 : encountered where there must not be duplicates - for examples several
 : type definitions with the same qualified name. Dependent on the
 : configuration parameter app:TELERATE_COMPONENT_DUPLICATES, either
 : an error is thrown (value 0), the first instance is returned (value 1)
 : or the last instance is returned (value 2).
 :)
declare function f:resolveDuplicateComponents($duplicates as element()+)
        as element() {
    if ($app:TOLERATE_COMPONENT_DUPLICATES eq 0) then
        let $compName := $duplicates[1]/@name/string()
        let $compType := $duplicates[1]/local-name(.)
        return
            tt:createError("INVALID_XSD", 
               concat("schema component duplicate; type: ", $compType, "; name: ", $compName,
                      "; number of duplicates: ", count($duplicates)), ())               
    else if ($app:TOLERATE_COMPONENT_DUPLICATES eq 1) then $duplicates[1]
    else $duplicates[last()]
};

(:~
 : Transforms a component dependencies map into an element.
 : The map has keys 'types', 'groups', 'agroups', 'elems', 'atts'.
 : Their values are the QNames of components referenced directly 
 : or indirectly by the component described by the map.
 :)
declare function f:depsMap2Elem($deps as map(*))
        as element() {
    <deps>{
        let $types :=
            for $type in $deps?types
            let $lname := local-name-from-QName($type)
            let $uri := namespace-uri-from-QName($type)
            order by lower-case($lname), lower-case($uri)
            return
                <type name="{$lname}" namespace="{$uri}"/>
        return
            <types count="{count($types)}">{$types}</types>,
            
        let $groups :=            
            for $group in $deps?groups 
            let $lname := local-name-from-QName($group)
            let $uri := namespace-uri-from-QName($group)
            order by lower-case($lname), lower-case($uri)            
            return <group name="{$lname}" namespace="{$uri}"/>
        return
            <groups count="{count($groups)}">{$groups}</groups>,
            
        let $agroups :=
            for $agroup in $deps?agroups 
            let $lname := local-name-from-QName($agroup)
            let $uri := namespace-uri-from-QName($agroup)
            order by lower-case($lname), lower-case($uri)            
            return <agroup name="{$lname}" namespace="{$uri}"/> 
        return
            <agroups count="{count($agroups)}">{$agroups}</agroups>,

        let $elems :=
            for $elem in $deps?elems 
            let $lname := local-name-from-QName($elem)
            let $uri := namespace-uri-from-QName($elem)
            order by lower-case($lname), lower-case($uri)            
            return <elem name="{$lname}" namespace="{$uri}"/> 
        return
            <elems count="{count($elems)}">{$elems}</elems>,
            
        let $atts :=
            for $att in $deps?atts 
            let $lname := local-name-from-QName($att)
            let $uri := namespace-uri-from-QName($att)
            order by lower-case($lname), lower-case($uri)            
            return <att name="{$lname}" namespace="{$uri}"/> 
        return
            <atts count="{count($atts)}">{$atts}</atts>
            
    }</deps>            
};        

(:~
 : Normalizes a URI. Returns it without changes, unless the URI is
 : a file URI. In this case, reduces multiple slashes after 'file:' to
 : a single slash, puts drive letter lower-case and adds drive letter 'c' in
 : case the uri does not contain a drive letter.
 :
 : @param uri the uri to be normalized
 : @return the normalized uri
 :)
declare function f:normalizeUri($uri as xs:string) {
    if (not(matches($uri, '^\s*file:'))) then $uri else
    
    let $u := replace($uri, 'file:/+', 'file:/')
    let $driveLetter := replace($u, '^file:/(.):.+', '$1')[not(. eq $u)]
    return
        if ($driveLetter) then
            replace($u, '(file:/).(:.+)', concat('$1', lower-case($driveLetter), '$2'))
        else
            replace($u, '^(file:/)(.+)', '$1c:/$2') 
};

(:~
 : Returns a whitespace string producing indentation.
 :
 : @param level hierarchical level of the code line to be indented (>= 0)
 : @return an XQuery query
 :) 
declare function f:xq_indent($level as xs:integer)
      as xs:string {
   string-join(for $i in 1 to $level return '   ', '')
};

(:~
 : Removes pretty print text nodes, enabling fresh indentation.
 :)
declare function f:prettyNode($node as node())
        as node()? {
    typeswitch($node)
    case document-node() return
        document {$node/node() ! f:prettyNode(.)}
    case element() return
        element {node-name($node)} {
            $node/@* ! f:prettyNode(.),
            $node/node() ! f:prettyNode(.)
        }
    case text() return
        $node[not(../*) or matches(., '\S')]
    default return $node
};        




