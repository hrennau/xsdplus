(:
 : -------------------------------------------------------------------------
 :
 : baseTreeInspector.xqm - functions evaluating base trees
 :
 : -------------------------------------------------------------------------
 :)

module namespace f="http://www.xsdplus.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm";    
    
declare namespace z="http://www.xsdplus.org/ns/structure";


(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns the data path of a base tree node, relative to the root descriptor.
 : The names used in the path do not have a prefix.
 :
 : @param bnode a node in a base tree
 : @param ancFilter if specified, no path is returned if no ancestor-or-self is found whose name matches the filter
 : @return the data path of $bnode
 :)
declare function f:getBnodePath($bnode as element(), $ancFilter as element(nameFilter)?)
        as xs:string? {
    if ($bnode/self::z:* and not($bnode/self::z:_attribute_)) then () else
    
    let $broot := $bnode/ancestor-or-self::*[parent::z:baseTree]
    let $ancestors := $bnode/ancestor::*[. >> $broot][not(self::z:*)]
    let $name := if ($bnode/self::z:_attribute_) then concat('@', $bnode/@name) else local-name($bnode)
    let $skip := $ancFilter and not($ancestors[tt:matchesNameFilter(local-name(), $ancFilter)]) and not(tt:matchesNameFilter($name, $ancFilter))
    return if ($skip) then () else
    
    string-join(($ancestors/local-name(.), $name), '/') 
};

(:~
 : Returns the root descriptor of a base tree. Note: the root descriptor is
 : the descriptor of the root element of the document represented by the
 : base tree.
 :
 : @param btree an element representing a base tree
 : @return the root descriptor
 :)
declare function f:getBtreeRoot($btree as element(z:baseTree))
        as element() {
    $btree/*[not(self::z:*)][1]        
};

(:~
 : Returns for a base tree particle node the element descriptors of all possible child 
 : elements. If the particle node is an element descriptor, the result consists of the 
 : descriptors of all possible child elements. If the particle is a group descriptor 
 : (sequence, choice, all), the result consists of the descriptors of all possible group 
 : members.
 :
 : @param elem a base tree node representing an element
 : @return the base tree nodes representing the element's child elements
 :)
declare function f:getBnodeChildElemDescriptors($elem as element())
        as element()* {
    if ($elem/self::z:_annotation_) then () else
    
    let $zchildren := $elem/z:*
    return (
        ($elem/* except $zchildren),
        $zchildren/f:getBnodeChildElemDescriptors(.)
    )
};

(:~
 : Returns for a base tree particle node the names of all possible child elements. If 
 : the particle node is an element descriptor, the result consists of the names of all 
 : possible child elements. If the particle is a group descriptor (sequence, choice, all), 
 : the result consists of the names of all possible group members.
 :
 : @param elem a base tree node representing an element
 : @return the base tree nodes representing the element's child elements
 :)
declare function f:getBnodeChildElemNames($elem as element())
        as xs:QName* {
    distinct-values(f:getBnodeChildElemDescriptors($elem)/node-name(.))        
};

(:~
 : Returns for a sequence of base tree particle nodes the names of elements which any
 : instance of the sequence may contain (disregarding wildcards).
 :
 : @param bcontent a sequence of base tree particle nodes (element or group descriptors)
 : @return complete list of all possible member names
 :)
declare function f:getBcontentMemberNames($bcontent as element()*)
        as xs:QName* {
    let $bcontent := $bcontent[not(self::z:_annotation_)]
    return
        if (not($bcontent)) then () else
    
    let $topElems := $bcontent[not(self::z:*)]/node-name(.)
    let $groupElems := $bcontent/f:getBnodeChildElemNames(.)
    return
        distinct-values(($topElems, $groupElems))
};

(:~
 : Returns for a sequence of base tree particle nodes the names of elements which any
 : instance of the sequence must contain.
 :
 : Note. The set of names to be returned can be viewed as the distinct values
 : obtained from the union of three sets of names: (1) names of non-optional top-level
 : elements; (2) names contributed by any non-optional sequence or all group; (3)names 
 : contributed by any non-optional choice. A non-optional choice contributes all names 
 : which are mandatory in all of its branches.
 :
 : @param bcontent a sequence of base tree particle nodes (element or group descriptors)
 : @return complete list of all mandatory member names
 :)
declare function f:getBcontentMandatoryMemberNames($bcontent as element()*)
        as xs:QName* {
    let $bcontent := $bcontent[not(self::z:_annotation_)]
    return
        if (not($bcontent)) then () else
    
    let $topElems := $bcontent[not(self::z:*)][not(@minOccurs eq '0')]/node-name(.)
    let $seqChildren := 
        let $compositors := $bcontent/(self::z:_sequence_, self::z:_all_)[not(@minOccurs eq '0')]
        return f:getBcontentMandatoryMemberNames($compositors/*)
    let $choiceChildren :=        
        for $choice in $bcontent/self::z:_choice_[not(@minOccurs eq '0')]    
        let $branches :=
            for $branch in $choice/*
            let $branchMandatory := f:getBcontentMandatoryMemberNames($branch)
            return
                <branch>{
                    for $qname in $branchMandatory return
                        <elem name="{local-name-from-QName($qname)}" namespace="{namespace-uri-from-QName($qname)}"/>
                }</branch>
        return                
            if ($branches[not(*)]) then ()   (: any branch without mandatory members renders the choice optional :)
            else if (count($branches) eq 1) then $branches/elem/QName(@namespace, @name)
            else
                let $b1 := $branches[1]
                let $tail := tail($branches)
                for $elemName in $b1/elem/QName(@namespace, @name)
                where every $branch in $tail satisfies $branch/elem/QName(@namespace, @name) = $elemName
                return $elemName
    return
        distinct-values(($topElems, $seqChildren, $choiceChildren))            
};

(:~
 : Returns for a sequence of base tree particle nodes the top-level choice descriptors.
 : Note that the returned nodes consist of all z:_choice_ elements found within $bcontent
 : and its descendants which are not contained by another z:_choice_element found within
 : $bcontent. 
 :
 : @param elem a base tree node representing an element
 : @return the base tree nodes representing the element's child elements
 :)
declare function f:getBcontentTopLevelChoiceDescriptors($bcontent as element()*)
        as element()* {
    let $bcontent := $bcontent[not(self::z:_annotation_)]
    return
        if (empty($bcontent)) then () else        
   
    let $choices := $bcontent/self::z:_choice_
    let $otherGroups := $bcontent/self::z:* except $choices    
    return (
        $choices,
        f:getBcontentTopLevelChoiceDescriptors($otherGroups/*)
    )
};

(:~
 : Returns for a sequence of base tree particle nodes the descriptors of elements which an
 : instance of the sequence may contain and which are not contained by a choice group.
 :
 : @param elem a base tree node representing an element
 : @return the base tree nodes representing the element's child elements
 :)
declare function f:getBcontentNonChoiceChildElemDescriptors($bcontent as element()*)
        as element()* {
    let $bcontent := $bcontent[not(self::z:_annotation_)]
    return
        if (empty($bcontent)) then () else        

    let $choices := $bcontent/self::z:_choice_
    let $otherGroups := $bcontent/self::z:* except $choices    
    let $elems := $bcontent/(self::* except self::z:*)
    return (
        $elems,
        f:getBcontentTopLevelChoiceDescriptors($otherGroups/*)
    )
};


