// Chuck Benz, Hollis, NH   Copyright (c)2002
//
// The information and description contained herein is the
// property of Chuck Benz.
//
// Permission is granted for any reuse of this information
// and description as long as this copyright notice is
// preserved.  Modifications may be made as long as this
// notice is preserved.

// per Widmer and Franaszek

task automatic f_8b10b_encode (input [8:0] datain, input dispin, output [9:0] dataout, output dispout) ;
  logic ai = datain[0] ;
  logic bi = datain[1] ;
  logic ci = datain[2] ;
  logic di = datain[3] ;
  logic ei = datain[4] ;
  logic fi = datain[5] ;
  logic gi = datain[6] ;
  logic hi = datain[7] ;
  logic ki = datain[8] ;

  logic aeqb = (ai & bi) | (!ai & !bi) ;
  logic ceqd = (ci & di) | (!ci & !di) ;
  logic l22 = (ai & bi & !ci & !di) |
	     (ci & di & !ai & !bi) |
	     ( !aeqb & !ceqd) ;
  logic l40 = ai & bi & ci & di ;
  logic l04 = !ai & !bi & !ci & !di ;
  logic l13 = ( !aeqb & !ci & !di) |
	     ( !ceqd & !ai & !bi) ;
  logic l31 = ( !aeqb & ci & di) |
	     ( !ceqd & ai & bi) ;

  // The 5B/6B encoding

  logic ao = ai ;
  logic bo = (bi & !l40) | l04 ;
  logic co = l04 | ci | (ei & di & !ci & !bi & !ai) ;
  logic doo = di & ! (ai & bi & ci) ;
  logic eo = (ei | l13) & ! (ei & di & !ci & !bi & !ai) ;
  logic io = (l22 & !ei) |
	    (ei & !di & !ci & !(ai&bi)) |  // D16, D17, D18
	    (ei & l40) |
	    (ki & ei & di & ci & !bi & !ai) | // K.28
	    (ei & !di & ci & !bi & !ai) ;

  // pds16 indicates cases where d-1 is assumed + to get our encoded value
  logic pd1s6 = (ei & di & !ci & !bi & !ai) | (!ei & !l22 & !l31) ;
  // nds16 indicates cases where d-1 is assumed - to get our encoded value
  logic nd1s6 = ki | (ei & !l22 & !l13) | (!ei & !di & ci & bi & ai) ;

  // ndos6 is pds16 cases where d-1 is + yields - disp out - all of them
  logic ndos6 = pd1s6 ;
  // pdos6 is nds16 cases where d-1 is - yields + disp out - all but one
  logic pdos6 = ki | (ei & !l22 & !l13) ;


  // some Dx.7 and all Kx.7 cases result in run length of 5 case unless
  // an alternate coding is used (referred to as Dx.A7, normal is Dx.P7)
  // specifically, D11, D13, D14, D17, D18, D19.
  logic alt7 = fi & gi & hi & (ki | 
			      (dispin ? (!ei & di & l31) : (ei & !di & l13))) ;

   
  logic fo = fi & ! alt7 ;
  logic go = gi | (!fi & !gi & !hi) ;
  logic ho = hi ;
  logic jo = (!hi & (gi ^ fi)) | alt7 ;

  // nd1s4 is cases where d-1 is assumed - to get our encoded value
  logic nd1s4 = fi & gi ;
  // pd1s4 is cases where d-1 is assumed + to get our encoded value
  logic pd1s4 = (!fi & !gi) | (ki & ((fi & !gi) | (!fi & gi))) ;

  // ndos4 is pd1s4 cases where d-1 is + yields - disp out - just some
  logic ndos4 = (!fi & !gi) ;
  // pdos4 is nd1s4 cases where d-1 is - yields + disp out 
  logic pdos4 = fi & gi & hi ;

  // only legal K codes are K28.0->.7, K23/27/29/30.7
  //	K28.0->7 is ei=di=ci=1,bi=ai=0
  //	K23 is 10111
  //	K27 is 11011
  //	K29 is 11101
  //	K30 is 11110 - so K23/27/29/30 are ei & l31
  logic illegalk = ki & 
		  (ai | bi | !ci | !di | !ei) & // not K28.0->7
		  (!fi | !gi | !hi | !ei | !l31) ; // not K23/27/29/30.7

  // now determine whether to do the complementing
  // complement if prev disp is - and pd1s6 is set, or + and nd1s6 is set
  logic compls6 = (pd1s6 & !dispin) | (nd1s6 & dispin) ;

  // disparity out of 5b6b is disp in with pdso6 and ndso6
  // pds16 indicates cases where d-1 is assumed + to get our encoded value
  // ndos6 is cases where d-1 is + yields - disp out
  // nds16 indicates cases where d-1 is assumed - to get our encoded value
  // pdos6 is cases where d-1 is - yields + disp out
  // disp toggles in all ndis16 cases, and all but that 1 nds16 case

  logic disp6 = dispin ^ (ndos6 | pdos6) ;

  logic compls4 = (pd1s4 & !disp6) | (nd1s4 & disp6) ;
  dispout = disp6 ^ (ndos4 | pdos4) ;

  dataout = {(jo ^ compls4), (ho ^ compls4),
		    (go ^ compls4), (fo ^ compls4),
		    (io ^ compls6), (eo ^ compls6),
		    (doo ^ compls6), (co ^ compls6),
		    (bo ^ compls6), (ao ^ compls6)} ;

endtask

// Chuck Benz, Hollis, NH   Copyright (c)2002
//
// The information and description contained herein is the
// property of Chuck Benz.
//
// Permission is granted for any reuse of this information
// and description as long as this copyright notice is
// preserved.  Modifications may be made as long as this
// notice is preserved.

// per Widmer and Franaszek


task automatic f_8b10b_decode ( input [9:0] datain, input dispin, output [8:0] dataout, output dispout, output code_err, output disp_err) ;

  logic ai = datain[0] ;
  logic bi = datain[1] ;
  logic ci = datain[2] ;
  logic di = datain[3] ;
  logic ei = datain[4] ;
  logic ii = datain[5] ;
  logic fi = datain[6] ;
  logic gi = datain[7] ;
  logic hi = datain[8] ;
  logic ji = datain[9] ;

  logic aeqb = (ai & bi) | (!ai & !bi) ;
  logic ceqd = (ci & di) | (!ci & !di) ;
  logic p22 = (ai & bi & !ci & !di) |
	     (ci & di & !ai & !bi) |
	     ( !aeqb & !ceqd) ;
  logic p13 = ( !aeqb & !ci & !di) |
	     ( !ceqd & !ai & !bi) ;
  logic p31 = ( !aeqb & ci & di) |
	     ( !ceqd & ai & bi) ;

  logic p40 = ai & bi & ci & di ;
  logic p04 = !ai & !bi & !ci & !di ;

  logic disp6a = p31 | (p22 & dispin) ; // pos disp if p22 and was pos, or p31.
   logic disp6a2 = p31 & dispin ;  // disp is ++ after 4 bits
   logic disp6a0 = p13 & ! dispin ; // -- disp after 4 bits
    
  logic disp6b = (((ei & ii & ! disp6a0) | (disp6a & (ei | ii)) | disp6a2 |
		  (ei & ii & di)) & (ei | ii | di)) ;

  // The 5B/6B decoding special cases where ABCDE != abcde

  logic p22bceeqi = p22 & bi & ci & (ei == ii) ;
  logic p22bncneeqi = p22 & !bi & !ci & (ei == ii) ;
  logic p13in = p13 & !ii ;
  logic p31i = p31 & ii ;
  logic p13dei = p13 & di & ei & ii ;
  logic p22aceeqi = p22 & ai & ci & (ei == ii) ;
  logic p22ancneeqi = p22 & !ai & !ci & (ei == ii) ;
  logic p13en = p13 & !ei ;
  logic anbnenin = !ai & !bi & !ei & !ii ;
  logic abei = ai & bi & ei & ii ;
  logic cdei = ci & di & ei & ii ;
  logic cndnenin = !ci & !di & !ei & !ii ;

  // non-zero disparity cases:
  logic p22enin = p22 & !ei & !ii ;
  logic p22ei = p22 & ei & ii ;
  //logic p13in = p12 & !ii ;
  //logic p31i = p31 & ii ;
  logic p31dnenin = p31 & !di & !ei & !ii ;
  //logic p13dei = p13 & di & ei & ii ;
  logic p31e = p31 & ei ;

  logic compa = p22bncneeqi | p31i | p13dei | p22ancneeqi | 
		p13en | abei | cndnenin ;
  logic compb = p22bceeqi | p31i | p13dei | p22aceeqi | 
		p13en | abei | cndnenin ;
  logic compc = p22bceeqi | p31i | p13dei | p22ancneeqi | 
		p13en | anbnenin | cndnenin ;
  logic compd = p22bncneeqi | p31i | p13dei | p22aceeqi |
		p13en | abei | cndnenin ;
  logic compe = p22bncneeqi | p13in | p13dei | p22ancneeqi | 
		p13en | anbnenin | cndnenin ;

  logic ao = ai ^ compa ;
  logic bo = bi ^ compb ;
  logic co = ci ^ compc ;
  logic doo = di ^ compd ;
  logic eo = ei ^ compe ;

  logic feqg = (fi & gi) | (!fi & !gi) ;
  logic heqj = (hi & ji) | (!hi & !ji) ;
  logic fghj22 = (fi & gi & !hi & !ji) |
		(!fi & !gi & hi & ji) |
		( !feqg & !heqj) ;
  logic fghjp13 = ( !feqg & !hi & !ji) |
		 ( !heqj & !fi & !gi) ;
  logic fghjp31 = ( (!feqg) & hi & ji) |
		 ( !heqj & fi & gi) ;


  logic ko = ( (ci & di & ei & ii) | ( !ci & !di & !ei & !ii) |
		(p13 & !ei & ii & gi & hi & ji) |
		(p31 & ei & !ii & !gi & !hi & !ji)) ;

  logic alt7 =   (fi & !gi & !hi & // 1000 cases, where disp6b is 1
		 ((dispin & ci & di & !ei & !ii) | ko |
		  (dispin & !ci & di & !ei & !ii))) |
		(!fi & gi & hi & // 0111 cases, where disp6b is 0
		 (( !dispin & !ci & !di & ei & ii) | ko |
		  ( !dispin & ci & !di & ei & ii))) ;

  logic k28 = (ci & di & ei & ii) | ! (ci | di | ei | ii) ;
  // k28 with positive disp into fghi - .1, .2, .5, and .6 special cases
  logic k28p = ! (ci | di | ei | ii) ;
  logic fo = (ji & !fi & (hi | !gi | k28p)) |
	    (fi & !ji & (!hi | gi | !k28p)) |
	    (k28p & gi & hi) |
	    (!k28p & !gi & !hi) ;
  logic go = (ji & !fi & (hi | !gi | !k28p)) |
	    (fi & !ji & (!hi | gi |k28p)) |
	    (!k28p & gi & hi) |
	    (k28p & !gi & !hi) ;
  logic ho = ((ji ^ hi) & ! ((!fi & gi & !hi & ji & !k28p) | (!fi & gi & hi & !ji & k28p) | 
			    (fi & !gi & !hi & ji & !k28p) | (fi & !gi & hi & !ji & k28p))) |
	    (!fi & gi & hi & ji) | (fi & !gi & !hi & !ji) ;

  logic disp6p = (p31 & (ei | ii)) | (p22 & ei & ii) ;
  logic disp6n = (p13 & ! (ei & ii)) | (p22 & !ei & !ii) ;
  logic disp4p = fghjp31 ;
  logic disp4n = fghjp13 ;

  dispout = (fghjp31 | (disp6b & fghj22) | (hi & ji)) & (hi | ji);

  code_err = p40 | p04 | (fi & gi & hi & ji) | (!fi & !gi & !hi & !ji) |
		    (p13 & !ei & !ii) | (p31 & ei & ii) | 
		    (ei & ii & fi & gi & hi) | (!ei & !ii & !fi & !gi & !hi) | 
		    (ei & !ii & gi & hi & ji) | (!ei & ii & !gi & !hi & !ji) |
		    (!p31 & ei & !ii & !gi & !hi & !ji) |
		    (!p13 & !ei & ii & gi & hi & ji) |
		    (((ei & ii & !gi & !hi & !ji) | 
		      (!ei & !ii & gi & hi & ji)) &
		     ! ((ci & di & ei) | (!ci & !di & !ei))) |
		    (disp6p & disp4p) | (disp6n & disp4n) |
		    (ai & bi & ci & !ei & !ii & ((!fi & !gi) | fghjp13)) |
		    (!ai & !bi & !ci & ei & ii & ((fi & gi) | fghjp31)) |
		    (fi & gi & !hi & !ji & disp6p) |
		    (!fi & !gi & hi & ji & disp6n) |
		    (ci & di & ei & ii & !fi & !gi & !hi) |
		    (!ci & !di & !ei & !ii & fi & gi & hi) ;

  dataout = {ko, ho, go, fo, eo, doo, co, bo, ao} ;

  // my disp err fires for any legal codes that violate disparity, may fire for illegal codes
   disp_err = ((dispin & disp6p) | (disp6n & !dispin) |
		      (dispin & !disp6n & fi & gi) |
		      (dispin & ai & bi & ci) |
		      (dispin & !disp6n & disp4p) |
		      (!dispin & !disp6p & !fi & !gi) |
		      (!dispin & !ai & !bi & !ci) |
		      (!dispin & !disp6p & disp4n) |
		      (disp6p & disp4p) | (disp6n & disp4n)) ;

endtask // f_8b10b_decode


