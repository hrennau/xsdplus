(:
 : -------------------------------------------------------------------------
 :
 : seat2xq.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="seat2xq" type="item()*" func="seat2xqOp">     
         <param name="seat" type="docFOX" fct_minDocCount="1" sep="WS"/>
         <param name="format" type="xs:string?" fct_values="txt, seatx, xqx, txt2, txt3" default="txt2"/>
      </operation>
      <operation name="seatFormatUpgrade" type="item()*" func="seatFormatUpgradeOp">     
         <param name="seat" type="docFOX" fct_minDocCount="1" sep="WS"/>
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
    "constants.xqm",
    "xqx2xq.xqm",
    "schemaLoader.xqm",
    "seatFunctions.xqm",
    "seat2seatx.xqm",
    "seatx2xq.xqm",
    "seatx2xqx.xqm",
    "seat2xq_old.xqm";
    
declare namespace z="http://www.xsdplus.org/ns/structure";
declare namespace zprev="http://www.xsdr.org/ns/structure";

(:~
 : Implements operation `seat2xq`. The operation transforms a 'seat'
 : document into an XQuery implementation of the transformation
 : specified by the document.
 :
 : @param request the operation request
 : @return an XQuery query
 :) 
declare function f:seat2xqOp($request as element())
        as item()* {
    let $schemas := app:getSchemas($request)      
    let $seats as element(z:seats)? := trace(
        tt:getParam($request, 'seat')/*/f:upgradeSeat(.) , 'SEATS: ')
    let $format := tt:getParam($request, 'format')
    let $resources := $seats/z:prolog
    let $seat := $seats/descendant::z:seat[1]
    let $xq := 
        switch($format)
        case 'txt' return f:seat2xq($seat, $resources, $request)
        case 'seatx' return f:seatx($seat, $resources, $request)
        case 'xqx' return 
            let $seatx := f:seatx($seat, $resources, $request)
            return f:seatx2xqx($seatx, $request)
        case 'txt2' return
            let $seatx := f:seatx($seat, $resources, $request)
            return f:seatx2xq($seatx)
        case 'txt3' return
            let $seatx := f:seatx($seat, $resources, $request)
            let $xqx := f:seatx2xqx($seatx, $request)
            return f:xqx2xq($xqx)
        default return error()            
    return $xq
};

(:~
 : Implements operation `seatFormatUpgrade`. A legacy format of a
 : SEAT document is transformed into the current format.
 :
 : @param request the operation request
 : @return an XQuery query
 :) 
declare function f:seatFormatUpgradeOp($request as element())
        as item()* {
    let $seats as element(z:seats)? := tt:getParam($request, 'seat')/*/f:upgradeSeat(.)
    return $seats
};

(:~
 : Upgrades a SEAT doc to the new syntax.
 :
 : @param doc a SEAT document
 : @return the upgraded document
 :)
declare function f:upgradeSeat($doc as element())
        as element() {
    f:upgradeSeatRC($doc)        
};        

(:~
 : Recursive helper function of `upgradeSeat`.
 :)
declare function f:upgradeSeatRC($n as node())
        as node() {
    typeswitch($n)
    case element(zprev:xmaps) return 
        element z:seats {
            for $a in $n/@* return f:upgradeSeatRC($a),
            
            let $seat1 := $n/zprev:xmap[1]
            let $resources := $n/node()[. << $seat1]
            let $seats := $n/node() except $resources
            return (
                <z:prolog>{
                    for $r in $resources return f:upgradeSeatRC($r)
                }</z:prolog>,
                for $s in $seats return f:upgradeSeatRC($s)                
            )
        }
            
    case element(zprev:xmap) return 
        element z:seat {
            for $a in $n/@* return f:upgradeSeatRC($a),
            for $c in $n/node() return f:upgradeSeatRC($c)
        }
    case element(zprev:xmap) return 
        element z:seat {
            for $a in $n/@* return f:upgradeSeatRC($a),
            for $c in $n/node() return f:upgradeSeatRC($c)
        }
    case element() return
        let $nname := 
            if ($n/self::zprev:*) then QName($app:URI_LTREE, concat('z:', local-name($n)))
            else node-name($n)
        return
            element {$nname} {
                for $a in $n/@* return f:upgradeSeatRC($a),
                for $c in $n/node() return f:upgradeSeatRC($c)
            }
    case attribute(if0) return attribute alt {$n}
    case attribute(default) return attribute dflt {$n}    
        
    default return $n            
};        
