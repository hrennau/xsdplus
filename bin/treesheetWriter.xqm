(:
 : -------------------------------------------------------------------------
 :
 : treesheetWriter.xqm - operation and public functions creating treesheets
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>   
      <operation name="treesheet" type="xs:string" func="treesheetOp">
         <param name="enames" type="nameFilter?" pgroup="comps"/> 
         <param name="tnames" type="nameFilter?" pgroup="comps"/>         
         <param name="gnames" type="nameFilter?" pgroup="comps"/>      
         <param name="ens" type="nameFilter?"/>
         <param name="tns" type="nameFilter?"/>
         <param name="gns" type="nameFilter?"/>         
         <param name="global" type="xs:boolean?" default="true"/>         
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
         <param name="namespacePrefixLength" type="xs:integer?"/>ss
         <param name="namespaceLabel" type="xs:string?"/>
         <param name="sortAtts" type="xs:boolean?" default="false"/>
         <param name="sortElems" type="xs:boolean?" default="false"/>         
         <param name="sgroupStyle" type="xs:string?" default="ignore" fct_values="expand, compact, ignore"/>         
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="colRhs" type="xs:integer" default="60"/>
         <param name="report" type="xs:string*" fct_values="anno, tdesc, type, stype, ctype, sapiadoc, sapiadoc0, sapiadoc2"/>
         <param name="reportMaxLen" type="xs:integer?"/> 
         <param name="preferElemAnno" type="xs:boolean?" default="false"/>
         <param name="noLabel" type="xs:boolean?"/>
         <param name="lang" type="xs:string?"/>
         <pgroup name="in" minOccurs="1"/>    
         <pgroup name="comps" maxOccurs="1"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.xsdplus.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_request.xqm",
   "tt/_reportAssistent.xqm",
   "tt/_errorAssistent.xqm",
   "tt/_log.xqm",
   "tt/_nameFilter.xqm",
   "tt/_pcollection.xqm";
    
import module namespace app="http://www.xsdplus.org/ns/xquery-functions" 
at "locationTreeComponents.xqm",
   "occUtilities.xqm";
   
import module namespace anno="http://www.xsdplus.org/ns/xquery-functions/anno"
at "annotationUtilities.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

declare variable $f:TSHEET_INDENT_UNIT := '. ';
declare variable $f:TSHEET_FILLER_SIMPLE_ITEMS := 
    string-join(for $i in 1 to 100 return '... ', '');
declare variable $f:TSHEET_FILLER_COMPLEX_ITEMS := 
    string-join(for $i in 1 to 100 return '... ', '');
    
(:    
declare variable $f:TSHEET_FILLER_COMPLEX_ITEMS := 
    string-join(for $i in 1 to 100 return '~~~ ', '');
:)
(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Implements operation `vtree`.
 :
 : @param request the operation request
 : @return a report containing base tree components describing
 :     the schema components specified by operation parameters
 :) 
declare function f:treesheetOp($request as element())
        as xs:string {
    let $schemas := app:getSchemas($request)
    let $enames := tt:getParam($request, 'enames')
    let $tnames := tt:getParam($request, 'tnames')    
    let $gnames := tt:getParam($request, 'gnames')  
    let $ens := tt:getParam($request, 'ens')    
    let $tns := tt:getParam($request, 'tns')
    let $gns := tt:getParam($request, 'gns')    
    let $global := tt:getParam($request, 'global')    
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $groupNorm := tt:getParam($request, 'groupNormalization')
    let $colRhs := tt:getParam($request, 'colRhs')
    let $report := tt:getParam($request, 'report')
    let $lang := tt:getParam($request, 'lang')
    let $sortAtts := tt:getParam($request, 'sortAtts')    
    let $sortElems := tt:getParam($request, 'sortElems')    
    let $sgroupStyle := tt:getParam($request, 'sgroupStyle')    
    let $namespacePrefixLength := tt:getParam($request, 'namespacePrefixLength')
    let $namespaceLabel := tt:getParam($request, 'namespaceLabel')
    let $noLabel := tt:getParam($request, 'noLabel')
    let $reportMaxLen := tt:getParam($request, 'reportMaxLen')
    let $preferElemAnno := tt:getParam($request, 'preferElemAnno')
    
    let $options :=
        <options withStypeTrees="false"
                 withAnnos="{$report = ('anno', 'sapiadoc', 'sapiadoc0', 'sapiadoc2')}"
                 colRhs="{$colRhs}"
                 sgroupStyle="{$sgroupStyle}"
                 sortAtts="{$sortAtts}"
                 sortElems="{$sortElems}"
                 noLabel="{$noLabel}"
                 reportMaxLen="{$reportMaxLen}"
                 preferElemAnno="{$preferElemAnno}">{
            if (empty($namespacePrefixLength)) then () else
                attribute namespacePrefixLength {$namespacePrefixLength},
            if (empty($namespaceLabel)) then () else
                attribute namespaceLabel {$namespaceLabel}
        }</options>
    
    let $itemReporter := 
        for $r in $report return
        
        switch($r)
        case('tdesc') return
            function($n, $options) 
                {
                    if ($n/(self::z:_anyAttribute_)) then ()
                    else if (not($n/@z:type)) then
                        if ($n/@z:abstract) then 'ty: '[not($options/@noLabel eq 'true')] || '(abstract)'
                        else 'tdesc: (no type)'
                    else $n/(@z:typeDesc, @z:contentTypeDesc)[1] ! ('ty: '[not($options/@noLabel eq 'true')] || .)
                }
        (: case('anno') return anno:reportAnno(?, ?, $lang) ! ('anno: ' || .) :) (: unclear - 'anno: ...' removed :)
        case('anno') return anno:reportAnno(?, ?, $lang)
        case('sapiadoc') return anno:reportSapIaDoc(?, 'sapiadoc', ?, $lang)
        case('sapiadoc0') return anno:reportSapIaDoc(?, 'sapiadoc0', ?, $lang)
        case('sapiadoc2') return anno:reportSapIaDoc(?, 'sapiadoc2', ?, $lang)        
        case('type') return
            function($n, $options) 
                {$n/@z:type ! ('type: '[not($options/@noLabel eq 'true')] || .)}
        case('stype') return
            function($n, $options) {
                 if ($n/@z:typeVariant eq 'cc') then ()
                 else $n/@z:type ! ('stype: '[not($options/@noLabel eq 'true')] || .)
            }
        case('ctype') return
            function($n, $options) {
                 if (not($n/@z:typeVariant eq 'cc')) then ()
                 else $n/@z:type ! ('ctype: '[not($options/@noLabel eq 'true')] || .)
            }
        default return ()
    
    return
    (: removed: $colRhs, $sgroupStyle, $namespacePrefixLength, $namespaceLabel,  :)
        f:treesheet($enames, $tnames, $gnames, $ens, $tns, $gns, $global,  
            $itemReporter, $options, $nsmap, $schemas)
};

(:~
 : Creates a treesheet. The components to be reported are specified by name filters
 : ($enames, $tnames, $gnames) and the "global flag", which determines whether 
 : matching element declarations must be global. The item reporting is specified
 : in terms of report functions ($itemReporter).
 :
 : @param enames name filter for element declarations; if $global is 'true',
 :     only top-level element declarations are considered
 : @param tnames name filter for type definitions
 : @param gnames name filter for group definitions
 : @param global if true, the name filter for element declarations matches only
 :     top-level declarations
 : @param colRhs number of the column in which the item reports begin (Rhs = right hand side)
 : @param itemReporter functions mapping a location tree nodes to report lines
 : @param nsmap normalized bindings of namespace URIs to prefixes
 : @param schemas the schema elements currently considered
 : @return a treesheet describing the location tree nodes in terms of the
 :     report created by the $itemReporter functions
 :) 
declare function f:treesheet($enames as element(nameFilter)*,
                             $tnames as element(nameFilter)*,
                             $gnames as element(nameFilter)*,
                             $ens as element(nameFilter)*,
                             $tns as element(nameFilter)*,
                             $gns as element(nameFilter)*,                             
                             $global as xs:boolean?,
                             $itemReporter as function(*)*,
                             $options as element(options),
                             $nsmap as element(zz:nsMap)?,   
                             $schemas as element(xs:schema)+)
        as xs:string {
    let $nsmap := if ($nsmap) then $nsmap else app:getTnsPrefixMap($schemas)
    let $ltree := app:ltree($enames, $tnames, $gnames, $ens, $tns, $gns, $global, $options, 
                            (), $nsmap, $schemas)
    let $tsheet := f:ltree2Treesheet($ltree, $options, $itemReporter)                          
    return
        $tsheet
};

(:~
 : Transforms a location tree into a treesheet.
 :
 : @param ltree a location tree
 : @param options options controlling the view tree construction
 : @return a view tree
 :)
declare function f:ltree2Treesheet($ltree as element(), 
                                   $options as element(options),
                                   $itemReporter as function(*)*)
        as xs:string {
    string-join(
        f:ltree2TreesheetRC($ltree, 0, (), $options, $itemReporter)
        , '&#xA;'
    )        
};

(:~
 : Recursive helper function of `ltree2Treesheet`.
 :)
declare function f:ltree2TreesheetRC($n as node(),
                                     $level as xs:integer,
                                     $prefix as xs:string?,
                                     $options as element(options),
                                     $itemReporter as function(*)*)
        as xs:string* {
    typeswitch($n)

    case element(zz:nsMap) | element(z:_stypeTree_) | element(z:_annotation_) return ()

    case element(z:locationTrees) return 
        for $c in $n/* return
            f:ltree2TreesheetRC($c, 0, $prefix, $options, $itemReporter)
    
    case element(z:locationTree) return
        let $compKind := $n/@compKind
        let $compLabel :=
            switch($compKind)
            case 'elem' return 'Element'
            case 'type' return 'Type'
            case 'group' return 'Group'
            default return 'UNKNOWN-COMP-KIND: '

        let $lname := replace($n/@z:name, '.+:', '')
        let $nsInfo :=
            let $nsMap := $n/zz:nsMap
            return if (not($nsMap)) then () else
            
            let $qname := f:resolveNormalizedQName($n/@z:name, $nsMap)
            let $uri := namespace-uri-from-QName($qname)
            return
                if (not($uri)) then () else
                
                let $namespacePrefixLength := $options/@namespacePrefixLength/xs:integer(.)
                let $namespaceLabel := ($options/@namespaceLabel/string(), 'namespace')[1]
                let $showURI := if (empty($namespacePrefixLength)) then $uri 
                                    else substring($uri, $namespacePrefixLength)
                return
                    concat('   ', $namespaceLabel, ': ', $showURI)
        return (
            concat($compLabel, ': ', $lname, $nsInfo),
            '===================================================',
            for $c in $n/* return 
                f:ltree2TreesheetRC($c, 0, (), $options, $itemReporter)
        )
        
    case element(z:_attributes_) return
        for $c in $n/* return
            f:ltree2TreesheetRC($c, $level, $prefix, $options, $itemReporter)
    
    case element(z:_any_) return
        let $occ := $n/@z:occ
        let $occSuffix :=
            if (matches($occ, '\d')) then concat('{', $occ, '}') else $occ
        let $useName := '_any_' || $occSuffix    
        return
            $prefix || $useName
            
    (: 20190819, hjr: hide _all_ group container element :)
    case element(z:_all_) return
        for $c in $n/node() return f:ltree2TreesheetRC($c, $level, $prefix, $options, $itemReporter)
        
    case element(z:_choice_) | element(z:_sgroup_) return
        let $occ := $n/@z:occ
        let $sgHeadSuffix := $n/@z:sgHead/concat('[', replace(., '.*:', ''), ']')
        let $occSuffix :=
            if (matches($occ, '\d')) then concat('{', $occ, '}') else $occ
        let $useName := local-name($n) || $sgHeadSuffix || $occSuffix    
        return (
            $prefix || $useName,
            let $nextLevel := $level + 1
            for $c at $pos in $n/*
            let $posStr := string($pos)
            let $branchNr := substring($posStr, string-length($posStr))
            let $nextPrefix := $prefix || $branchNr || ' '
            return
                f:ltree2TreesheetRC($c, $nextLevel, $nextPrefix, $options, $itemReporter)
        )
    case element() return
        let $nextPrefix := $prefix || $f:TSHEET_INDENT_UNIT
        let $nextLevel := $level + 1
        let $name := $n/node-name($n)
        let $lname := local-name-from-QName($name)
        let $attPrefix := '@'[$n/parent::z:_attributes_]
        let $collapsedFlag := '+'[$n/@z:collapsed eq 'true']
        let $occ := $n/@z:occ
        let $occSuffix :=
            if (matches($occ, '\d')) then concat('{', $occ, '}') else $occ
        let $lhsText := concat($collapsedFlag, $attPrefix, $lname, $occSuffix)
        let $lhsTextWidth := string-length($lhsText)
        let $rhs := f:treesheetRhs($n, $lhsTextWidth, $options, $itemReporter)        
        let $lhs := f:treesheetLhs($n, $prefix, $lhsText, $options, $rhs)

        let $rep := 
            if (empty($rhs)) then $lhs
            else (
                $lhs || $rhs[1],
                tail($rhs)
            )
        let $content :=
            let $elems :=
                let $preliminary := $n/*
                return
                    if (not($options/@sortElems eq 'true')) then $preliminary
                    else
                        for $item in $preliminary
                        order by local-name($item), namespace-uri($item)
                        return $item
            for $elem in $elems             
            return
                f:ltree2TreesheetRC($elem, $nextLevel, $nextPrefix, $options, $itemReporter)
        return (
            $rep,
            $content
        )
        
    default return ()
};

(:~
 : Creates the tree item descriptor, consisting of the item 
 : name followed by an optional occurrence indicator, a prefix 
 : indicating hierarchy level, and a postfix ensuring alignment 
 : of item descriptions.
 :
 : @param node the item's location tree node
 : @prefix a prefix indicating hierarchy level
 : @lhsText the text of the tree item descriptor, excluding prefix 
 :    indicating hierarchy level and postfix ensuring alignment of
 :    item descriptions
 : @options treesheet options
 : @rhs the lines containing the item description
 : @return complete tree item desciprot, including prefix indicating 
 :    hierarchy level and postfix ensuring alignment
 :) 
declare function f:treesheetLhs($node as element(),
                                $prefix as xs:string?, 
                                $lhsText as xs:string?,                                
                                $options as element(options),
                                $rhs as xs:string*)
        as item()* {
    let $text := concat($prefix, $lhsText)
    return
        if (empty($rhs)) then $text else
    
    let $colRhs := $options/@colRhs/xs:integer(.)
    let $typeVar := $node/@z:typeVariant                     
    let $template :=
        if ($node/self::z:*) then ()
        else if ($typeVar eq 'cc') then $f:TSHEET_FILLER_COMPLEX_ITEMS
        else $f:TSHEET_FILLER_SIMPLE_ITEMS
        
    return if (not($template)) then $text else
        
    let $lenText := string-length($text)  
    let $lenTemplate := string-length($template)
    return
        if ($lenText >= $colRhs - 3) then concat($text, '   ')
        else concat($text, ' ', substring($template, 3 + $lenTemplate - $colRhs + $lenText))
};        

(:~
 : Creates a formatted item report. The first line will be appended 
 : to the tree item descriptor; further lines will start with an 
 : appropriate prefix of space characters ensuring an aligned 
 : appearance of all lines of the report.
 :
 : @param the item's location tree node
 : @param lhsTextWidth length of the leading part of the tree item descriptor, 
 :    consisting of a prefix indicating hierarchy level, item name and
 :    optional occurrence indicator, excluding any postfix used for 
 :    alignment
 : @param options treesheet options
 : @param itemReporter function(s) consuming the location tree node
 :    and returning the raw lines of an item report; the raw lines 
 :    do not include any prefix for achieving alignment
 : @return strings containing the aggregated item report
 :) 
declare function f:treesheetRhs($node as element(),
                                $lhsTextWidth as xs:integer, 
                                $options as element(options),
                                $itemReporter as function(*)*)
        as item()* {
    let $linesRaw :=
        for $ir in $itemReporter
        return $ir($node, $options)
    return
        if (count($linesRaw) le 1) then $linesRaw
        else
            let $colRhs := $options/@colRhs/xs:integer(.)
            let $prefixWidth := max(($colRhs, $lhsTextWidth + 1)) - 1
            let $prefix := string-join(for $i in 1 to $prefixWidth return ' ', '')
            return (
                $linesRaw[1],
                $linesRaw[position() gt 1] ! concat($prefix, .)
            )
};