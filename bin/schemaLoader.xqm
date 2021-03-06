(:
 : -------------------------------------------------------------------------
 :
 : schemaLoader.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="load" type="node()" func="loadOp">     
         <param name="xsd" type="docFOX*" sep="WS" pgroup="input"/>
         <param name="xsdCat" type="docCAT*" sep="WS" pgroup="input"/>
         <param name="retainChameleons" type="xs:boolean?" default="false" />
         <pgroup name="input" minOccurs="1"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.xsdplus.org/ns/xquery-functions";

import module namespace i="http://www.xsdplus.org/ns/xquery-functions" at 
    "namespaceTools.xqm",
    "util.xqm";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
declare namespace z="http://www.xsdplus.org/ns/structure";

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns all xs:schema elements contained by specified resources,
 : or recursively imported or included by those resources.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:loadOp($request as element())
        as element() {
    let $retainChameleons := tt:getParam($request, 'retainChameleons')
    let $docs := tt:getParams($request, 'xsd xsdCat')
    let $schemaRoots := $docs//xs:schema
    let $schemas := f:schemaElems($schemaRoots, $retainChameleons)
    return
        <z:schemas countSchemas="{count($schemas)}">{
           $schemas
        }</z:schemas>
};    

(:~
 : Retrieves all schemas specified by standard request parameters, or directly or
 : indirectly included or imported by specified schemas.
 :
 : @param request the operation request
 :)
declare function f:getSchemas($request as element())
        as element(xs:schema)* {        
    let $headSchemas := tt:getParams($request, 'xsd xsds')/*
    let $retainChameleons := (tt:getParam($request, 'retainChameleons'), false())[1]    
    return 
        if (not($headSchemas)) then () else f:schemaElems($headSchemas, $retainChameleons)        
};

(:~
 : Retrieves all schemas specified by standard request parameters, or directly or
 : indirectly included or imported by specified schemas.
 :
 : @param request the operation request
 : @param retainChameleons if true, chameleon schemas are retained as such, rather than 
 :   transformed into schemas with a target namespace equal to the target namespace
 :   of the including schema
 :)
declare function f:getSchemas($request as element(), $retainChameleons as xs:boolean)
        as element(xs:schema)* {        
    let $headSchemas := tt:getParams($request, 'xsd xsds')/*
    return 
        if (not($headSchemas)) then () else f:schemaElems($headSchemas, $retainChameleons)        
};

(:~ 
 : <p/> Returns the xs:schema elements recursively imported imported/included by a given  
 : schema element. If an included schema is a "chameleon
 : schema" (schema without target namespace which is included by a schema with
 : a target namespace), the chameleon is transformed into a schema with
 : the including schema's target namespace. 
 : <p/>
 : If any include or import could not be resolved to an xs:schema element,
 : the function returns a sequence whose first item is an errors item
 : (xs:errors) followed by the schema elements that could be found. The
 : errors item contains one xs:error child for each failure to resolve, 
 : delivering diagnostic information.
 :
 : @param $rootSchemas   the root xs:schema elements identifying the schema
 : @param $retainChameleons if true, chameleon schemas are not transformed into
 :    a schema with the including schema's target namespace
 : @return a sequence of schema elements and/or one error item, which is
 : an xe:error or an xe:errors element
 :
 : @version 0.1-20100107
 :)
 declare function f:schemaElems($rootSchemas as element()+) 
        as element()* {
    f:schemaElems($rootSchemas, false())        
};

declare function f:schemaElems($rootSchemas as element()+,
                               $retainChameleons as xs:boolean) 
        as element()* {
    (: support for schemas embedded in WSDL ... :)
    let $rootSchemas := $rootSchemas/descendant-or-self::xs:schema

(:    
    let $rootSchemas_embedded := $rootSchemas[parent::*]
    let $rootSchemas_top := $rootSchemas except $rootSchemas_embedded
    
    let $DUMMY := trace(count($rootSchemas_embedded), '#ROOT_SCHEMAS_EMBEDDED: ')
    let $DUMMY := trace(count($rootSchemas_top), '#ROOT_SCHEMAS_TOP: ')
:)    
    let $uris := $rootSchemas ! base-uri(.)
    let $uriNorms := $uris ! f:normalizeUri(.)
(:    
    let $elems_top := if (empty($rootSchemas_top)) then () else f:_schemaElems($rootSchemas_top, $retainChameleons, $uriNorms, ())[. instance of node()] 
    let $elems_embedded := if (empty($rootSchemas_embedded)) then () else f:_schemaElems($rootSchemas_embedded, $retainChameleons, (), ())[. instance of node()]
    
    let $elems := ($elems_top, $elems_embedded)/.
:)
    let $elems := f:_schemaElems($rootSchemas, $retainChameleons, $uriNorms, ())[. instance of node()]
    let $errors := tt:extractErrors($elems)
    return
        if ($errors) then
            tt:wrapErrors($errors) else
            
   (: eleminate elements with duplicate base URI; make sure that
    : elimination must be suppressed if the target namespace differs,
    : as a chameleon schema may be copied more than once in order
    : to acquire more than one namespace.
    :)

   let $elems :=
      for $e at $pos in $elems
      where empty($elems[position() < $pos][base-uri(.) eq base-uri($e) and (
                                               empty((@targetNamespace, $e/@targetNamespace)) or 
                                               @targetNamespace eq $e/@targetNamespace)])
      return $e

   (: eleminate duplicate schema elements with different base URI's.
    : A duplicate is recognized by containing a component already
    : contained by a preceding schema element.
    :)

   let $elems := 
      for $elem at $pos in $elems 
      let $tns := string($elem/@targetNamespace)
      let $elementNames := $elem/xs:element/@name
      let $attributeNames := $elem/xs:attribute/@name
      let $attributeGroupNames := $elem/xs:attributeGroup/@name
      let $modelGroupNames := $elem/xs:modelGroup/@name

      let $repeatedElems :=         
         $elems[position() < $pos][string(@targetNamespace) eq $tns]/xs:element/@name[. = $elementNames]
      
      let $DUMMY :=
        if (not($repeatedElems)) then () else
            trace($repeatedElems/concat(., '   (in: ', $elem/root()/document-uri(.), '   ### also in: ', root()/document-uri(.)), 'REPEATED_ELEMS: ')
      return
      (: Note (hjr, 20180829):
         Applying the treesheet operation to immc2 data (everis) revealed the possible issue
         that filtering the schema elements (removing elements containing a repeated
         top-level component) may cause dangling references 
         (e.g. in f:lcomp_type: app:findType returns the empty sequence)
       :)
       
      (:
        $elem
       :)
              
         $elem [empty($elems[position() < $pos]
                            [string(@targetNamespace) eq $tns]
                            [xs:element/@name = $elementNames])]
               [empty($elems[position() < $pos]
                            [string(@targetNamespace) eq $tns]
                            [xs:attribute/@name = $attributeNames])]
               [empty($elems[position() < $pos]
                            [string(@targetNamespace) eq $tns]
                            [xs:attributeGroupNames/@name = $attributeGroupNames])]
               [empty($elems[position() < $pos]
                            [string(@targetNamespace) eq $tns]
                            [xs:modelGroupNames/@name = $modelGroupNames])]
   return
      ($errors, $elems)
          
};

(:~ 
 : Private helper function for function "schemaElems". Recurses over the
 : tree of schema elements directly or indirectly imported or included by
 : a root schema. Returns the root schema and representations of those
 : included/imported schema elements. If an included/imported schema
 : element is not a "chameleon schema", it is itself returned; otherwise
 : it is represented by an info element which contains the base uri and 
 : the future target namespace of the respective chameleon schema.<p/>

 : Note that base uris are "normalized" by replacing /// by /, as experience
 : showed that the unnormalized form (as returned by 'resolve-uri') may not 
 : be suitable for document retrieval.<p/>

 : Returns all xs:schema elements contributing to a schema identified 
 : by a root schema element. All include and import instructions are
 : are recursively resolved; if the result of a resolving is a "chameleon
 : schema" (schema without target namespace which is included by a schema with
 : a target namespace), the chameleon is transformed into a schema with
 : the including schema's target namespace. 
 :
 : @param $rootSchema   the root schema element identifying the schema
 : @param $retainChameleons if true, chameleon schemas are not transformed into
 :    a schema with the including schema's target namespace
 : @param $foundSoFar   normalized URIs of schema elements produced by 
 :                      preceding recursion steps
 : @param $remainingChildren a sequence of xs:include and/or xs:import elements
 :                      that must be processed
 : @return              a sequence of schema elements and/or an error item, which
 : is an xe:error or an xe:errors element
y :
 : @version 0.1-20100105
 :)
declare function f:_schemaElems($rootSchemas as element(xs:schema)+, 
                                $retainChameleons as xs:boolean,
                                $foundSoFar as xs:string*,
                                $remainingChildren as element()*) 
    as item()* {   
   let $rootSchema := $rootSchemas[1]
   let $remainingRootSchemas := tail($rootSchemas)
   return

  (: not within recursion over one level of xs:import and xs:include elements;
   : this means: $rootSchema is either the very root of the whole schema, or
   : the recursion has just stepped down from a parent schema element to an included
   : or imported schema element, and $rootSchema is that parent schema element
   :)
  if (empty($remainingChildren)) then (
     $rootSchema,
     let $children := $rootSchema/(xs:include, xs:import) (: [@schemaLocation/string()] :)  
        (: 20190326 - predicate removed, in order to support imports without @schemaLocation, within WSDL :)
        (: 20091115, hjr: note the predicate - introduced because import without 
         :                @schemaLocation encountered in: owsExceptionReport.xsd ... 
         :)
     return
        if (empty($children)) then 
           if (empty($remainingRootSchemas)) then ()
           else f:_schemaElems($remainingRootSchemas, $retainChameleons, $foundSoFar, ())
        else
           f:_schemaElems($rootSchemas, $retainChameleons, $foundSoFar, $children)
   )

   (: within recursion over one level of <xs:import> and <xs:include> elements 
    :)
   else
      let $actChild := $remainingChildren[1]
      let $nextRemainingChildren := $remainingChildren[position() gt 1]       
      let $actChildContribution :=
         let $uri := $actChild/@schemaLocation/resolve-uri(., base-uri($actChild))
         let $uriNorm := $uri ! f:normalizeUri(.)
         let $schemaRaw :=
            if (empty($uriNorm)) then
                let $currentSchema := $actChild/ancestor::xs:schema[1]
                let $siblingSchemas := $actChild/root()//xs:schema[not(. is $currentSchema)]
                return
                    $siblingSchemas[@targetNamespace eq $actChild/@namespace]
            else if (not(doc-available($uriNorm))) then () 
            else doc($uriNorm)//xs:schema
            
         return if (not($schemaRaw)) then () else
         
         (: If import or include has no schemaLocation, a pseudo URI must be assigned in order to update $foundSoFar :)
         let $uriNorm := if ($uriNorm) then $uriNorm else 
            concat($rootSchema/base-uri(.), '~~~TNS~~~', $schemaRaw/@targetNamespace) (: pseudo URI :)
         
         let $schema :=
            (: case A) not a chameleon => take as is :)
            if ($actChild/self::xs:import or not($rootSchema/@targetNamespace) or $schemaRaw/@targetNamespace
                or $retainChameleons)
               then
                  if ($foundSoFar = $uriNorm) then () else $schemaRaw

            (: case B) a chameleon => transform to target namespace of including schema element :)
            else  
               let $tns := $rootSchema/@targetNamespace/string() 
               let $uriUsed := concat($uriNorm, '$$$', $tns)
               return
                  if ($foundSoFar = $uriUsed) then ()
                  else
                     let $prefixProposal := ()
                     let $prefix := i:findPrefix($schemaRaw, $tns, $prefixProposal, ()) 
                     return 
                        i:changeTns($schemaRaw, $tns, $prefix)
         return 
            if (empty($schema)) then () else

            let $uriUsed := 
               if (not($schema/@z:isChameleon eq 'true')) then $uriNorm 
               else
                  concat($uriNorm, '$$$', $rootSchema/@targetNamespace)
            return (
               $uriUsed,  (: write into stream, so that it can be extracted on calling levels and transferred into $foundSoFar :)

               if (tt:extractErrors($schema)) then 
                  ($schema, $uriNorm, $foundSoFar)
               else
                  f:_schemaElems($schema, $retainChameleons, ($foundSoFar, $uriUsed), ())

         )
      let $remainingChildrenContribution :=
         if (empty($nextRemainingChildren)) then () else
         let $nextFoundSoFar := 
            distinct-values(
               ($foundSoFar, $actChildContribution
                  [. instance of xs:anyAtomicType] [not(starts-with(., '$$$'))]))
         return
            f:_schemaElems($rootSchema, $retainChameleons, $nextFoundSoFar, $nextRemainingChildren)
      let $remainingRootSchemasContribution :=
         if (empty($remainingRootSchemas)) then () else
         let $nextFoundSoFar :=
            distinct-values(
               ($foundSoFar, ($actChildContribution, $remainingChildrenContribution)
                  [. instance of xs:anyAtomicType] [not(starts-with(., '$$$'))]))
         return
            f:_schemaElems($remainingRootSchemas, $retainChameleons, $nextFoundSoFar, ())
      return
         ($actChildContribution, $remainingChildrenContribution, $remainingRootSchemasContribution)
};

