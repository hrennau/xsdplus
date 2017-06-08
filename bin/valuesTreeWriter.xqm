(:
 : -------------------------------------------------------------------------
 :
 : frequencies.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="valuesTree" type="item()" func="valuesTreeOp">     
         <param name="doc" type="docFOX" sep="WS" pgroup="input"/>
         <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
         <param name="format" type="xs:string?" fct_values="tree, treesheet" default="treesheet"/>
         <param name="rootElem" type="xs:NCName"/>
         <param name="inamesTokenize" type="nameFilter?" />
         <param name="nterms" type="xs:integer?" default="3"/>
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
 : Implements operation 'valuesTree'. 
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
declare function f:valuesTreeOp($request as element())
        as item()? {
    let $schemas := app:getSchemas($request)        
    let $docs := tt:getParams($request, 'doc dcat')
    let $rootElem := tt:getParams($request, 'rootElem')
    let $format := tt:getParams($request, 'format')
    let $nterms := tt:getParams($request, 'nterms')
    let $inamesTokenize := tt:getParams($request, 'inamesTokenize')
    return
        f:valuesTree($docs, $rootElem, $format, $nterms, $inamesTokenize, $schemas)
};

(:~
 : Creates a values tree. 
 :) 
declare function f:valuesTree($docs as node()+,
                              $rootElem as xs:NCName?,
                              $format as xs:string,
                              $nterms as xs:integer,
                              $inamesTokenize as element(nameFilter)?,
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
        
    let $functionObserveAtts := f:getFunction_attributeNodesObserver_itemValues($nterms, $inamesTokenize)
    let $functionObserveElems := f:getFunction_elementNodesObserver_itemValues($nterms, $inamesTokenize)
    let $valTrees :=
        for $elem in $elems
        group by $elemName := local-name($elem)
        let $tree := app:observationTree($elem, $elem, $functionObserveAtts, $functionObserveElems)
        let $mode := if (count($elem) gt 1) then 'multiDoc' else 'singleDoc'
        return
            <z:valuesTree rootElem="{$elemName}" 
                          mode="{$mode}"
                          countDocs="{count($elem)}" 
                          t="{current-dateTime()}">{
                $tree
            }</z:valuesTree>
    return
        (: case #1 - no schemas, just return frequency trees :)
        if (not($schemas)) then
            if (count($valTrees) eq 1) then $valTrees
            else
                <z:valuesTrees count="{count($valTrees)}">{
                    $valTrees
                }</z:valuesTrees>
        else
        
    (: case #2 - with schemas, return fact trees :)
    let $ltreeAttNames := QName($app:URI_LTREE, 'occ')
    let $otreeAttNamesMap := map{
        QName($app:URI_LTREE, 'z:values'): '-'
    }    
   
    let $options := <options/>
    let $factTrees :=
        for $valTree in $valTrees
        let $rootElem := $valTree/@rootElem
        let $ltree := $ltrees/z:locationTree[$rootElem eq @z:name/replace(., '.*:', '')]
        let $factTree := app:mergeOtreeIntoLtree
            ($ltree, $valTree, $ltreeAttNames, $otreeAttNamesMap, $options)
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
            let $itemReporter := f:treesheetItemReporter_itemValues#2
            return
                app:ltree2Treesheet($report, $options, $itemReporter)
};        

(:~
 : A function mapping a set of observed attributes to attributes and/or elements conveying
 : an observation of type 'itemValues'. The function is called during the construction 
 : of an observation tree.
 :
 : @param atts a set of attributes to be observed
 : @param docs the documents or document fragments containing the attributes
 : @return attributes and/or elements conveying the observations
 :)
declare function f:getFunction_attributeNodesObserver_itemValues(
                        $nterms as xs:integer,
                        $inamesTokenize as element(nameFilter)?)
        as function(*) {
    function($atts, $docs) {
        let $valuesDescriptor := f:getItemValuesDescriptor($atts, $nterms, $inamesTokenize)
        return 
            attribute z:values {$valuesDescriptor}
    }            
};

(:~
 : A function mapping a set of observed elements to attributes and/or elements conveying
 : an observation of type 'itemValues'. The function is called during the construction 
 : of an observation tree.
 :
 : @param atts a set of attributes to be observed
 : @param docs the documents or document fragments containing the attributes
 : @return attributes and/or elements conveying the observations
 :)
declare function f:getFunction_elementNodesObserver_itemValues(
                        $nterms as xs:integer,
                        $inamesTokenize as element(nameFilter)?)
        as function(*) {
    function($elems, $docs) {
        let $valuesDescriptor := f:getItemValuesDescriptor($elems, $nterms, $inamesTokenize)
        return 
            attribute z:values {$valuesDescriptor}
    }            
};        

(:~
 : Maps a sequence of items (attributes or elements) to a descriptor reporting
 : their data values.
 :)
declare function f:getItemValuesDescriptor($items as node()*,
                                           $nterms as xs:integer,
                                           $inamesTokenize as element(nameFilter)?)
        as xs:string? {
    let $values := $items[not(*)]/string()
    let $values :=
            if (not($inamesTokenize)) then $values
            else if (not(tt:matchesNameFilter($items[1]/local-name(), $inamesTokenize))) then $values
            else $values ! tokenize(., '\s+') => distinct-values()
    let $values := $values => sort()
    let $selectedValues := $values[position() le $nterms]
    let $countValues := count($values)
    let $countSelectedValues := count($selectedValues)
    let $valuesDescriptor := string-join($selectedValues, '#') || (
        if ($countValues eq $countSelectedValues) then () else 
            concat('   (',  $countValues - $countSelectedValues, ' more values)'))
    return
        $valuesDescriptor          
};

(:~
 : Creates a treesheet item report, type 'itemValues'.
 :
 : @param node a node of the model to be transformed into a treesheet
 : @param options control details of the item report
 : @return the lines of an item report
 :)
declare function f:treesheetItemReporter_itemValues($node, $options)
        as xs:string* {
    $node[@z:values]/concat('values: ', @z:values)
};
