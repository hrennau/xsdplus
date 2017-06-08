(:
 : -------------------------------------------------------------------------
 :
 : frequencyTreeWriter.xqm - operation and a function creating a frequency tree
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="frequencyTree" type="item()" func="frequencyTreeOp">     
         <param name="doc" type="docFOX" sep="WS" pgroup="input"/>
         <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
         <param name="format" type="xs:string?" fct_values="tree, treesheet" default="treesheet"/>
         <param name="rootElem" type="xs:NCName"/>
         <param name="xsd" type="docFOX*" sep="SC" fct_minDocCount="1"/>
         <param name="colRhs" type="xs:integer" default="60"/>         
         <pgroup name="input" minOccurs="1"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.ttools.org/xitems/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at 
    "constants.xqm",
    "factTreeUtilities.xqm",
    "locationTreeWriter.xqm",
    "schemaLoader.xqm",
    "treesheetWriter.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";

(:~
 : Implements operation 'frequencyTree'. 
 :
 : Operation params:
 : * doc, docs, dcat, fdocs: the XML documents to be processed
 : * rootElem the name of the root elements of the logical documents
 :      to be analyzed; if not specified, all document elements are
 :      considered
 : * format: the report format (tree or treesheet)
 : * colRhs: treesheet column where the item reports start
 : * xsd: XSDs to be used for arranging the frequency in a schema-implied
 :     structure
 :
 : @param request the operation request
 : @return a frequency tree
 :) 
declare function f:frequencyTreeOp($request as element())
        as item()? {
    let $schemas := app:getSchemas($request)        
    let $docs := tt:getParams($request, 'doc dcat')
    let $rootElem := tt:getParams($request, 'rootElem')
    let $format := tt:getParams($request, 'format')
    return
        f:frequencyTree($docs, $rootElem, $format, $schemas)
};

(:~
 : Creates a frequency tree. 
 :) 
declare function f:frequencyTree($docs as node()+,
                                 $rootElem as xs:NCName?,
                                 $format as xs:string,
                                 $schemas as element(xs:schema)*)
        as item()? {                                 
    let $nsmap := 
        if (not($schemas)) then () else app:getTnsPrefixMap($schemas)
        
    (: document root elements :)
    let $elems := 
        if (not($rootElem)) then $docs/*
        else $docs/descendant::*[local-name(.) eq $rootElem]
    return
        if (not($elems)) then () else

    let $enames := distinct-values($elems/local-name(.))
    
    (: location trees :)
    let $ltrees :=
        if (not($schemas)) then () else
        
        let $options := <options withStypeTrees="false"/>
        let $global := true()
        let $elemNameFilters := $enames ! tt:parseNameFilter(.)
        return
            app:ltree($elemNameFilters, (), (),  $global, $options, (), $nsmap, $schemas)
    return
        if ($schemas and count($enames) ne count($ltrees//z:locationTree)) then
            let $enamesWithoutSchema := 
                $enames[not($ltrees/z:locationTree/@z:name/replace(., '.*:', ''))]
            return
                error(QName((), 'INVALID_CALL'), concat(
                    'No XSD declaration found for root element(s): ',
                    string-join($enamesWithoutSchema, ', '),
                    '; available XSD declarations: ',
                    string-join($schemas/xs:element/@name => sort(), ', ')))
        else
        
    let $functionObserveAtts := f:attributeNodesObserver_itemFrequency#2
    let $functionObserveElems := f:elementNodesObserver_itemFrequency#2
    let $freqTrees :=
        for $elem in $elems
        group by $elemName := local-name($elem)
        let $tree := app:observationTree($elem, $elem, $functionObserveAtts, $functionObserveElems)
        let $mode := if (count($elem) gt 1) then 'multiDoc' else 'singleDoc'
        return
            <z:frequencyTree rootElem="{$elemName}" 
                             mode="{$mode}"
                             countDocs="{count($elem)}" 
                             t="{current-dateTime()}">{
                $tree
            }</z:frequencyTree>
    return
        (: case #1 - no schemas, just return frequency trees :)
        if (not($schemas)) then
            if (count($freqTrees) eq 1) then $freqTrees
            else
                <z:frequencyTrees count="{count($freqTrees)}">{
                    $freqTrees
                }</z:frequencyTrees>
        else
        
    (: case #2 - with schemas, return fact trees :)
    let $ltreeAttNames := QName($app:URI_LTREE, 'occ')
    let $otreeAttNamesMap := map{
        QName($app:URI_LTREE, 'z:dcount'): (),
        QName($app:URI_LTREE, 'z:dfreq'): '0',
        QName($app:URI_LTREE, 'z:ifreq'): ()
    }    
   
    let $options := <options/>
    let $factTrees :=
        for $freqTree in $freqTrees
        let $rootElem := $freqTree/@rootElem
        let $ltree := $ltrees/z:locationTree[$rootElem eq @z:name/replace(., '.*:', '')]
        let $factTree := app:mergeOtreeIntoLtree
            ($ltree, $freqTree, $ltreeAttNames, $otreeAttNamesMap, $options)
        return
            $factTree
    let $report :=
        <z:locationTrees count="{count($factTrees)}">{
            $factTrees
        }</z:locationTrees>
    return
        (: format = XML :)
        if ($format eq 'tree') then $report
        
        (: format = treesheet :)
        else 
            let $options := <options colRhs="60"/>
            let $itemReporter := f:treesheetItemReporter_itemFrequency#2
            return
                app:ltree2Treesheet($report, $options, $itemReporter)
};        

(:~
 : A function mapping a set of observed attributes to attributes and/or elements conveying
 : an observation of type 'itemFrequency'. The function is called during the construction 
 : of an observation tree.
 :
 : @param atts a set of attributes to be observed
 : @param docs the documents or document fragments containing the attributes
 : @return attributes and/or elements conveying the observations
 :)
declare function f:attributeNodesObserver_itemFrequency($atts as attribute()*, $docs as node()*)
        as node()* {
    let $dcount := count($docs)
    let $dcountWithItem := count($atts/ancestor::* intersect $docs)        
    let $dfreq := round-half-to-even($dcountWithItem div $dcount, 2)
    return (
        attribute z:dcount {$dcountWithItem},
        attribute z:dfreq {$dfreq}
    )
};

(:~
 : A function mapping a set of observed elements to attributes and/or elements conveying
 : an observation of type 'itemFrequency'. The function is called during the construction 
 : of an observation tree.
 :
 : @param atts a set of attributes to be observed
 : @param docs the documents or document fragments containing the attributes
 : @return attributes and/or elements conveying the observations
 :)
declare function f:elementNodesObserver_itemFrequency($elems as element()*, $docs as node()*)
        as node()* {
    let $dcount := count($docs)
    let $docsWithItem := $elems/ancestor::* intersect $docs
    let $dcountWithItem := count($docsWithItem)
    let $itemFrequencies :=
        for $doc in $docsWithItem 
        group by $countItems := count($elems[ancestor::* intersect $doc])
        return $countItems
    let $itemFreqMean := avg($itemFrequencies) ! round-half-to-even(., 1)
    let $itemFreqMin := min($itemFrequencies) ! round-half-to-even(., 1)
    let $itemFreqMax := max($itemFrequencies) ! round-half-to-even(., 1)
    let $itemFreqInfo := 
        concat($itemFreqMean, 
               if ($itemFreqMax eq 1) then () else concat( 
                   ' (', $itemFreqMin, '-', $itemFreqMax, ')'))
    let $dfreq := round-half-to-even($dcountWithItem div $dcount, 2)
    return    
        if ($elems intersect $docs) then
            attribute z:dcount {count($elems)}
        else (
            attribute z:dcount {$dcountWithItem},
            attribute z:dfreq {$dfreq},
            attribute z:ifreq {$itemFreqInfo}
        )
};        

(:~
 : Creates a treesheet item report, type 'itemFrequency'.
 :
 : @param node a node of the model to be transformed into a treesheet
 : @param options control details of the item report
 : @return the lines of an item report
 :)
declare function f:treesheetItemReporter_itemFrequency($node, $options)
        as xs:string* {
    if ($node/parent::z:locationTree) then 
        concat('dcount: ', $node/@z:dcount)
    else if ($node/@z:dfreq) then
        let $dfreq := $node/@z:dfreq/xs:decimal(.)
        let $barLenMax := 20
        let $barLen := ($barLenMax * $dfreq) ! round-half-to-even(., 0) ! xs:integer(.)
        let $bar := concat(
            string-join(for $i in 1 to $barLen return '*', ''),
            string-join(for $i in 1 to $barLenMax - $barLen return ' ', '')
        )
        return
            concat('dfreq: ', $bar, ' (', $dfreq,
                   $node/@z:ifreq/concat(', ifreq=', .),
                   ')')
    else ()                        
};

(:
(:~
 : Creates a values tree. 
 :
 : Operation params:
 : * doc, docs, dcat, fdocs: the XML documents to be processed
 : * rootElem the name of the root elements of the logical documents
 :      to be analyzed
 :
 : @param request the operation request
 : @return a frequency tree
 :) 
declare function f:valuesTree($request as element())
        as element() {
    let $docs := tt:getParams($request, 'doc docs dcat fdocs')
    let $rootElem := trace(tt:getParams($request, 'rootElem') , 'ROOT_ELEM: ')
    let $numVal := tt:getParams($request, 'numVal')
    
    let $elems := 
        if ($rootElem) then $docs/descendant::*[local-name(.) eq $rootElem]
        else $docs/*
    let $count := count($elems)
    let $tree := f:valuesTreeRC($elems, $numVal)
    return
        <z:valuesTree rootElem="{$rootElem}" 
                      countDocs="{count($elems)}"
                      numVal="{$numVal}"
                      t="{current-dateTime()}">{
            $tree
        }</z:valuesTree>
};        

(:~
 : Recursive helper function of `valuesTree`.
 :
 : @param n a node of the node tree to be processed
 : @param numValues the number of values to be output for each data item
 : @return a values tree
 :) 
declare function f:valuesTreeRC($n as node()+, $numValues as xs:integer)
        as node()? {
    let $count := attribute n {count($n)}        
    let $atts :=
        let $attInfos :=
            for $att in $n/@*
            group by $aname := local-name($att)
            
            let $values :=
                for $attNode in $att
                group by $value := string($attNode)
                order by $value
                return <_a n="{count($attNode)}">{$value}</_a>
            let $minMax := f:getMinMaxAtt($values)                
            order by $aname
            return           
                <_att name="{$aname}" n="{count($att)}" nValues="{count($values)}">{
                    $minMax, $values[position() le $numValues]
                }</_att>
        return <_atts>{$attInfos}</_atts> [exists($attInfos)]        
    let $content :=
        for $child in $n/*
        group by $name := local-name($child)
        order by $name
        return f:valuesTreeRC($child, $numValues)
    let $simpleContent :=
        let $values :=
            for $text in $n[not(*)]/text()
            group by $value := string($text)
            order by lower-case($value)
            return <_v n="{count($text)}">{$value}</_v>
        let $minMax :=  f:getMinMaxAtt($values)
        return
            if (empty($values)) then () 
            else <_values n="{count($values)}">{
                     $minMax, $values[position() le $numValues]
                 }</_values>           
    return
        element {node-name($n[1])} {$count, $atts, $simpleContent, $content}
};

declare function f:getMinMaxAtt($values as element()*) 
        as attribute()? {
    if (empty($values)) then ()
    else if (exists($values[not(. castable as xs:long)])) then
        let $lens := $values/string-length(.)
        return attribute minMaxLen {concat(min($lens), ' - ', max($lens))}
    else attribute minMax {concat(min($values), ' - ', max($values))} 
};
:)
