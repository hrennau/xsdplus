(:
 : -------------------------------------------------------------------------
 :
 : locationTreeNavigator.xqm - operations for navigating location tree contents
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
    "constants.xqm",
    "locationTreeComponents.xqm",
    "locationTreeNormalizer.xqm",
    "occUtilities.xqm",
    "substitutionGroups.xqm";
    
declare namespace c="http://www.xsdplus.org/ns/xquery-functions";    
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

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns the root element descriptor of a location tree.
 :
 : @param ltree a location tree element
 : @return the root element descriptor of the location tree
 :)
declare function f:getLtreeRoot($ltree as element(z:locationTree))
        as element() {
    $ltree/(* except zz:*)[1]            
};

(:~
 : Returns for a location tree particle node the element descriptors of all possible 
 : child elements. If the particle node is an element descriptor, the result consists 
 : of the descriptors of all possible child elements. If the particle is a group 
 : descriptor (sequence, choice, all), the result consists of the descriptors of all 
 : possible group members.
 :
 : @param elem a location tree node representing an element
 : @return the location tree nodes representing the element's child elements
 :)
declare function f:getLnodeChildElemDescriptors($elem as element())
        as element()* {
    if ($elem/(self::z:_annotation_, self::z:_attributes_)) then () else
    
    let $zchildren := $elem/z:*
    return (
        ($elem/* except $zchildren),
        $zchildren/f:getLnodeChildElemDescriptors(.)
    )
};

(:~
 : Returns for a location tree particle node the attribute descriptors.
 :
 : The particle node is expected to be an element descriptor.
 :
 : @param elem a location tree node representing an element
 : @return the location tree nodes representing the element's attributes
 :)
declare function f:getLnodeAttributeDescriptors($elem as element())
        as element()* {
    $elem/z:_attributes_/(* except z:*)
};

(:~
 : Returns for a location tree particle node the names of all possible child elements. 
 : If the particle node is an element descriptor, the result consists of the names 
 : of all possible child elements. If the particle is a group descriptor (sequence, 
 : choice, all), the result consists of the names of all possible group members.
 :
 : @param elem a location tree node representing an element
 : @return the location tree nodes representing the element's child elements
 :)
declare function f:getLnodeChildElemNames($elem as element())
        as xs:QName* {
    distinct-values(f:getLnodeChildElemDescriptors($elem)/node-name(.))        
};

(:~
 : Returns for a sequence of location tree particle nodes the names of elements 
 : which any instance of the sequence may contain (disregarding wildcards).
 :
 : @param lcontent a sequence of location tree particle nodes (element or group descriptors)
 : @return complete list of all possible member names
 :)
declare function f:getLcontentMemberNames($lcontent as element()*)
        as xs:QName* {
    let $lcontent := $lcontent[not((self::z:_annotation_, self::z:_attributes_))]
    return
        if (not($lcontent)) then () else
    
    let $elemChildren := $lcontent[not(self::z:*)]
    let $groupChildren := $lcontent except $elemChildren
    
    let $names1 := $elemChildren/node-name(.)
    let $names2 := $groupChildren/f:getLcontentMemberNames(*)
    return
        distinct-values(($names1, $names2))
};

(:~
 : Returns for a sequence of location tree particle nodes the names of elements 
 : which any instance of the sequence must contain.
 :
 : Note. The set of names to be returned can be viewed as the distinct values
 : obtained from the union of three sets of names: 
 : (1) Names of non-optional sequence members which are elements; 
 : (2) Names contributed by any non-optional sequence member which is a sequence 
 :     or all group; a sequence or all group contributes all names obtained by
 :     applying this function to the sequence of its child nodes
 : (3) Names contributed by any non-optional sequence member which is a choice 
 :     group; a choice group contributes all names which are mandatory in all 
 :     of its branches.
 :
 : @param lcontent a sequence of location tree particle nodes (element or group descriptors)
 : @return list of all mandatory member names
 :)
declare function f:getLcontentMandatoryMemberNames($lcontent as element()*)
        as xs:QName* {
    let $lcontent := $lcontent[not((self::z:_annotation_, z:_attributes_))]
    return
        if (not($lcontent)) then () else
    
    let $elemChildren := $lcontent[not(self::z:*)][not(@minOccurs eq '0')]/node-name(.)
    let $seqChildren := 
        let $compositors := $lcontent/(self::z:_sequence_, self::z:_all_)[not(@minOccurs eq '0')]
        return f:getLcontentMandatoryMemberNames($compositors/*)
        
    (: choice children contribute those elements which are mandatory in each branch :)
    let $choiceChildren :=        
        for $choice in $lcontent/self::z:_choice_[not(@minOccurs eq '0')]    
        let $branches :=
            for $branch in $choice/*
            let $branchMandatory := f:getLcontentMandatoryMemberNames($branch)
            return
                (: an intermediate representation of the branch used for
                   checking if a given element is mandatory in all branches :)
                <branch>{
                    for $qname in $branchMandatory return
                        <elem name="{local-name-from-QName($qname)}" 
                              namespace="{namespace-uri-from-QName($qname)}"/>
                }</branch>
        return                
            if ($branches[not(*)]) then ()   (: any branch without mandatory members renders the choice optional :)
            else if (count($branches) eq 1) then $branches/elem/QName(@namespace, @name)
            else
                (: select those branch elements which are mandatory in all branches :)
                let $b1 := $branches[1]
                let $tail := tail($branches)
                for $elemName in $b1/elem/QName(@namespace, @name)
                where every $branch in $tail 
                      satisfies $branch/elem/QName(@namespace, @name) = $elemName
                return $elemName
    return
        distinct-values(($elemChildren, $seqChildren, $choiceChildren))            
};

(:~
 : Returns for a sequence of location tree particle nodes the top-level choice 
 : group descriptors. Note that the returned nodes consist of all z:_choice_ 
 : elements found within $lcontent and its descendants which are not contained 
 : by another z:_choice_ element found within $lcontent. 
 :
 : @param lcontent a sequence of location tree particle nodes (element or group descriptors)
 : @return the location tree nodes representing the element's child elements
 :)
declare function f:getLcontentTopLevelChoiceDescriptors($lcontent as element()*)
        as element()* {
    let $lcontent := $lcontent[not((self::z:_annotation_, self::z:_attributes_))]
    return
        if (empty($lcontent)) then () else        
   
    let $choices := $lcontent/self::z:_choice_
    let $otherGroups := $lcontent/self::z:* except $choices    
    return (
        $choices,
        f:getLcontentTopLevelChoiceDescriptors($otherGroups/*)
    )
};

(:~
 : Returns true if a location tree element descriptor refers to a complex element,
 : not a simple element.
 :
 : @param elem element descriptor
 : @return true if the descriptor describes a complex element, false otherwise
 :)
declare function f:isLtreeElemComplex($elem as element())
        as xs:boolean {
    exists(($elem/
        (z:_attributes_, z:_choice_, z:_sequence_, z:_all_, (* except z:*))))
};

(:~
 : Returns for a sequence of location tree particle nodes the descriptors of 
 : elements which an instance of the sequence may contain and which are not 
 : contained by a choice group.
 :
 : @param elem a location tree node representing an element
 : @return the location tree nodes representing the element's child elements
 :)
declare function f:getLcontentNonChoiceChildElemDescriptors($lcontent as element()*)
        as element()* {
    let $lcontent := $lcontent[not((self::z:_annotation_, self::z:_attributes_))]
    return
        if (empty($lcontent)) then () else        

    let $choices := $lcontent/self::z:_choice_
    let $otherGroups := $lcontent/self::z:* except $choices    
    let $elems := $lcontent/(self::* except self::z:*)
    return (
        $elems,
        f:getLcontentNonChoiceChildElemDescriptors($otherGroups/*)
        (: hjr, 20171126 :)
        (: f:getLcontentTopLevelChoiceDescriptors($otherGroups/*) :)
    )
};

declare function f:ltreePath($lnode as element(), $pathContext as node()?)
      as xs:string {     
    let $path := string-join(
        for $item in $lnode/ancestor-or-self::*[not($pathContext) or . >> $pathContext]
        where not($item/ancestor::z:_annotation_) and 
                  (not ($item/self::z:*) or local-name($item) = ('_choice_', '_sequence_', '_all_'))
        return
         if ($item/parent::z:_attributes_) then 
            let $name := $item/@z:name
            let $occ := f:ltreePath_occInd($item)
            return concat('@', $name, $occ)
         else if ($item/self::z:_attributes_) then ()
         else (
            (: insert pseudo step describing the actual choice (if appropriate) :)
            if (not($item/parent::z:_choice_)) then () else
               let $branchNr := concat('.', 1 + count($item/preceding-sibling::*))
               (: if the parent level has several choices, the choice must be identified :)
               let $choiceNr := 1 + $item/../count(preceding-sibling::z:_choice_)
               let $choiceIndex :=
                  if ($choiceNr eq 1) then () else concat('[', $choiceNr, ']')
               let $occ := f:ltreePath_occInd($item/..)
               return
                  concat('#', $occ, $choiceIndex, $branchNr)
            ,
            (: the step itself :)
            if ($item/self::z:_choice_) then () else 
            
            let $occ := f:ltreePath_occInd($item)
            let $name := 
               if ($item/self::z:_choice_) then '#'
               else if ($item/self::z:_sequence_) then '%seq'               
               else if ($item/self::z:_all_) then '%all'               
               else if ($item/@z:name) then $item/@z:name
               else name($item)
            return concat($name, $occ)
         ), '/')
    return $path
};

(:~
 : Returns all base tree data paths of bnodes with a given name.
 :)
declare function f:ltreePathsForItemName($itemName as xs:string,
                                         $ltree as element(),
                                         $nsmap as element(zz:nsMap))
        as xs:string* {
    let $isAtt := starts-with($itemName, '@')
    let $useItemName := if ($isAtt) then substring($itemName, 2) else $itemName
    let $qname := app:resolveNormalizedQName($useItemName, $nsmap)
    let $lnodes :=
        if ($isAtt) then $ltree//z:_attributes_/*[node-name(.) eq $qname]
        else $ltree//*[not(self::z:*)][node-name(.) eq $qname]
    for $apath in $lnodes/f:ltreePath(., ancestor::z:locationTree)
    order by lower-case($apath)
    return $apath
};


(:~
 : Returns the step(s) connecting the parent node of a given location node's target node and the
 : target node of that location node itself. The $mode parameter controls whether any intervening
 : group descriptor (sequence, choice, all) is represented.
 :
 : @param node the location node in question
 : @param mode controls the representation of the step
 : @param nsmapAll a namespace map used for normalizing prefixes across different schema versions
 : @return the trailing path step
 :)
declare function f:ltreePathLastStep($node as element(), 
                                     $mode as xs:string?,
                                     $nsmapAll as element(zz:nsMap))                                        
        as xs:string {
    let $name := concat('@'[$node/parent::z:_attributes_], app:normalizedQNameString(node-name($node), $nsmapAll)) 
    let $parentNode := $node/ancestor::*[not(self::z:*)][1]
    let $stepNodes := $node/ancestor::*[not(. << $parentNode)]
        [if ($mode eq 'ignChoice') then not(self::z:_choice_)
         else if ($mode eq 'ignChoiceSequence') then not(self::z:_choice_) and not(self::z:_sequence_)
         else true()]          
    return string-join(($stepNodes/app:normalizedQNameString(node-name(.), $nsmapAll), $name), '/')
};

(:~
 : Returns the paths of all items of a location tree fragment, relative to
 : the fragment root.
 :
 : @param root location node which is the root of the fragment
 : @return the fragment lnode paths
 :)
declare function f:ltreeFragmentPaths($root as element())
        as xs:string* {
    let $annotationNodes := $root//z:_annotation_//*        
    let $fragmentNodes := ($root//(* except (z:*, xs:*))) except $annotationNodes
    return $fragmentNodes/app:ltreePath(., $root)
};

(:~
 : Returns an indicator string reporting occurrence constraints. If
 : $addBrackets is true, curly brackets are used in case of an indicator
 : specifying one or two numbers.
 :)
declare function f:ltreePath_occInd($item as element())
      as xs:string? {
    if ($item/parent::z:_attributes_) then
        if ($item/@use eq 'required') then ()
        else if ($item/@default) then '?!'
        else if ($item/@fixed) then '!'
        else '?'               
    else $item/@z:occ/(if (matches(., '^\d')) then concat('{', ., '}') else .)
};      









