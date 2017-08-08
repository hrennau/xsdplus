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
         <param name="global" type="xs:boolean?" default="true"/>         
         <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
         <param name="sortAtts" type="xs:boolean?" default="false"/>
         <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
         <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
         <param name="colRhs" type="xs:integer" default="60"/>
         <param name="report" type="xs:string*" fct_values="anno, tdesc, tname, stname, ctname"/>
         <param name="lang" type="xs:string?"/>
         <pgroup name="in" minOccurs="1"/>    
         <pgroup name="comps" maxOccurs="1"/>         
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
    let $global := tt:getParam($request, 'global')    
    let $nsmap := app:getTnsPrefixMap($schemas)
    let $groupNorm := trace(tt:getParam($request, 'groupNormalization') , 'GROUP NORMALIZATION: ')
    let $colRhs := tt:getParam($request, 'colRhs')
    let $report := tt:getParam($request, 'report')
    let $lang := tt:getParam($request, 'lang')
    
    let $itemReporter := 
        for $r in $report return
        
        switch($r)
        case('tdesc') return
            function($n, $options) 
                {
                    if (not($n/@z:type)) then
                        if ($n/@z:abstract) then 'tdesc: (abstract)'
                        else 'tdesc: (no type)'
                    else $n/(@z:typeDesc, @z:contentTypeDesc)[1] ! ('tdesc: ' || .)
                }
        case('anno') return f:reportAnno(?, ?, $lang)
        case('tname') return
            function($n, $options) 
                {$n/@z:type ! ('tname: ' || .)}
        case('stname') return
            function($n, $options) {
                 if ($n/@z:typeVariant eq 'cc') then ()
                 else $n/@z:type ! ('tname: ' || .)
            }
        case('ctname') return
            function($n, $options) {
                 if (not($n/@z:typeVariant eq 'cc')) then ()
                 else $n/@z:type ! ('tname: ' || .)
            }
        default return ()
    
    return
        f:treesheet($enames, $tnames, $gnames, $global, $colRhs, $itemReporter, $nsmap, $schemas)
};

declare function f:reportAnno($n as node(), $options as element(options)?, $lang as xs:string?) 
        as xs:string* {
    let $docums := $n/z:_annotation_/z:_documentation_
    let $docum :=
        if (count($docums) le 1) then $docums
        else 
            let $try := $docums[@xml:lang eq $lang]
            return
                if ($try) then $try
                else
                    let $try := 
                        if ($lang eq 'en') then () else $docums[@xml:lang eq 'en']
                    return
                        if ($try) then $try
                        else
                            let $try := $docums[not(@xml:lang)]
                            return
                                if ($try) then $try
                                else
                                    let $langs := distinct-values($docums/@xml:lang) => sort()
                                    return
                                        $docums[@xml:lang eq $langs[1]]
    return 
        if (not($docum)) then () else 'anno: ' || string-join($docum, ' ### ') ! normalize-space(.)
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
                             $global as xs:boolean?,
                             $colRhs as xs:integer?,
                             $itemReporter as function(*)*,
                             $nsmap as element(z:nsMap)?,
                             $schemas as element(xs:schema)+)
        as xs:string {
    let $options :=
        <options withStypeTrees="false"
                 withAnnos="true"
                 colRhs="{$colRhs}"
        />
    let $nsmap := if ($nsmap) then $nsmap else app:getTnsPrefixMap($schemas)
    let $ltree := app:ltree($enames, $tnames, $gnames, $global, $options, 
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

    case element(z:nsMap) | element(z:_stypeTree_) | element(z:_annotation_) return ()

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
        let $nname := $n/@z:name
        let $lname := replace($nname, '.*:', '')
        return (
            concat($compLabel, ': ', $lname),
            '===================================================',
            for $c in $n/* return 
                f:ltree2TreesheetRC($c, 0, (), $options, $itemReporter)
        )
        
    case element(z:_attributes_) return
        for $c in $n/* return
            f:ltree2TreesheetRC($c, $level, $prefix, $options, $itemReporter)
    
    case element(z:_choice_) return
        let $occ := $n/@z:occ
        let $occSuffix :=
            if (matches($occ, '\d')) then concat('{', $occ, '}') else $occ
        let $useName := '_choice_' || $occSuffix    
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
        let $occ := $n/@z:occ
        let $occSuffix :=
            if (matches($occ, '\d')) then concat('{', $occ, '}') else $occ
        let $lhsText := concat($attPrefix, $lname, $occSuffix)
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
            for $c in $n/* return
                f:ltree2TreesheetRC($c, $nextLevel, $nextPrefix, $options, $itemReporter)
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