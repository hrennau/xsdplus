(:
dcat.xq - creates a catalog of document URIs 

Input parameters specifies one or more directories, positive and/or
negative name patterns, a switch determining whether subdirectories
are considered too, the format (xml or text). A further
parameter controls whether the name of the (root) directory
is prepended before the file name. If the parameter "expression"
is used, only XML files are considered for which the expression
evaluates to true (effective boolean value).

@param a whitespace seperated list of directories
@param patterns whitespace separated list of name patterns to be included and/or excluded
@param deep if true, the files of subdirectories are considered, too
@param xmlbase if set, the value will be written into an xml:base attribute at the root element
@param relative if true, the file names are relative to the root directory from
       where they were found, otherwise the root directory is prepended
@param expression if specified, only files are considered which are XML
   and for which the expression evaluates to true (effective boolean value)
@param prefix if set, each this prefix is prepended before each path
@param withdirs if true, the file list contains also directories, otherwise only fils
@param format if text, file names are rendered in plain text, one name per line,
       otherwise as XML document
@return a file list in XML format

@version 20121120-A
==================================================================================
:)

declare namespace m="http://www.xtools.org/ns/functions";

declare variable $dirs external := ".";
declare variable $patterns external := '*';
declare variable $deep as xs:boolean external := false();
declare variable $xmlbase external := ();
declare variable $relative as xs:boolean external := false();
declare variable $expression as xs:string? external := ();
declare variable $prefix as xs:string? external := ();
declare variable $format as xs:string external := "xml";
declare variable $onlyfiles as xs:boolean external := true();


declare variable $itemnames as xs:string? external := "docs/doc/href";   
                   (: 3 items for outer element, inner element, uri attribute;
                      if the attribute is not specified, the uri will be
                      the text content of the inner elements, rather than
                      an attribute value :)

declare variable $href as xs:boolean? := false();

(:~
 : Translates a name list into a name filter.
 :
 : Name pattern syntax: '*' is interpreted as wildcard, 
 :    leading '!' turns the pattern into a negative
 :    pattern, suffix '#c' makes the pattern
 :    case sensitive. Example:
 :    '*RQ#c *RS#c !*test*
 :    =>
 :    matches must end with 'RQ' or 'RS' (case sensitive),
 :    but must not contain the string 'test' (case insensitive)
 :
 : @param names whitespace separated list of name patterns
 :    using name pattern syntax
 : @return a "nameFilter" element
 :)
declare function m:writeNameFilter($patterns as xs:string)
      as element(nameFilter) {
   let $patternList := tokenize($patterns, '\s+')
   let $patternsPlus := $patternList[not(starts-with(., '!'))]   
   let $patternsMinus := for $n in $patternList[starts-with(., '!')] return substring($n, 2)
   return

   <nameFilter>{
      <filterPos>{
         for $p in $patternsPlus
         let $request := 
            let $raw := concat('i', substring-after($p, '#'))            
            return
               if (contains($raw, 'c')) then replace($raw, '[ic]', '')
               else $raw
         let $patternRaw := replace($p, '#.*', '')
         let $patternExp := replace($patternRaw, '\*', '.*')
         let $pattern := concat('^', $patternExp, '$')
         return
            <filter pattern="{$pattern}" options="{$request}"/>
      }</filterPos>,
      <filterNeg>{
         for $p in $patternsMinus
         let $request := 
            let $raw := concat('i', substring-after($p, '#'))            
            return
               if (contains($raw, 'c')) then replace($raw, '[ic]', '')
               else $raw
         let $patternRaw := replace($p, '#.*', '')
         let $patternExp := replace($patternRaw, '\*', '.*')
         let $pattern := concat('^', $patternExp, '$')
         return
            <filter pattern="{$pattern}" options="{$request}"/>
      }</filterNeg>
   }</nameFilter>
};

(:~
 : Filters a sequence of names by a name filter. The name filter
 : was previously obtained by passing a whitespace separated list
 : of name patterns to function 'writeNameFilter'.
 :
 : @params names the names to be filtered
 : @return the filtered names
 :)
declare function m:filterNames($names as xs:string*, $filter as element(nameFilter))
      as xs:string* {
   $names
      [empty($filter/filterPos/filter) or (some $f in $filter/filterPos/filter satisfies matches(., string($f/@pattern), string($f/@options)))]
      [every $f in $filter/filterNeg/filter satisfies not(matches(., string($f/@pattern), string($f/@options)))] 
};

declare function m:getFileList($directories, 
                               $deep as xs:boolean, 
                               $namePatterns as xs:string, 
                               $expression, 
                               $onlyFiles as xs:boolean, 
                               $dirRelative as xs:boolean, 
                               $format as xs:string,
                               $itemnames as xs:string?)
      as element() {
   let $itemnamesList := tokenize($itemnames, '\s*/\s*')
   let $oElemName := ($itemnamesList[1], 'files')[1]
   let $iElemName := ($itemnamesList[2], 'file')[1]
   let $attName := $itemnamesList[3]
   let $filter := m:writeNameFilter($namePatterns)

   let $files :=
      for $dir in tokenize($directories, '\s+') 
      return
         <dir path="{$dir}">{
            let $dirPrefix := if ($dir eq '.') then '' 
                              else replace($dir, '([^/])$', '$1/')
            let $renderDirPrefix := if ($dirRelative) then () else $dirPrefix
            let $names := file:list($dir, $deep)
            for $name in $names
            let $path := concat($dirPrefix, $name)
            let $nameEdited := concat($prefix, $renderDirPrefix, 
                                  replace($name, '\\', '/'))
            let $exprCheck as xs:boolean :=
               if (not($expression)) then true()
               else if (ends-with($path, '.zip')) then false()
               else if (not(doc-available($path))) then false()
               else 
                  let $bindings := map{ '' : doc($path)}
                  return xs:boolean(xquery:eval($expression, $bindings))
            where m:filterNames(replace($name, '.*/', ''), $filter) 
                  and (not($onlyFiles) or not(file:is-dir($path))) 
                  and $exprCheck
            order by lower-case($name)
            return
               element {$iElemName} {
                  if ($attName) then attribute {$attName} {$nameEdited}
                  else $nameEdited
               }
         }</dir>

   let $baseAtt :=
(:   
      let $base := trace( file:path-to-uri(file:parent('.')) , 'BASE: ')
:)      
      let $base := file:path-to-uri(file:current-dir())
      return
        attribute xml:base {$base}
(:        
      if (not($xmlbase)) then () 
      else attribute xml:base {$xmlbase}
:)

   let $doc :=
      element {$oElemName} {
         attribute dirs {$directories},
         attribute deep {$deep},
         attribute patterns {$namePatterns},
         attribute relative {$relative},
         attribute countFiles {count($files/*)},         
         (: attribute itemNames {$itemnames}, :)
         attribute t {current-dateTime()},
         $baseAtt,
         $files/*
   }

   return
      if ($format eq 'xml') then $doc 
      else string-join($doc//file/string(), "&#xA;")
};


m:getFileList($dirs, $deep, $patterns, $expression, $onlyfiles, $relative, $format, $itemnames)
