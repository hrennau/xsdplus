(:
 : xsdp - 
 :
 : @version 2017-06-04T20:10:17.277+02:00 
 :)

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_docs.xqm",
    "tt/_help.xqm",
    "tt/_pcollection.xqm",
    "tt/_pcollection_mongo.xqm",
    "tt/_request.xqm";

import module namespace a2="http://www.ttools.org/xitems/ns/xquery-functions" at
    "frequencyTreeWriter.xqm",
    "valuesTreeWriter.xqm";

import module namespace a1="http://www.xsdplus.org/ns/xquery-functions" at
    "baseTreeNormalizer.xqm",
    "baseTreeReporter.xqm",
    "baseTreeWriter.xqm",
    "componentDependencies.xqm",
    "componentReporter.xqm",
    "jsonSchema.xqm",
    "locationTreeComponents.xqm",
    "locationTreeWriter.xqm",
    "pathDictionary.xqm",
    "schemaLoader.xqm",
    "simpleTypeInfo.xqm",
    "treesheetWriter.xqm",
    "viewBaseTreeWriter.xqm",
    "viewTreeWriter.xqm";

declare namespace m="http://www.xsdplus.org/ns/xquery-functions";
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

declare variable $request as xs:string external;

(: tool scheme 
   ===========
:)
declare variable $toolScheme :=
<topicTool name="xsdp">
  <operations>
    <operation name="_dcat" func="getRcat" type="element()" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="docs" type="catDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="catFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="_docs" func="getDocs" type="element()+" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <pgroup name="input" minOccurs="1"/>
      <param name="doc" type="docURI*" sep="WS" pgroup="input"/>
      <param name="docs" type="docDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="docFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="fdocs" type="docSEARCH*" sep="SC" pgroup="input"/>
    </operation>
    <operation name="_doctypes" func="getDoctypes" type="node()" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <pgroup name="input" minOccurs="1"/>
      <param name="doc" type="docURI*" sep="WS" pgroup="input"/>
      <param name="docs" type="docDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="docFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="fdocs" type="docSEARCH*" sep="SC" pgroup="input"/>
      <param name="attNames" type="xs:boolean" default="false"/>
      <param name="elemNames" type="xs:boolean" default="false"/>
      <param name="sortBy" type="xs:string?" fct_values="name,namespace" default="name"/>
    </operation>
    <operation name="_search" type="node()" func="search" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
    </operation>
    <operation name="_searchCount" type="item()" func="searchCount" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
    </operation>
    <operation name="_createNcat" type="node()" func="createNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_feedNcat" type="node()" func="feedNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="doc" type="docURI*" sep="WS"/>
      <param name="docs" type="catDFD*" sep="SC"/>
      <param name="dox" type="catFOX*" sep="SC"/>
      <param name="path" type="xs:string?"/>
    </operation>
    <operation name="_copyNcat" type="node()" func="copyNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI?" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
      <param name="toNodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_deleteNcat" type="node()" func="deleteNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_nodlSample" type="node()" func="nodlSample" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="model" type="xs:string?" fct_values="xml, sql, mongo" default="xml"/>
    </operation>
    <operation name="test01" type="empty-sequence()" func="test01" mod="tt/_pcollection_mongo.xqm" namespace="http://www.ttools.org/xquery-functions"/>
    <operation name="normBtree" type="node()" func="normBtreeOp" mod="baseTreeNormalizer.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="btree" type="docFOX"/>
      <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
    </operation>
    <operation name="btreeDependencies" type="node()" func="btreeDependencies" mod="baseTreeReporter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="btree" type="docFOX+" sep="SC" fct_minDocCount="1"/>
    </operation>
    <operation name="btree" type="node()" func="btreeOp" mod="baseTreeWriter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="gnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
      <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <pgroup name="in" minOccurs="1"/>
      <pgroup name="comps" maxOccurs="1"/>
    </operation>
    <operation name="deps" type="node()" func="depsOp" mod="componentDependencies.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="gnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <pgroup name="in" minOccurs="1"/>
      <pgroup name="comps" maxOccurs="1"/>
    </operation>
    <operation name="elem" type="item()" func="reportElems" mod="componentReporter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <param name="enames" type="nameFilter?"/>
      <param name="format" type="xs:string*" default="decl" fct_values="decl, name, report"/>
      <param name="tnames" type="nameFilter?"/>
      <param name="scope" type="xs:NCName" fct_values="root, global, local, all" default="all"/>
      <param name="skipAnno" type="xs:boolean?" default="true"/>
      <param name="addUri" type="xs:boolean?" default="false"/>
      <param name="addFname" type="xs:boolean?" default="false"/>
      <param name="paths" type="xs:boolean?" default="false"/>
      <param name="maxPathLevel" type="xs:integer?"/>
      <pgroup name="in" minOccurs="1"/>
    </operation>
    <operation name="att" type="item()" func="reportAtts" mod="componentReporter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <param name="anames" type="nameFilter?"/>
      <param name="format" type="xs:string*" default="decl" fct_values="decl, name, report"/>
      <param name="tnames" type="nameFilter?"/>
      <param name="scope" type="xs:NCName" fct_values="global, local, all" default="all"/>
      <param name="skipAnno" type="xs:boolean?" default="true"/>
      <param name="addUri" type="xs:boolean?" default="false"/>
      <param name="addFname" type="xs:boolean?" default="false"/>
      <param name="paths" type="xs:boolean?" default="false"/>
      <param name="maxPathLevel" type="xs:integer?"/>
      <pgroup name="in" minOccurs="1"/>
    </operation>
    <operation name="type" type="item()" func="reportTypes" mod="componentReporter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <param name="enames" type="nameFilter?"/>
      <param name="tnames" type="nameFilter?"/>
      <param name="rgnames" type="nameFilter?"/>
      <param name="scope" type="xs:NCName" fct_values="global, local, all" default="all"/>
      <param name="skipAnno" type="xs:boolean?" default="true"/>
      <param name="addUri" type="xs:boolean?" default="false"/>
      <param name="addFname" type="xs:boolean?" default="false"/>
      <pgroup name="in" minOccurs="1"/>
    </operation>
    <operation name="group" type="item()" func="reportGroups" mod="componentReporter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <param name="gnames" type="nameFilter?"/>
      <param name="rgnames" type="nameFilter?"/>
      <param name="skipAnno" type="xs:boolean?" default="true"/>
      <param name="addUri" type="xs:boolean?" default="false"/>
      <param name="addFname" type="xs:boolean?" default="false"/>
      <param name="noref" type="xs:boolean?" default="false"/>
      <param name="format" type="xs:string?" default="decl" fct_values="decl, name"/>
      <pgroup name="in" minOccurs="1"/>
    </operation>
    <operation name="agroup" type="item()" func="reportAttGroups" mod="componentReporter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <param name="hnames" type="nameFilter?"/>
      <param name="skipAnno" type="xs:boolean?" default="true"/>
      <param name="addUri" type="xs:boolean?" default="false"/>
      <param name="addFname" type="xs:boolean?" default="false"/>
      <param name="noref" type="xs:boolean?" default="false"/>
      <param name="format" type="xs:string?" default="name" fct_values="decl, name"/>
      <pgroup name="in" minOccurs="1"/>
    </operation>
    <operation name="locators" type="item()" func="getLocators" mod="componentReporter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <param name="enames" type="nameFilter?"/>
      <param name="addFname" type="xs:boolean?" default="false"/>
      <pgroup name="in" minOccurs="1"/>
    </operation>
    <operation name="frequencyTree" type="item()" func="frequencyTreeOp" mod="frequencyTreeWriter.xqm" namespace="http://www.ttools.org/xitems/ns/xquery-functions">
      <param name="doc" type="docFOX" sep="WS" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="format" type="xs:string?" fct_values="tree, treesheet" default="treesheet"/>
      <param name="rootElem" type="xs:NCName"/>
      <param name="xsd" type="docFOX*" sep="SC" fct_minDocCount="1"/>
      <param name="colRhs" type="xs:integer" default="60"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="jschema" type="item()" func="jschema" mod="jsonSchema.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="btree" type="docURI*" fct_rootElem="baseTrees" sep="WS"/>
      <param name="ename" type="nameFilter?"/>
      <param name="format" type="xs:string?" fct_values="xml, json" default="json"/>
      <param name="mode" type="xs:string?" default="rq" fct_values="rq,rs, ot"/>
      <param name="skipRoot" type="xs:boolean?" default="falses"/>
      <param name="top" type="xs:boolean?" default="true"/>
    </operation>
    <operation name="jschemas" type="item()" func="jschemas" mod="jsonSchema.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="dir" type="xs:string"/>
      <param name="btree" type="docURI*" fct_rootElem="baseTrees" sep="WS"/>
      <param name="ename" type="nameFilter?"/>
      <param name="format" type="xs:string?" fct_values="xml, json" default="json"/>
      <param name="mode" type="xs:string?" default="rq" fct_values="rq,rs, ot"/>
      <param name="skipRoot" type="xs:boolean?" default="falses"/>
      <param name="top" type="xs:boolean?" default="true"/>
    </operation>
    <operation name="lcomps" type="node()" func="lcompsOp" mod="locationTreeComponents.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="gnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
      <param name="expandBaseType" type="xs:boolean?" default="true"/>
      <param name="expandGroups" type="xs:boolean?" default="true"/>
      <param name="stypeTrees" type="xs:boolean?" default="true"/>
      <param name="annos" type="xs:boolean?" default="true"/>
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <pgroup name="in" minOccurs="1"/>
      <pgroup name="comps" maxOccurs="1"/>
    </operation>
    <operation name="ltree" type="node()" func="ltreeOp" mod="locationTreeWriter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="gnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
      <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
      <param name="stypeTrees" type="xs:boolean?" default="true"/>
      <param name="annos" type="xs:boolean?" default="true"/>
      <param name="propertyFilter" type="nameFilter?"/>
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <pgroup name="in" minOccurs="1"/>
      <pgroup name="comps" maxOccurs="1"/>
    </operation>
    <operation name="pathDict" type="item()" func="pathDict" mod="pathDictionary.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="ancFilter" type="nameFilter?"/>
      <param name="btree" type="docFOX" fct_minDocCount="1"/>
      <param name="ename" type="nameFilter?"/>
      <param name="format" type="xs:string?" default="txt" fct_values="xml, txt"/>
    </operation>
    <operation name="load" type="node()" func="loadOp" mod="schemaLoader.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="xsd" type="docFOX*" sep="WS" pgroup="input"/>
      <param name="xsdCat" type="docCAT*" sep="WS" pgroup="input"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="stypeTree" type="node()" func="opStypeTree" mod="simpleTypeInfo.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="anames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <pgroup name="in" minOccurs="1"/>
      <pgroup name="comps" maxOccurs="1"/>
    </operation>
    <operation name="stypeDesc" type="node()" func="opStypeDesc" mod="simpleTypeInfo.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="anames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <pgroup name="in" minOccurs="1"/>
      <pgroup name="comps" maxOccurs="1"/>
    </operation>
    <operation name="treesheet" type="xs:string" func="treesheetOp" mod="treesheetWriter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="gnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
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
    <operation name="valuesTree" type="item()" func="valuesTreeOp" mod="valuesTreeWriter.xqm" namespace="http://www.ttools.org/xitems/ns/xquery-functions">
      <param name="doc" type="docFOX" sep="WS" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="format" type="xs:string?" fct_values="tree, treesheet" default="treesheet"/>
      <param name="rootElem" type="xs:NCName"/>
      <param name="inamesTokenize" type="nameFilter?"/>
      <param name="nterms" type="xs:integer?" default="3"/>
      <param name="xsd" type="docFOX*" sep="SC" fct_minDocCount="1"/>
      <param name="colRhs" type="xs:integer" default="60"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="vbtree" type="node()" func="vbtreeOp" mod="viewBaseTreeWriter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="attRep" type="xs:string?" default="elem" fct_values="att, elem, elemSorted"/>
      <param name="btree" type="docFOX"/>
      <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
      <param name="sortAtts" type="xs:boolean?" default="false"/>
    </operation>
    <operation name="vtree" type="node()" func="vtreeOp" mod="viewTreeWriter.xqm" namespace="http://www.xsdplus.org/ns/xquery-functions">
      <param name="attRep" type="xs:string?" default="elem" fct_values="att, elem, elemSorted"/>
      <param name="enames" type="nameFilter?" pgroup="comps"/>
      <param name="tnames" type="nameFilter?" pgroup="comps"/>
      <param name="gnames" type="nameFilter?" pgroup="comps"/>
      <param name="global" type="xs:boolean?" default="false"/>
      <param name="groupNormalization" type="xs:integer" default="4" fct_max="5"/>
      <param name="sortAtts" type="xs:boolean?" default="false"/>
      <param name="xsd" type="docFOX*" sep="SC" pgroup="in" fct_minDocCount="1"/>
      <param name="xsds" type="docCAT*" sep="SC" pgroup="in"/>
      <pgroup name="in" minOccurs="1"/>
      <pgroup name="comps" maxOccurs="1"/>
    </operation>
    <operation name="_help" func="_help" mod="tt/_help.xqm">
      <param name="default" type="xs:boolean" default="false"/>
      <param name="type" type="xs:boolean" default="false"/>
      <param name="mode" type="xs:string" default="overview" fct_values="overview, scheme"/>
      <param name="ops" type="nameFilter?"/>
    </operation>
  </operations>
  <types/>
  <facets/>
</topicTool>;

declare variable $req as element() := tt:loadRequest($request, $toolScheme);


(:~
 : Executes pseudo operation '_storeq'. The request is stored in
 : simplified form, in which every parameter is represented by a 
 : parameter element whose name captures the parameter value
 : and whose text content captures the (unitemized) parameter 
 : value.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__storeq($request as element())
        as node() {
    element {node-name($request)} {
        attribute crTime {current-dateTime()},
        
        for $c in $request/* return
        let $value := replace($c/@paramText, '^\s+|\s+$', '', 's')
        return
            element {node-name($c)} {$value}
    }       
};

    
(:~
 : Executes operation '_dcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__dcat($request as element())
        as element() {
    tt:getRcat($request)        
};
     
(:~
 : Executes operation '_docs'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__docs($request as element())
        as element()+ {
    tt:getDocs($request)        
};
     
(:~
 : Executes operation '_doctypes'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__doctypes($request as element())
        as node() {
    tt:getDoctypes($request)        
};
     
(:~
 : Executes operation '_search'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__search($request as element())
        as node() {
    tt:search($request)        
};
     
(:~
 : Executes operation '_searchCount'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__searchCount($request as element())
        as item() {
    tt:searchCount($request)        
};
     
(:~
 : Executes operation '_createNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__createNcat($request as element())
        as node() {
    tt:createNcat($request)        
};
     
(:~
 : Executes operation '_feedNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__feedNcat($request as element())
        as node() {
    tt:feedNcat($request)        
};
     
(:~
 : Executes operation '_copyNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__copyNcat($request as element())
        as node() {
    tt:copyNcat($request)        
};
     
(:~
 : Executes operation '_deleteNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__deleteNcat($request as element())
        as node() {
    tt:deleteNcat($request)        
};
     
(:~
 : Executes operation '_nodlSample'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__nodlSample($request as element())
        as node() {
    tt:nodlSample($request)        
};
     
(:~
 : Executes operation 'test01'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_test01($request as element())
        as empty-sequence() {
    tt:test01($request)        
};
     
(:~
 : Executes operation 'normBtree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_normBtree($request as element())
        as node() {
    a1:normBtreeOp($request)        
};
     
(:~
 : Executes operation 'btreeDependencies'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_btreeDependencies($request as element())
        as node() {
    a1:btreeDependencies($request)        
};
     
(:~
 : Executes operation 'btree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_btree($request as element())
        as node() {
    a1:btreeOp($request)        
};
     
(:~
 : Executes operation 'deps'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_deps($request as element())
        as node() {
    a1:depsOp($request)        
};
     
(:~
 : Executes operation 'elem'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_elem($request as element())
        as item() {
    a1:reportElems($request)        
};
     
(:~
 : Executes operation 'att'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_att($request as element())
        as item() {
    a1:reportAtts($request)        
};
     
(:~
 : Executes operation 'type'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_type($request as element())
        as item() {
    a1:reportTypes($request)        
};
     
(:~
 : Executes operation 'group'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_group($request as element())
        as item() {
    a1:reportGroups($request)        
};
     
(:~
 : Executes operation 'agroup'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_agroup($request as element())
        as item() {
    a1:reportAttGroups($request)        
};
     
(:~
 : Executes operation 'locators'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_locators($request as element())
        as item() {
    a1:getLocators($request)        
};
     
(:~
 : Executes operation 'frequencyTree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_frequencyTree($request as element())
        as item() {
    a2:frequencyTreeOp($request)        
};
     
(:~
 : Executes operation 'jschema'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_jschema($request as element())
        as item() {
    a1:jschema($request)        
};
     
(:~
 : Executes operation 'jschemas'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_jschemas($request as element())
        as item() {
    a1:jschemas($request)        
};
     
(:~
 : Executes operation 'lcomps'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_lcomps($request as element())
        as node() {
    a1:lcompsOp($request)        
};
     
(:~
 : Executes operation 'ltree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_ltree($request as element())
        as node() {
    a1:ltreeOp($request)        
};
     
(:~
 : Executes operation 'pathDict'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_pathDict($request as element())
        as item() {
    a1:pathDict($request)        
};
     
(:~
 : Executes operation 'load'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_load($request as element())
        as node() {
    a1:loadOp($request)        
};
     
(:~
 : Executes operation 'stypeTree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_stypeTree($request as element())
        as node() {
    a1:opStypeTree($request)        
};
     
(:~
 : Executes operation 'stypeDesc'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_stypeDesc($request as element())
        as node() {
    a1:opStypeDesc($request)        
};
     
(:~
 : Executes operation 'treesheet'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_treesheet($request as element())
        as xs:string {
    a1:treesheetOp($request)        
};
     
(:~
 : Executes operation 'valuesTree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_valuesTree($request as element())
        as item() {
    a2:valuesTreeOp($request)        
};
     
(:~
 : Executes operation 'vbtree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_vbtree($request as element())
        as node() {
    a1:vbtreeOp($request)        
};
     
(:~
 : Executes operation 'vtree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_vtree($request as element())
        as node() {
    a1:vtreeOp($request)        
};
     
(:~
 : Executes operation '_help'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__help($request as element())
        as node() {
    tt:_help($request, $toolScheme)        
};

(:~
 : Executes an operation.
 :
 : @param req the operation request
 : @return the result of the operation
 :)
declare function m:execOperation($req as element())
      as item()* {
    if ($req/self::zz:errors) then tt:_getErrorReport($req, 'Invalid call', 'code', ()) else
    if ($req/@storeq eq 'true') then m:execOperation__storeq($req) else
    
    let $opName := tt:getOperationName($req) 
    let $result :=    
        if ($opName eq '_help') then m:execOperation__help($req)
        else if ($opName eq '_dcat') then m:execOperation__dcat($req)
        else if ($opName eq '_docs') then m:execOperation__docs($req)
        else if ($opName eq '_doctypes') then m:execOperation__doctypes($req)
        else if ($opName eq '_search') then m:execOperation__search($req)
        else if ($opName eq '_searchCount') then m:execOperation__searchCount($req)
        else if ($opName eq '_createNcat') then m:execOperation__createNcat($req)
        else if ($opName eq '_feedNcat') then m:execOperation__feedNcat($req)
        else if ($opName eq '_copyNcat') then m:execOperation__copyNcat($req)
        else if ($opName eq '_deleteNcat') then m:execOperation__deleteNcat($req)
        else if ($opName eq '_nodlSample') then m:execOperation__nodlSample($req)
        else if ($opName eq 'test01') then m:execOperation_test01($req)
        else if ($opName eq 'normBtree') then m:execOperation_normBtree($req)
        else if ($opName eq 'btreeDependencies') then m:execOperation_btreeDependencies($req)
        else if ($opName eq 'btree') then m:execOperation_btree($req)
        else if ($opName eq 'deps') then m:execOperation_deps($req)
        else if ($opName eq 'elem') then m:execOperation_elem($req)
        else if ($opName eq 'att') then m:execOperation_att($req)
        else if ($opName eq 'type') then m:execOperation_type($req)
        else if ($opName eq 'group') then m:execOperation_group($req)
        else if ($opName eq 'agroup') then m:execOperation_agroup($req)
        else if ($opName eq 'locators') then m:execOperation_locators($req)
        else if ($opName eq 'frequencyTree') then m:execOperation_frequencyTree($req)
        else if ($opName eq 'jschema') then m:execOperation_jschema($req)
        else if ($opName eq 'jschemas') then m:execOperation_jschemas($req)
        else if ($opName eq 'lcomps') then m:execOperation_lcomps($req)
        else if ($opName eq 'ltree') then m:execOperation_ltree($req)
        else if ($opName eq 'pathDict') then m:execOperation_pathDict($req)
        else if ($opName eq 'load') then m:execOperation_load($req)
        else if ($opName eq 'stypeTree') then m:execOperation_stypeTree($req)
        else if ($opName eq 'stypeDesc') then m:execOperation_stypeDesc($req)
        else if ($opName eq 'treesheet') then m:execOperation_treesheet($req)
        else if ($opName eq 'valuesTree') then m:execOperation_valuesTree($req)
        else if ($opName eq 'vbtree') then m:execOperation_vbtree($req)
        else if ($opName eq 'vtree') then m:execOperation_vtree($req)
        else if ($opName eq '_help') then m:execOperation__help($req)
        else
        tt:createError('UNKNOWN_OPERATION', concat('No such operation: ', $opName), 
            <error op='{$opName}'/>)    
     let $errors := if ($result instance of node()+) then tt:extractErrors($result) else ()     
     return
         if ($errors) then tt:_getErrorReport($errors, 'System error', 'code', ())     
         else $result
};

m:execOperation($req)
    