(:
 : -------------------------------------------------------------------------
 :
 : componentReporter.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)

(:~@operations
   <operations>
      <operation name="elem" type="item()" func="reportElems">     
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="enames" type="nameFilter?"/>
         <param name="format" type="xs:string*" default="decl" fct_values="decl, name, report"/>         
         <param name="tnames" type="nameFilter?"/>         
         <param name="scope" type="xs:NCName" fct_values="root, global, local, all" default="all"/>
         <param name="skipAnno" type="xs:boolean?" default="true"/>
         <param name="addUri" type="xs:boolean?" default="false"/>         
         <param name="addFname" type="xs:boolean?" default="false"/>         
         <param name="paths" type="xs:boolean?" default="false"/>         
         <param name="maxPathLevel" type="xs:integer?"/>         
         <pgroup name="in" minOccurs="1"/>
      </operation>
      <operation name="att" type="item()" func="reportAtts">     
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="anames" type="nameFilter?"/>
         <param name="format" type="xs:string*" default="decl" fct_values="decl, name, report"/>         
         <param name="tnames" type="nameFilter?"/>         
         <param name="scope" type="xs:NCName" fct_values="global, local, all" default="all"/>
         <param name="skipAnno" type="xs:boolean?" default="true"/>
         <param name="addUri" type="xs:boolean?" default="false"/>         
         <param name="addFname" type="xs:boolean?" default="false"/>         
         <param name="paths" type="xs:boolean?" default="false"/>         
         <param name="maxPathLevel" type="xs:integer?"/>         
         <pgroup name="in" minOccurs="1"/>
      </operation>
      <operation name="type" type="item()" func="reportTypes">     
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="enames" type="nameFilter?"/>
         <param name="tnames" type="nameFilter?"/> 
         <param name="rgnames" type="nameFilter?"/>         
         <param name="scope" type="xs:NCName" fct_values="global, local, all" default="all"/>
         <param name="skipAnno" type="xs:boolean?" default="true"/>
         <param name="addUri" type="xs:boolean?" default="false"/>         
         <param name="addFname" type="xs:boolean?" default="false"/>         
         <pgroup name="in" minOccurs="1"/>
      </operation>
      <operation name="group" type="item()" func="reportGroups">     
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="gnames" type="nameFilter?"/>        
         <param name="rgnames" type="nameFilter?"/>         
         <param name="skipAnno" type="xs:boolean?" default="true"/>
         <param name="addUri" type="xs:boolean?" default="false"/>         
         <param name="addFname" type="xs:boolean?" default="false"/>         
         <param name="noref" type="xs:boolean?" default="false"/>         
         <param name="format" type="xs:string?" default="decl" fct_values="decl, name"/>         
         <pgroup name="in" minOccurs="1"/>
      </operation>
      <operation name="agroup" type="item()" func="reportAttGroups">     
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="hnames" type="nameFilter?"/>        
         <param name="skipAnno" type="xs:boolean?" default="true"/>
         <param name="addUri" type="xs:boolean?" default="false"/>         
         <param name="addFname" type="xs:boolean?" default="false"/>         
         <param name="noref" type="xs:boolean?" default="false"/>         
         <param name="format" type="xs:string?" default="name" fct_values="decl, name"/>         
         <pgroup name="in" minOccurs="1"/>
      </operation>
    </operations>  
:)  

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at
    "componentLocator.xqm",
    "componentManager.xqm",
    "componentNavigator.xqm",
    "componentPath.xqm",
    "schemaLoader.xqm",
    "util.xqm";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_errorAssistent.xqm";    
    
declare namespace z="http://www.xsdplus.org/ns/structure";

declare variable $f:NEW_PATH_FUNCTION := 1;

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)
declare function f:reportElems($request as element())
        as element() {
    let $schemas as element(xs:schema)* := app:getSchemas($request)        
    let $skipAnno := tt:getParams($request, 'skipAnno')    
    let $fname := tt:getParam($request, 'addFname')
    let $uri := tt:getParam($request, 'addUri')
    let $format := tt:getParams($request, 'format')    
    let $maxPathLevel := tt:getParams($request, 'maxPathLevel')    
    
    let $paths := tt:getParam($request, 'paths')    
    (: retrieve element declarations :)
    let $comps := f:getElems($request, $schemas)
    
    (: write their representations :)   
    let $comps :=
        if ($format eq 'report') then f:_getElemReport($comps, $request, $schemas) else
        
        (: case: without path info :)
        if (not($paths)) then 
            for $comp in $comps
            let $name := $comp/(@name, @ref)            
            order by lower-case($name)
            return 
                <z:elem name="{$name}">{
                    if (not($fname)) then () else attribute xsd {app:getDocumentName($comp)},
                    if (not($uri)) then () else attribute uri {f:getDocumentUri($comp)},                    
                    if ($format eq 'name') then () else $comp/app:editComponent(., $skipAnno, (), ())
                }</z:elem>
        (: case: with path info :)                
        else        
            let $maxPathCount := ()
            for $comp in $comps
            let $name := $comp/(@name, @ref)            
            let $paths := 
                if ($f:NEW_PATH_FUNCTION) then app:dgetItemPaths($comp, $maxPathLevel, $maxPathCount, $schemas)
                else app:egetElemPaths($comp, $maxPathLevel, $maxPathCount, $schemas)
            order by lower-case($name)                
            return
                <z:elem name="{$name}">{
                    if (not($fname)) then () else attribute xsd {app:getDocumentName($comp)},    
                    if (not($uri)) then () else attribute uri {f:getDocumentUri($comp)},                
                    <z:paths count="{count($paths)}">{for $path in $paths return <z:path p="{$path}"/>}</z:paths>,
                    if ($format eq 'name') then () else $comp/app:editComponent(., $skipAnno, (), ())
                }</z:elem>
    return
        <z:elems xmlns:xs="http://www.w3.org/2001/XMLSchema" countElems="{count($comps)}">{
            $comps
        }</z:elems>
};        

(:~
 : Returns attribute declarations, optionally filtered, enhanced by additional
 : information and stripped from annotations.
 :)
declare function f:reportAtts($request as element())
        as element() {
    let $schemas as element(xs:schema)* := app:getSchemas($request)        
    let $skipAnno := tt:getParams($request, 'skipAnno')    
    let $fname := tt:getParams($request, 'addFname')
    let $uri := tt:getParam($request, 'addUri')
    let $format := tt:getParams($request, 'format')
    let $maxPathLevel := tt:getParams($request, 'maxPathLevel')    
    let $paths := 
        if (exists($maxPathLevel)) then true()
        else tt:getParam($request, 'paths')    
    
    (: retrieve attribute declarations :)
    let $comps := f:getAtts($request, $schemas)
    
    (: write their representations :)
    let $comps :=
        if ($format eq 'report') then f:_getAttReport($comps, $request, $schemas) else
        
        (: case: without path info :)
        if (not($paths)) then 
            for $comp in $comps 
            return 
                <z:att name="{$comp/(@name, @ref)}">{
                    if (not($fname)) then () else attribute xsd {app:getDocumentName($comp)},
                    if (not($uri)) then () else attribute uri {f:getDocumentUri($comp)},             
                    if ($format eq 'name') then () else $comp/app:editComponent(., $skipAnno, (), ())                    
                }</z:att> 
        (: case: with path info :)                
        else        
            let $maxPathCount := ()
            for $comp in $comps
            let $paths := app:dgetItemPaths($comp, $maxPathLevel, $maxPathCount, $schemas)
            return
                <z:att name="{$comp/(@name, @ref)}">{
                    if (not($fname)) then () else attribute xsd {app:getDocumentName($comp)},
                    if (not($uri)) then () else attribute uri {f:getDocumentUri($comp)},                    
                    <z:paths count="{count($paths)}">{for $path in $paths return <z:path p="{$path}"/>}</z:paths>,
                    if ($format eq 'name') then () else $comp/app:editComponent(., $skipAnno, (), ())                    
                }</z:att>
    return
        <z:atts xmlns:xs="http://www.w3.org/2001/XMLSchema" countAtts="{count($comps)}">{
            $comps
        }</z:atts>
};        

declare function f:reportTypes($request as element())
        as element() {
    let $schemas as element(xs:schema)* := app:getSchemas($request)
    let $skipAnno := trace(tt:getParams($request, 'skipAnno') , 'SKIP_ANNO: ')
    let $fname := trace(tt:getParams($request, 'addFname') , 'FNAME: ')
    let $uri := trace(tt:getParam($request, 'addUri') , 'URI: ')
    
    let $comps := f:getTypes($request, $schemas)
    let $comps := $comps/app:editComponent(., $skipAnno, $fname, $uri)        
    return
        <z:types xmlns:xs="http://www.w3.org/2001/XMLSchema">{
            $comps
        }</z:types>
};        

declare function f:reportGroups($request as element())
        as element() {
    let $format := tt:getParam($request, 'format')    
    let $schemas as element(xs:schema)* := app:getSchemas($request)    
    let $comps := f:getGroups($request, $schemas)
    let $comps := $comps/app:editComponent(., $request) => sort((), function($g) {$g/@name})
    let $compsReport :=
        if ($format eq 'name') then $comps ! <group name="{@name}"/>
        else $comps
    return
        <z:groups xmlns:xs="http://www.w3.org/2001/XMLSchema">{
            $compsReport
        }</z:groups>
};        

declare function f:reportAttGroups($request as element())
        as element() {
    let $format := tt:getParam($request, 'format')        
    let $schemas as element(xs:schema)* := app:getSchemas($request)   
    let $comps := f:getAttGroups($request, $schemas)
    let $comps := $comps/app:editComponent(., $request)        
    let $compsReport :=
        if ($format eq 'name') then $comps ! <group name="{@name}"/>
        else $comps
    return
        <z:attGroups xmlns:xs="http://www.w3.org/2001/XMLSchema">{
            $compsReport
        }</z:attGroups>
};        

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Search element declarations, optionally filtered by name, xsd name and scope.
 :)
declare function f:getElems($request as element(), $schemas as element(xs:schema)+)
        as element()* {       
    let $enames as element(nameFilter)? := tt:getParam($request, 'enames')
    let $tnames as element(nameFilter)? := tt:getParam($request, 'tnames')    
    let $schemaNameFilter as element(nameFilter)? := tt:getParam($request, 'xnames')    
    let $scope := tt:getParam($request, 'scope')
    
    let $useSchemas :=
        if (not($schemaNameFilter)) then $schemas else
            $schemas
                [let $xname := app:getDocumentUri(.) 
                 let $xname := replace($xname, '.*[/\\]', '') (: extract file name, without path :)
                 return not($xname) or tt:matchesNameFilter($xname, $schemaNameFilter)]
    
    (: filter by scope :)    
    let $comps :=
        if ($scope = ('root', 'global')) then
            let $compsGlobal := $useSchemas/xs:element
            return
                if ($scope eq 'global') then $compsGlobal
                else (: scope = 'root' => global and not referenced :)
                    for $e in $compsGlobal
                    let $ename := app:getComponentName($e)
                    where not($schemas//xs:element/@ref[resolve-QName(., ..) eq $ename])
                    return $e
        else if ($scope eq 'local') then $schemas/*//xs:element
        else $schemas//xs:element
        
   (: filter by name :)
    let $comps :=
        if (not($enames)) then $comps else
            let $allNames := distinct-values($comps/@name/string())
            let $selNames := tt:filterNames($allNames, $enames)
            return
                $comps[@name = $selNames or @ref = $selNames]
   (: filter by type :)
    let $comps :=
        if (not($tnames)) then $comps else
            $comps[tt:matchesNameFilter(replace(@type, '^.+:', ''), $tnames)]
            
    return
        $comps
};

(:~
 : Search attribute declarations, optionally filtered by name, xsd name and scope.
 :)
declare function f:getAtts($request as element(), $schemas as element(xs:schema)+)
        as element()* {       
    let $anames as element(nameFilter)? := tt:getParam($request, 'anames')
    let $tnames as element(nameFilter)? := tt:getParam($request, 'tnames')    
    let $schemaNameFilter as element(nameFilter)? := tt:getParam($request, 'xnames')    
    let $scope := tt:getParam($request, 'scope')
    
    let $useSchemas :=
        if (not($schemaNameFilter)) then $schemas else
            $schemas
                [let $xname := app:getDocumentUri(.) 
                 let $xname := replace($xname, '.*[/\\]', '') (: extract file name, without path :)
                 return not($xname) or tt:matchesNameFilter($xname, $schemaNameFilter)]
   
    (: filter by scope :)
    let $comps :=
        if ($scope = ('root', 'global')) then $useSchemas/xs:attribute
        else if ($scope eq 'local') then $schemas/*//xs:attribute
        else $schemas//xs:attribute
        
   (: filter by name :)
    let $comps :=
        if (not($anames)) then $comps else
            let $allNames := distinct-values($comps/@name/string())
            let $selNames := tt:filterNames($allNames, $anames)
            return
                $comps[@name = $selNames or @ref = $selNames]
                
   (: filter by type :)
    let $comps :=
        if (not($tnames)) then $comps else
            $comps[tt:matchesNameFilter(replace(@type, '^.+:', ''), $tnames)]                
    return
        $comps
};

(:~
 : Search type definitions, xs:simpleType and xs:complexType.
 :)
declare function f:getTypes($request as element(), $schemas as element(xs:schema)+)
        as element()* {       
    let $tnames as element(nameFilter)? := tt:getParam($request, 'tnames')
    let $rgnames as element(nameFilter)? := tt:getParam($request, 'rgnames')    
    let $schemaNameFilter as element(nameFilter)? := tt:getParam($request, 'xnames')    
    let $scope := tt:getParam($request, 'scope')
    
    let $useSchemas :=
        if (not($schemaNameFilter)) then $schemas else
            $schemas
                [let $xname := app:getDocumentUri(.) 
                 return not($xname) or tt:matchesNameFilter($xname, $schemaNameFilter)]
    
    let $comps :=
        if ($scope = 'global') then $useSchemas/(xs:simpleType, xs:complexType)
        else if ($scope = 'local') then $useSchemas/*//(xs:simpleType, xs:complexType)
        else $useSchemas//(xs:simpleType, xs:complexType)
        
   (: select by name :)
    let $comps :=
        if (not($tnames)) then $comps else
            let $allNames := distinct-values($comps/@name/string())
            let $selNames := tt:filterNames($allNames, $tnames)
            return
                $comps[@name = $selNames]
                
    (: select by rgroups 
       only types directly referencing particular groups are selected :)
       
    let $comps := 
        if (not($rgnames)) then $comps 
        else $comps[.//xs:group/@ref[tt:matchesNameFilter(., $rgnames)]]
    
    return
        $comps
};

(:~
 : Retrieve xs:group definitions.
 :
 : Supported filters:
 : - group names (name filter)
 : - schema names
 : - noref - only dangling groups to which no @ref points are selected
 :)
declare function f:getGroups($request as element(), $schemas as element(xs:schema)+)
        as element()* {       
    let $gnames as element(nameFilter)? := tt:getParam($request, 'gnames')
    let $rgnames as element(nameFilter)? := tt:getParam($request, 'rgnames')    
    let $schemaNameFilter as element(nameFilter)? := tt:getParam($request, 'xnames')    
    let $noref as xs:boolean? := tt:getParam($request, 'noref')    
    
    let $useSchemas :=
        if (not($schemaNameFilter)) then $schemas else
            $schemas
                [let $xname := app:getDocumentUri(.) 
                 return not($xname) or tt:matchesNameFilter($xname, $schemaNameFilter)]
    
    let $comps := $useSchemas/xs:group[@name]
        
    (: select by name :)
    let $comps := 
        if (not($gnames)) then $comps 
        else $comps[tt:matchesNameFilter(@name, $gnames)]
    
    (: select by rgroups 
       only groups directly referencing particular other groups are selected :)
    let $comps := 
        if (not($rgnames)) then $comps 
        else $comps[.//xs:group/@ref[tt:matchesNameFilter(., $rgnames)]]
    
    (: select noref 
       only "dangling" groups without any @ref pointing to them are selected :)       
    let $comps :=
        if (not($noref)) then $comps
        else 
            for $comp in $comps
            let $qname := $comp/QName(ancestor::xs:schema/@targetNamespace, @name)
            let $refs := $schemas//xs:group/@ref[resolve-QName(., ..) eq $qname]
            where not($refs)
            return $comp
            
    (: return final filtering result :)
    return
        $comps
};

(:~
 : Search attribute group components.
 :)
declare function f:getAttGroups($request as element(), $schemas as element(xs:schema)+)
        as element()* {       
    let $hnames as element(nameFilter)? := tt:getParam($request, 'hnames')
    let $schemaNameFilter as element(nameFilter)? := tt:getParam($request, 'xnames')    
    let $noref as xs:boolean? := tt:getParam($request, 'noref')
    
    let $useSchemas :=
        if (not($schemaNameFilter)) then $schemas else
            $schemas
                [let $xname := app:getDocumentUri(.) 
                 return not($xname) or tt:matchesNameFilter($xname, $schemaNameFilter)]
    
    let $comps := $useSchemas/xs:attributeGroup[@name]
        
   (: select by name :)
    let $comps := if (not($hnames)) then $comps else $comps[tt:matchesNameFilter(@name, $hnames)]

    (: select noref 
       only "dangling" attribute groups without any @ref pointing to them are selected :)       
    let $comps :=
        if (not($noref)) then $comps
        else 
            for $comp in $comps
            let $qname := $comp/QName(ancestor::xs:schema/@targetNamespace, @name)
            let $refs := $schemas//xs:attributeGroup/@ref[resolve-QName(., ..) eq $qname]
            where not($refs)
            return $comp

    (: return final filtering result :)
    return
        $comps
};

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)


declare function f:_getAttReport($comps as element(xs:attribute)*, $request as element(), $schemas as element(xs:schema)+)
        as element()* {
    let $nsmap := trace( app:getTnsPrefixMap($schemas), 'NSMAP: ')
    for $comp in $comps   
    group by $qname := app:getComponentName($comp)
    let $lname := local-name-from-QName($qname)
    let $ns := namespace-uri-from-QName($qname)
    
    let $defaultValues :=   
        let $defaults :=
            let $withoutDefault := $comp[not(@default)]
            let $withDefault := $comp[@default]
            return
                if (not($withDefault)) then attribute default {'none'}
                else
                    for $c in $comp
                    group by $default := $c/@default
                    return
                        if (not($default)) then
                            <z:nodefault count="{count($c)}">{
                                for $item in $c 
                                let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)
                                return
                                    <z:loc value="{$loc}" check="{app:resolveComponentLocator($loc, $nsmap[1], $schemas) is $item}"/>
                            }</z:nodefault>
                        else
                            <z:default value="{$default}" count="{count($c)}">{                           
                                for $item in $c return
                                let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)
                                return
                                    <z:loc value="{$loc}" check="{app:resolveComponentLocator($loc, $nsmap[1], $schemas) is $item}"/>
                            }</z:default>
    return
        <z:defaults countWith="{count($comp[@default])}" countWithout="{count($comp[not(@default)])}">{
            $defaults
        }</z:defaults>

    let $types :=   
        let $local := $comp[xs:simpleType]
        let $global := $comp[@type]            
        let $ref := $comp[@ref]            
        let $none := $comps except ($local, $global, $ref)
        let $typeGroups := (
            if (not($local)) then <z:local/>
            else
                <z:local count="{count($local)}">{
                    for $item in $local
                    let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)                    
                    return
                        <z:loc value="{$loc}"/>
                }</z:local>,
            if (not($global)) then <z:global/>
            else
                let $typeDefs :=
                    for $item in $global
                    group by $qname := resolve-QName($item/@type, $item)
                    let $lname := local-name-from-QName($qname)
                    let $ns := namespace-uri-from-QName($qname)                        
                    return
                        <z:type name="{$lname}" namespace="{$ns}">{
                            for $instance in $item 
                            let $loc := app:getComponentLocator($instance, $nsmap[1], $schemas)
                            return
                                <z:loc value="{$loc}"/>
                        }</z:type>
                return                            
                    <z:global countGlobalTypes="{count($typeDefs)}" countTypes="{count($typeDefs)}">{
                        $typeDefs
                    }</z:global>,
            if (not($ref)) then <z:ref/>
            else
                <z:ref count="{count($ref)}">{
                    for $item in $ref
                    group by $qname := resolve-QName($item/@ref, $item)
                    let $lname := local-name-from-QName($qname)
                    let $ns := namespace-uri-from-QName($qname)                        
                    return
                        <z:refAtt name="{$lname}" namespace="{$ns}">{
                            for $instance in $item
                            let $loc := app:getComponentLocator($instance, $nsmap[1], $schemas)                            
                            return
                                <z:loc value="{$loc}"/>
                        }</z:refAtt>
                }</z:ref>,
            if (not($none)) then <z:none/>
            else
                <z:none count="{count($local)}">{
                    for $item in $none 
                    let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)
                    return
                        <z:loc value="{$loc}"/>
                }</z:none>
        )
        return
            <z:types countGlobalTypes="{$typeGroups/self::z:global/@countGlobalTypes}" countLocal="{count($local)}" countGlobal="{count($global)}" countRef="{count($ref)}" countNone="{count($none)}">{
                $typeGroups
            }</z:types>
            
    let $atts := ($defaultValues, $types)[self::attribute()] 
    let $elems := ($defaultValues, $types)[self::element()]    
    return
        <z:att name="{$lname}" namespace="{$ns}" count="{count($comp)}">{
            $atts,
            $elems
        }</z:att>
};        

declare function f:_getElemReport($comps as element(xs:element)*, $request as element(), $schemas as element(xs:schema)+)
        as element()* {
    let $nsmap := trace( app:getTnsPrefixMap($schemas), 'NSMAP: ')
    for $comp in $comps   
    group by $qname := app:getComponentName($comp)
    let $lname := local-name-from-QName($qname)
    let $ns := namespace-uri-from-QName($qname)
    
    let $defaultValues :=   
        let $defaults :=
            let $withoutDefault := $comp[not(@default)]
            let $withDefault := $comp[@default]
            return
                if (not($withDefault)) then attribute default {'none'}
                else
                    for $c in $comp
                    group by $default := $c/@default
                    return
                        if (not($default)) then
                            <z:nodefault count="{count($c)}">{
                                for $item in $c 
                                let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)
                                return
                                    <z:loc value="{$loc}" check="{app:resolveComponentLocator($loc, $nsmap[1], $schemas) is $item}"/>
                            }</z:nodefault>
                        else
                            <z:default value="{$default}" count="{count($c)}">{                           
                                for $item in $c return
                                let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)
                                return
                                    <z:loc value="{$loc}" check="{app:resolveComponentLocator($loc, $nsmap[1], $schemas) is $item}"/>
                            }</z:default>
    return
        <z:defaults countWith="{count($comp[@default])}" countWithout="{count($comp[not(@default)])}">{
            $defaults
        }</z:defaults>

    let $types :=   
        let $local := $comp[xs:complexType, xs:simpleType]
        let $global := $comp[@type]            
        let $ref := $comp[@ref]            
        let $none := $comps except ($local, $global, $ref)
        let $typeGroups := (
            if (not($local)) then <z:local/>
            else
                <z:local count="{count($local)}">{
                    for $item in $local return
                    let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)
                    return                    
                        <z:loc value="{$loc}" check="{app:resolveComponentLocator($loc, $nsmap[1], $schemas) is $item}"/>
                }</z:local>,
            if (not($global)) then <z:global/>
            else
                let $typeDefs :=
                    for $item in $global
                    group by $qname := resolve-QName($item/@type, $item)
                    let $lname := local-name-from-QName($qname)
                    let $ns := namespace-uri-from-QName($qname)                        
                    return
                        <z:type name="{$lname}" namespace="{$ns}">{
                            for $instance in $item return
                            let $loc := app:getComponentLocator($instance, $nsmap[1], $schemas)
                            return                            
                                <z:loc value="{$loc}" check="{app:resolveComponentLocator($loc, $nsmap[1], $schemas) is $instance}"/>
                        }</z:type>
                return                            
                    <z:global countGlobalTypes="{count($typeDefs)}" countTypes="{count($typeDefs)}">{
                        $typeDefs
                    }</z:global>,
            if (not($ref)) then <z:ref/>
            else
                <z:ref count="{count($ref)}">{
                    for $item in $ref
                    group by $qname := resolve-QName($item/@ref, $item)
                    let $lname := local-name-from-QName($qname)
                    let $ns := namespace-uri-from-QName($qname)                        
                    return
                        <z:refAtt name="{$lname}" namespace="{$ns}">{
                            for $instance in $item
                            let $loc := app:getComponentLocator($instance, $nsmap[1], $schemas)                            
                            return
                                <z:loc value="{$loc}"/>
                        }</z:refAtt>
                }</z:ref>,
            if (not($none)) then <z:none/>
            else
                <z:none count="{count($local)}">{
                    for $item in $none
                    let $loc := app:getComponentLocator($item, $nsmap[1], $schemas)                    
                    return
                        <z:loc value="{$loc}"/>
                }</z:none>
        )
        return
            <z:types countGlobalTypes="{$typeGroups/self::z:global/@countGlobalTypes}" countLocal="{count($local)}" countGlobal="{count($global)}" countRef="{count($ref)}" countNone="{count($none)}">{
                $typeGroups
            }</z:types>
            
    let $atts := ($defaultValues, $types)[self::attribute()] 
    let $elems := ($defaultValues, $types)[self::element()]    
    return
        <z:elem name="{$lname}" namespace="{$ns}" count="{count($comp)}">{
            $atts,
            $elems
        }</z:elem>
};        
