(:
 : -------------------------------------------------------------------------
 :
 : componentPath.xqm - Document me!
 :
 : IMPLEMENTATION NOTE.
 : Currently, there is a function 'getElemPaths' whose functionality is
 : also offered by the more general funtion 'getItemPaths'. ('Items' is
 : the term designating element and attribute declarations.)
 :
 : Function 'getElemPaths' shall be removed when its uses are replaced 
 : by calls of function 'getItemPaths'.
 :
 : See module 'componentSearch', variable  $f:NEW_PATH_FUNCTION.
 :
 : -------------------------------------------------------------------------
 :)

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace app="http://www.xsdplus.org/ns/xquery-functions" at    
    "componentFinder.xqm",
    "componentNavigator.xqm",
    "targetNamespaceTools.xqm";    

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_constants.xqm",
    "tt/_errorAssistent.xqm";    

declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace z="http://www.xsdplus.org/ns/structure";

(:~
 : Returns the data paths of all element or attribute declarations with a given name.
 :
 : @param name the element name
 : @param elemsOrAtts if value is 'atts', the paths of attribute declarations are returned,
 :    if value is 'elems', the paths of element declarations are returned
 : @param maxCount maximum number of paths to be returned; default: 1000
 : @param schemas the schema elements
 :)
declare function f:getItemPaths(
                      $name as xs:QName,
                      $elemsOrAtts as xs:string,
                      $maxLevel as xs:integer?,
                      $maxCount as xs:integer?,
                      $schemas as element(xs:schema)+) 
      as xs:string* {
    let $declarations := 
        if ($elemsOrAtts eq 'atts') then f:findAtts($name, $schemas)
        else f:findElems($name, $schemas)
    return
       f:dgetItemPaths($declarations, $maxLevel, $maxCount, $schemas)
};

(:~
 : Returns for given element or attribute declarations all data paths.
 :)
declare function f:dgetItemPaths(
                      $declarations as element()*, 
                      $maxLevel as xs:integer?,
                      $maxCount as xs:integer?, 
                      $schemas as element(xs:schema)+) 
      as xs:string* {
    if (empty($declarations)) then () else
    
    let $maxCount := ($maxCount, 1000000)[1]
    
    let $paths := f:_dgetItemPathsHRC($declarations, $maxLevel, $maxCount, (), $schemas)
    for $path in distinct-values($paths) order by $path return $path
};

(:~
 : Recursive helper function of 'dgetItemPaths'. Recursive call submits
 : the tail of the received declarations.
 :)
declare function f:_dgetItemPathsHRC($declarations as element()*,
                                     $maxLevel as xs:integer?,
                                     $maxCount as xs:integer?, 
                                     $pathsSoFar as xs:string*, 
                                     $schemas as element(xs:schema)+) 
      as xs:string* {
      
      if (empty($declarations)) then () else
      
      let $decl1 := $declarations[1]
      let $declTail := tail($declarations)
      
      let $paths := f:_dgetItemPathsRC($decl1, $maxLevel, $maxCount, 0, (), (), $schemas)
      let $newPathsSoFar := distinct-values(($pathsSoFar, $paths))
      
      let $newCount := count($newPathsSoFar)
      return
         if ($newCount gt $maxCount) then $newPathsSoFar[position() le $maxCount]
         else if (empty($declTail)) then $newPathsSoFar
         else
            f:_dgetItemPathsHRC($declTail, $maxLevel, $maxCount, $newPathsSoFar, $schemas)            
};
    
(:~
 : Recursive helper function of 'dgetItemPaths'. Recursive call submits the declarations
 : which can represent the parent elements of the items represented by the received
 : declaration.
 :
 : @param declaration the attribute or element declaration for which data paths are desired
 : @param pathsSoFar data paths aready found
 : @param maxLevel the maximum number of path steps to be traversed
 : @param maxCount the number of paths requested
 : @param curLevel the current number of path steps traversed, starting at the element or
 :    attribute declarations for which paths are requested 
 : @param curPath the path fragment which has been constructed so far during the recursion;
 :    it will be appended to the paths found for the received declaration
 : @param visited the element declarations already visited during the recursion
 : @param schemas the schema elements currently considered
 :)
declare function f:_dgetItemPathsRC($declaration as element()?,
                                    $maxLevel as xs:integer?,
                                    $maxCount as xs:integer?,
                                    $curLevel as xs:integer,
                                    $curPath as xs:string?,
                                    $visited as element()*, 
                                    $schemas as element(xs:schema)+) 
      as xs:string* {
    if (empty($declaration)) then () else

    let $newLevel := $curLevel + 1
    let $prefix := '@'[$declaration/self::xs:attribute]
    
    (: new path obtained by concatenating the current declaration's name and the path fragment constructed before :)
    let $newPath := string-join(($declaration/(@name, @ref)/concat($prefix, .), $curPath), '/') return

    if ($declaration intersect $visited) then 
        trace(concat ('RECURSION(', $newPath, ')*'), 'RECURSION: ')    
    else    
        if ($declaration/parent::xs:schema) then $newPath
        else if ($newLevel ge $maxLevel) then concat('.../', $newPath)
        else    
            let $newVisited := ($declaration, $visited)        
            let $parents := f:dfindItemParents($declaration, $schemas)
            (: let $dummy := trace(string-join($newVisited/@name, '/'), concat('NEW PARENTS=', string-join($parents/@name, ', '), '  ; CONT_WITH_VISITED: ')) :)        
            return       
                distinct-values(
                    for $p in $parents return
                        f:_dgetItemPathsRC($p, $maxLevel, $maxCount, $newLevel, $newPath, $newVisited, $schemas)
                )
};

(:~
 : Finds for given element or attribute declarations the element declarations
 : of possible parent elements.
 :
 : @param elems element declarations
 : @schemas the schema elements
 : @return the element declarations of elements which may have a child
 :    element governed by one of the declarations given
 :    by elems 
 :)
declare function f:dfindItemParents(
                        $declarations as element()*, 
                        $schemas as element(xs:schema)+) 
        as element(xs:element)* {
    if (empty($declarations)) then () else

    let $parentTypes :=
        let $ancestors := $declarations/ancestor::*[local-name() = ('complexType', 'group', 'attributeGroup')][1]
        return (
            $ancestors[self::xs:complexType],
            f:gfindGroupUsingTypes($ancestors[self::xs:group], false(), $schemas),
            f:hfindAttGroupUsingTypes($ancestors[self::xs:attributeGroup], false(), $schemas)            
        )           
    let $usingElems := f:tfindTypeUsingElems($parentTypes, true(), $schemas)
    (: let $dummy := trace(count($parentTypes), concat('ELEM_NAME=', string-join($elems/@name, ', '), ' COUNT_PARENTS: ')) :)    
    return
        $usingElems/.
};




(:~
 : Returns the data paths of all element declarations with a given name.
 :
 : @param name the element name
 : @param maxCount maximum number of paths to be returned; default: 1000
 : @param schemas the schema elements
 :)
declare function f:getElemPaths(
                      $name as xs:QName,
                      $maxLevel as xs:integer?,
                      $maxCount as xs:integer?,
                      $schemas as element(xs:schema)+) 
      as xs:string* {
    let $elems := f:findElems($name, $schemas)
    return
       f:egetElemPaths($elems, $maxLevel, $maxCount, $schemas)
};

(:~
 : Returns for given element declarations all data paths.
 :)
declare function f:egetElemPaths(
                      $elems as element(xs:element)*, 
                      $maxLevel as xs:integer?,
                      $maxCount as xs:integer?, 
                      $schemas as element(xs:schema)+) 
      as xs:string* {
    if (empty($elems)) then () else
    
    let $maxCount := ($maxCount, 1000000)[1]
    
    let $paths := f:_egetElemPathsHRC($elems, $maxLevel, $maxCount, (), $schemas)
    for $path in distinct-values($paths) order by $path return $path
};

(:~
 : Sibling recursing helper function of 'egetElemPaths'.
 :)
declare function f:_egetElemPathsHRC($elems as element(xs:element)*,
                                     $maxLevel as xs:integer?,
                                     $maxCount as xs:integer?, 
                                     $pathsSoFar as xs:string*, 
                                     $schemas as element(xs:schema)+) 
      as xs:string* {
      
      if (empty($elems)) then () else
      
      let $elem1 := $elems[1]
      let $elemTail := tail($elems)
      
      let $paths := f:_egetElemPathsRC($elem1, $pathsSoFar, $maxLevel, $maxCount, 0, (), (), $schemas)
      let $newPathsSoFar := distinct-values(($pathsSoFar, $paths))
      
      let $newCount := count($newPathsSoFar)
      return
         if ($newCount gt $maxCount) then $newPathsSoFar[position() le $maxCount]
         else if (empty($elemTail)) then $newPathsSoFar
         else
            f:_egetElemPathsHRC($elemTail, $maxLevel, $maxCount, $pathsSoFar, $schemas)            
};
    
(:~
 : Child recursing helper function of 'egetElemPaths'.
 :
 : @param visited the element declarations already visited during the recursion
 : @param curPath the path fragment which has been constructed so far during the recursion
 :)
declare function f:_egetElemPathsRC($elem as element(xs:element)?,
                                    $pathsSoFar as xs:string*,
                                    $maxLevel as xs:integer?,
                                    $maxCount as xs:integer?,
                                    $curLevel as xs:integer,
                                    $curPath as xs:string?,
                                    $visited as element(xs:element)*, 
                                    $schemas as element(xs:schema)+) 
      as xs:string* {
    if (empty($elem)) then () else

    let $newLevel := $curLevel + 1
    let $newPath := string-join(($elem/(@name, @ref), $curPath), '/') return

    if ($elem intersect $visited) then
        distinct-values(($pathsSoFar, concat ('RECURSION(', $newPath, ')*')))
    else    

        if ($elem/parent::xs:schema) then
            distinct-values(($pathsSoFar, $newPath))
        else if ($newLevel ge $maxLevel) then
            let $newPath := concat('.../', $newPath)
            return
                distinct-values(($pathsSoFar, $newPath))
        else    
    
        let $newVisited := ($elem, $visited)        
        let $parents := f:efindElemParents($elem, $schemas)
        (: let $dummy := trace(string-join($newVisited/@name, '/'), concat('NEW PARENTS=', string-join($parents/@name, ', '), '  ; CONT_WITH_VISITED: ')) :)        
        return       
            let $paths := distinct-values(
                for $p in $parents return
                    f:_egetElemPathsRC($p, $pathsSoFar, $maxLevel, $maxCount, $newLevel, $newPath, $newVisited, $schemas)
            )
            return
                $paths  (: [empty($maxCount) or position() le $maxCount] :)       
};

(:~
 : Finds for all element declarations with a given name the element declarations
 : of possible parent elements.
 :
 : @param name the element name
 : @schemas the schemas elements
 : @return the element declarations of elements that may have a child
 :    element with name equal $name
 :)
declare function f:findElemParents(
                        $name as xs:QName, 
                        $schemas as element(xs:schema)+) 
        as element(xs:element)* {
        
    let $elems := f:findElems($name, $schemas)
    return
       f:efindElemParents($elems, $schemas)
};

(:~
 : Finds for given element declarations the element declarations
 : of possible parent elements.
 :
 : @param elems element declarations
 : @schemas the schema elements
 : @return the element declarations of elements which may have a child
 :    element governed by one of the declarations given
 :    by elems 
 :)
declare function f:efindElemParents(
                        $elems as element(xs:element)*, 
                        $schemas as element(xs:schema)+) 
        as element(xs:element)* {
    if (empty($elems)) then () else

    let $parentTypes :=
        let $ancestors := $elems/ancestor::*[local-name() = ('complexType', 'group')][1]
        return (
            $ancestors[self::xs:complexType],
            f:gfindGroupUsingTypes($ancestors[self::xs:group], false(), $schemas)
        )           
    let $usingElems := f:tfindTypeUsingElems($parentTypes, true(), $schemas)
    (: let $dummy := trace(count($parentTypes), concat('ELEM_NAME=', string-join($elems/@name, ', '), ' COUNT_PARENTS: ')) :)    
    return
        $usingElems/.
};



