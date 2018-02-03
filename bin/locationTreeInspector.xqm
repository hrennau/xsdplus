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







