// =====================================================================
//  Fakturamaler — tjue oppsett. Hver mal er en ren funksjon som tar
//  visningsmodellen fra lagVisning() og returnerer HTML.
//
//  Malene eier sin egen CSS i app/faktura.css, klassenavn .inv-1 … .inv-20.
//  Dette er den ene tillatte CSS-en utenfor styles.css, av samme grunn
//  som rapport.css: dokumenter som skal skrives ut på A4 er ikke
//  grensesnitt, og skal ikke arve appens flater.
// =====================================================================

const esc = (s) => String(s == null ? "" : s).replace(/[&<>"]/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const pad = (n) => (n < 10 ? "0" + n : "" + n);
const dmy = (d) => pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear();
const iso = (d) => d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());

const MND = ["januar","februar","mars","april","mai","juni","juli","august","september","oktober","november","desember"];
const MNE = ["January","February","March","April","May","June","July","August","September","October","November","December"];
const LOK = { NOK:"nb-NO", SEK:"sv-SE", DKK:"da-DK", EUR:"de-DE", USD:"en-US", GBP:"en-GB", PKR:"en-PK" };

function belop(ore, valuta) {
  try {
    return new Intl.NumberFormat(LOK[valuta] || "nb-NO",
      { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format((ore || 0) / 100);
  } catch (e) { return ((ore || 0) / 100).toFixed(2); }
}


function hexA(hex,a){
  var h=(hex||"#126f69").replace("#","");
  if(h.length===3)h=h[0]+h[0]+h[1]+h[1]+h[2]+h[2];
  var n=parseInt(h,16);
  return "rgba("+((n>>16)&255)+","+((n>>8)&255)+","+(n&255)+","+a+")";
}
function A(lines){return lines.map(esc).join("<br>");}
function logo(v,cls){return v.seller.logo?'<img class="logo '+(cls||"")+'" src="'+v.seller.logo+'" alt="">':"";}
function sumRows(v){
  var r=[[v.t("Sum eks. mva","Subtotal"), v.f(v.net)]];
  if(Math.abs(v.discAmt)>0.004) r.push([v.t("Rabatt","Discount")+" "+v.disc+"%","−"+v.f(v.discAmt)]);
  var any=false;
  v.vatGroups.forEach(function(g){ if(g.rate>0){any=true;r.push([v.t("MVA","VAT")+" "+g.rate+" %", v.f(g.amt)]);} });
  if(!any) r.push([v.t("MVA","VAT")+" 0 %", v.f(0)]);
  if(Math.abs(v.roundAmt)>0.004) r.push([v.t("Avrunding","Rounding"), v.f(v.roundAmt)]);
  return r;
}
function sumDivs(v){
  return sumRows(v).map(function(x){return '<div><span>'+esc(x[0])+'</span><span class="num">'+x[1]+'</span></div>';}).join("");
}
function payLine(v){
  var p=v.pay,a=[];
  if(p.bank)a.push(esc(p.bank));
  if(p.account)a.push(v.t("Konto","Account")+" "+esc(p.account));
  if(p.iban)a.push("IBAN "+esc(p.iban));
  if(p.swift)a.push("SWIFT "+esc(p.swift));
  if(p.kid)a.push("KID "+esc(p.kid));
  return a.join(" · ");
}
function vatRows(v){
  return v.vatGroups.map(function(g){
    return "<tr><td>"+g.rate+" %</td><td class=\"r num\">"+v.f(g.base)+"</td><td class=\"r num\">"+v.f(g.amt)+"</td>"+
      "<td class=\"r num\">"+v.f(g.base+g.amt)+"</td></tr>";}).join("");
}
function q(n){ return (Math.round(n*100)/100).toString().replace(".",","); }

var T=[];
function reg(id,name,desc,fn){T.push({id:id,name:name,desc:desc,render:fn});}

/* ============ 1 Nordisk Minimal ============ */
reg(1,"Nordisk Minimal","Luftig, hårfine linjer, høyrestilte summer — norsk standard.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+" "+esc(i.u)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+i.vat+" %</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="hd"><div><div class="t">'+esc(v.title.split(" ")[0])+' <em>'+esc(v.title.split(" ").slice(1).join(" "))+'</em></div>'+logo(v)+
    '</div><div class="meta"><b>'+esc(v.number)+'</b>'+v.t("Fakturadato","Invoice date")+' '+v.dateStr+'<br>'+
    v.t("Forfall","Due")+' '+v.dueStr+'</div></div>'+
  '<div class="parties"><div><div class="lbl">'+v.t("Fra","From")+'</div><div class="pn">'+esc(v.seller.name)+'</div>'+A(v.seller.addr)+
    (v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</div>'+
    '<div><div class="lbl">'+v.t("Til","Bill to")+'</div><div class="pn">'+esc(v.buyer.name)+'</div>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+(v.buyer.org?'<br>'+v.t("Org.nr","Org. no.")+' '+esc(v.buyer.org):"")+'</div></div>'+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Antall","Qty")+
    '</th><th class="r">'+v.t("Pris","Unit price")+'</th><th class="r">'+v.t("MVA","VAT")+'</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft"><div>'+esc(v.seller.name)+'<br>'+esc(v.seller.email)+'<br>'+esc(v.seller.phone)+'</div>'+
    '<div>'+(payLine(v)||"&nbsp;")+'</div><div>'+esc(v.terms||"")+'</div></div>';
});

/* ============ 2 Ledger ============ */
reg(2,"Ledger","Beløpet øverst, betalingslenke, rolig tabell. Stripe-skolen.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  var ft=sumRows(v).map(function(x){return '<tr><td colspan="3" class="r">'+esc(x[0])+'</td><td class="r num">'+x[1]+'</td></tr>';}).join("");
  return '<div class="top2"><div><div class="t">'+esc(v.title)+'</div>'+logo(v)+'</div>'+
    '<div class="kv"><div><span>'+v.t("Fakturanummer","Invoice number")+'</span><b>'+esc(v.number)+'</b></div>'+
    '<div><span>'+v.t("Fakturadato","Date of issue")+'</span><b>'+v.dateLong+'</b></div>'+
    '<div><span>'+v.t("Forfallsdato","Date due")+'</span><b>'+v.dueLong+'</b></div>'+
    (v.seller.vat?'<div><span>'+v.t("Org.nr / MVA","Tax ID")+'</span><b>'+esc(v.seller.vat)+'</b></div>':"")+'</div></div>'+
  '<div class="cols"><div><b>'+esc(v.seller.name)+'</b><br>'+A(v.seller.addr)+'<br>'+esc(v.seller.email)+'</div>'+
    '<div><b>'+v.t("Fakturamottaker","Bill to")+'</b><br>'+esc(v.buyer.name)+'<br>'+A(v.buyer.addr)+
    (v.buyer.email?'<br>'+esc(v.buyer.email):"")+'</div></div>'+
  '<div class="hero">'+v.cf(v.total)+' '+v.t("forfaller","due")+' '+v.dueLong+'</div>'+
  (v.pay.link?'<a class="pay" href="'+esc(v.pay.link)+'">'+v.t("Betal på nett","Pay online")+'</a>':'<div class="pay">'+esc(payLine(v))+'</div>')+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Ant.","Qty")+
    '</th><th class="r">'+v.t("Enhetspris","Unit price")+'</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead>'+
    '<tbody>'+rows+'</tbody><tfoot>'+ft+'<tr><td colspan="3" class="r">'+v.t("Å betale","Amount due")+
    '</td><td class="r num">'+v.fc(v.total)+'</td></tr></tfoot></table>'+
  '<div class="pg">'+esc(v.number)+' · '+v.t("Side 1 av 1","Page 1 of 1")+'</div>';
});

/* ============ 3 Klassisk brevhode ============ */
reg(3,"Klassisk brevhode","Sentrert antikva, dobbel strek, formelt. Advokat og revisor.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"c num\">"+q(i.q)+" "+esc(i.u)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="lh"><h1>'+esc(v.seller.name)+'</h1><p>'+v.seller.addr.map(esc).join(" · ")+
    (v.seller.phone?" · "+esc(v.seller.phone):"")+(v.seller.email?" · "+esc(v.seller.email):"")+'</p></div>'+
  '<div class="t">'+esc(v.title)+'</div>'+
  '<div class="grid"><div><b>'+esc(v.buyer.name)+'</b><br>'+(v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
    '<dl><dt>'+v.t("Fakturanr.","Invoice no.")+'</dt><dd>'+esc(v.number)+'</dd>'+
    '<dt>'+v.t("Dato","Date")+'</dt><dd>'+v.dateStr+'</dd>'+
    '<dt>'+v.t("Forfall","Due")+'</dt><dd>'+v.dueStr+'</dd>'+
    (v.ourRef?'<dt>'+v.t("Vår ref.","Our ref.")+'</dt><dd>'+esc(v.ourRef)+'</dd>':"")+
    (v.theirRef?'<dt>'+v.t("Deres ref.","Your ref.")+'</dt><dd>'+esc(v.theirRef)+'</dd>':"")+'</dl></div>'+
  '<table><thead><tr><th>'+v.t("Spesifikasjon","Specification")+'</th><th class="c">'+v.t("Antall","Qty")+
    '</th><th class="r">'+v.t("Sats","Rate")+'</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Til betaling","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft">'+(payLine(v)||"")+(v.terms?'<br>'+esc(v.terms):"")+
    (v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</div>';
});

/* ============ 4 Eksport & Proforma ============ */
reg(4,"Eksport & Proforma","Rutenett med HS-kode, opprinnelse, REX og mottaker. Toll og frakt.",function(v){
  var x=v.seller.x||{};
  var rows=v.items.map(function(i){return "<tr><td class=\"c num\">"+q(i.q)+"</td><td class=\"c\">"+esc(i.u)+
    "</td><td>"+esc(i.d)+"</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  var extra="";
  for(var k=v.items.length;k<8;k++) extra+='<tr><td class="c">&nbsp;</td><td></td><td></td><td></td><td></td></tr>';
  return '<div class="bar"><h1>'+esc(v.title)+'<small>'+esc(v.seller.name)+'</small></h1>'+logo(v)+
    '<div style="text-align:right;font-size:8pt">'+A(v.seller.addr)+'<br>'+esc(v.seller.phone)+' · '+esc(v.seller.email)+'</div></div>'+
  '<div class="gr">'+
    '<div><b>'+v.t("Fakturanr.","Invoice no.")+'</b><span>'+esc(v.number)+'</span></div>'+
    '<div><b>'+v.t("Fakturadato","Invoice date")+'</b><span>'+v.dateStr+'</span></div>'+
    '<div><b>'+v.t("Gjelder","Invoice of")+'</b><span>'+esc(v.theirRef||v.t("Varer","Goods"))+'</span></div>'+
    '<div><b>REX '+v.t("registreringsnr.","registration no.")+'</b><span>'+esc(x.rex||"—")+'</span></div>'+
    '<div><b>National Tax No</b><span>'+esc(x.ntn||"—")+'</span></div>'+
    '<div><b>H.S. Code</b><span>'+esc(x.hs||"—")+'</span></div>'+
    '<div><b>'+v.t("Opprinnelsesland","Country of origin")+'</b><span>'+esc(x.origin||"—")+'</span></div>'+
    '<div><b>'+v.t("Vilkår","Terms")+'</b><span>'+esc(x.terms||"—")+'</span></div>'+
    '<div><b>'+v.t("Forfall","Due")+'</b><span>'+v.dueStr+'</span></div></div>'+
  '<div class="cons"><div><b>Consignee</b>'+esc(v.buyer.name)+'<br>'+(v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
    '<div><b>'+v.t("Merking","Marks")+'</b>'+esc(v.ourRef||v.number)+'<br><b style="margin-top:2mm">'+v.t("Valuta","Currency")+'</b>'+v.cur+'</div></div>'+
  '<table><thead><tr><th style="width:14%">'+v.t("Antall","Quantity")+'</th><th style="width:12%">'+v.t("Enhet","Unit")+
    '</th><th>'+v.t("Varebeskrivelse","Description of goods")+'</th><th style="width:16%">'+v.t("Pris pr. enhet","Per unit")+
    '</th><th style="width:18%">'+v.t("Totalbeløp","Total amount")+'</th></tr></thead><tbody>'+rows+extra+'</tbody>'+
    '<tfoot><tr><td class="c num">'+q(v.qtyTotal)+'</td><td></td><td class="r">'+v.t("TOTALT","TOTAL")+' '+v.cur+
    '</td><td></td><td class="r num">'+v.f(v.total)+'</td></tr></tfoot></table>'+
  '<div class="decl">'+esc(v.legal||"")+(v.terms?'<br>'+esc(v.terms):"")+(v.pay.note?'<br>'+esc(v.pay.note):"")+'</div>'+
  '<div class="sig"><div>'+v.t("Signatur avsender","Signature of exporter")+'</div><div>'+v.t("Stempel","Company stamp")+'</div></div>';
});

/* ============ 5 Mørk sidekolonne ============ */
reg(5,"Mørk sidekolonne","Mørk skinne til venstre med avsender og sum. Byrå og studio.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="rail">'+logo(v)+'<h1>'+esc(v.seller.name)+'</h1><div class="ac"></div>'+
    '<p>'+A(v.seller.addr)+'</p><p>'+esc(v.seller.email)+'<br>'+esc(v.seller.phone)+'</p>'+
    (v.seller.vat?'<div class="k">'+v.t("Org.nr","Tax ID")+'</div><p>'+esc(v.seller.vat)+'</p>':"")+
    (payLine(v)?'<div class="k">'+v.t("Betaling","Payment")+'</div><p>'+payLine(v).split(" · ").join("<br>")+'</p>':"")+
    '<div class="big">'+v.fc(v.total)+'</div></div>'+
  '<div class="main"><div class="t">'+esc(v.title)+'</div>'+
    '<div class="meta"><div><div class="k">'+v.t("Nummer","Number")+'</div><b>'+esc(v.number)+'</b></div>'+
    '<div><div class="k">'+v.t("Dato","Date")+'</div><b>'+v.dateStr+'</b></div>'+
    '<div><div class="k">'+v.t("Forfall","Due")+'</div><b>'+v.dueStr+'</b></div></div>'+
    '<div class="meta" style="grid-template-columns:1fr"><div><div class="k">'+v.t("Faktureres","Billed to")+'</div>'+
    '<b>'+esc(v.buyer.name)+'</b><br>'+A(v.buyer.addr)+'</div></div>'+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Ant.","Qty")+
    '</th><th class="r">'+v.t("Pris","Rate")+'</th><th class="r">'+v.t("Sum","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft">'+esc(v.terms||"")+'</div></div>';
});

/* ============ 6 Fargebånd ============ */
reg(6,"Fargebånd","Kraftig farget topp med nøkkeltall i stripe under. Handel og detalj.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+" "+esc(i.u)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+i.vat+" %</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="band"><h1>'+esc(v.title).toUpperCase()+'</h1><div class="co"><b>'+esc(v.seller.name)+'</b>'+
    A(v.seller.addr)+'<br>'+esc(v.seller.email)+'</div></div>'+
  '<div class="strip"><div><span>'+v.t("Nummer","Number")+'</span><b>'+esc(v.number)+'</b></div>'+
    '<div><span>'+v.t("Dato","Date")+'</span><b>'+v.dateStr+'</b></div>'+
    '<div><span>'+v.t("Forfall","Due")+'</span><b>'+v.dueStr+'</b></div>'+
    '<div><span>'+v.t("Å betale","Total")+'</span><b>'+v.fc(v.total)+'</b></div></div>'+
  '<div class="bd"><div class="to"><div class="k">'+v.t("Faktureres til","Bill to")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
  '<table><thead><tr><th>'+v.t("Vare eller tjeneste","Item")+'</th><th class="r">'+v.t("Antall","Qty")+
    '</th><th class="r">'+v.t("Pris","Price")+'</th><th class="r">'+v.t("MVA","VAT")+'</th><th class="r">'+v.t("Sum","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft">'+(payLine(v)||"")+(v.terms?' — '+esc(v.terms):"")+'</div></div>';
});

/* ============ 7 Kompakt kvittering ============ */
reg(7,"Kompakt kvittering","Smal remse i skrivemaskinsnitt. Kontant, kiosk, småsalg.",function(v){
  var rows=v.items.map(function(i){return '<div class="it"><div class="d">'+esc(i.d)+
    '<small>'+q(i.q)+(i.u?" "+esc(i.u):"")+' × '+v.f(i.p)+'</small></div><div class="num">'+v.f(i.sum)+'</div></div>';}).join("");
  var s=sumRows(v).map(function(x){return '<div class="kv"><span>'+esc(x[0])+'</span><span class="num">'+x[1]+'</span></div>';}).join("");
  return '<div class="slip"><div class="hd"><h1>'+esc(v.seller.name)+'</h1><p>'+v.seller.addr.map(esc).join(", ")+
    (v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</p></div><div class="rule"></div>'+
    '<div class="kv"><span>'+esc(v.title)+'</span><span>'+esc(v.number)+'</span></div>'+
    '<div class="kv"><span>'+v.t("Dato","Date")+'</span><span>'+v.dateStr+'</span></div>'+
    '<div class="kv"><span>'+v.t("Forfall","Due")+'</span><span>'+v.dueStr+'</span></div>'+
    '<div class="kv"><span>'+v.t("Kunde","Customer")+'</span><span>'+esc(v.buyer.name)+'</span></div>'+
    '<div class="rule"></div>'+rows+'<div class="rule"></div>'+s+
    '<div class="tot"><span>'+v.t("SUM","TOTAL")+'</span><span class="num">'+v.f(v.total)+' '+v.cur+'</span></div>'+
    '<div class="rule"></div><div class="stamp">'+esc(v.terms||v.t("Takk for handelen","Thank you"))+'</div>'+
    '<div class="bars"></div></div>';
});

/* ============ 8 Datatabell ============ */
reg(8,"Datatabell","Tett, stripete rader og MVA-oppsummering. Abonnement og mange linjer.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+"</td><td>"+esc(i.u)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+i.vat+" %</td><td class=\"r num\">"+
    v.f(i.sum*i.vat/100)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="hd"><div><h1>'+esc(v.title)+'</h1><div class="muted">'+esc(v.seller.name)+' · '+v.period+'</div></div>'+
    '<div class="m">'+v.t("Fakturanummer","Invoice number")+': <b>'+esc(v.number)+'</b><br>'+
    v.t("Fakturadato","Invoice date")+': <b>'+v.dateStr+'</b><br>'+v.t("Forfallsdato","Due date")+': <b>'+v.dueStr+
    '</b><br><b style="font-size:11pt">'+v.fc(v.total)+'</b></div></div>'+
  '<div class="three"><div><div class="k">'+v.t("Solgt av","Sold by")+'</div>'+esc(v.seller.name)+'<br>'+A(v.seller.addr)+
    (v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</div>'+
    '<div><div class="k">'+v.t("Solgt til","Sold to")+'</div>'+esc(v.buyer.name)+'<br>'+A(v.buyer.addr)+'</div>'+
    '<div><div class="k">'+v.t("Referanser","References")+'</div>'+
    (v.ourRef?v.t("Vår ref","Our ref")+": "+esc(v.ourRef)+"<br>":"")+
    (v.theirRef?v.t("Deres ref","Your ref")+": "+esc(v.theirRef)+"<br>":"")+
    (v.delivery?v.t("Levert","Delivered")+": "+esc(v.delivery):"")+'</div></div>'+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Ant.","Qty")+'</th><th>'+v.t("Enhet","Unit")+
    '</th><th class="r">'+v.t("Pris","Price")+'</th><th class="r">'+v.t("Sats","Rate")+'</th><th class="r">'+v.t("MVA","VAT")+
    '</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="grids"><table class="vt"><thead><tr><th>'+v.t("Sats","Rate")+'</th><th class="r">'+v.t("Grunnlag","Base")+
    '</th><th class="r">'+v.t("MVA","VAT")+'</th><th class="r">'+v.t("Sum","Total")+'</th></tr></thead><tbody>'+vatRows(v)+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Amount due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div></div>'+
  '<div class="ft"><div>'+esc(v.seller.name)+'</div><div>'+esc(v.seller.email)+'</div><div>'+esc(payLine(v))+'</div><div>'+esc(v.terms||"")+'</div></div>';
});

/* ============ 9 Diagonal aksent ============ */
reg(9,"Diagonal aksent","Skrå fargekile og sort beløpsmerke. Ung, teknisk profil.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+" "+esc(i.u)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="wedge"></div><div class="wedge2"></div><div class="in">'+
    '<h1>'+esc(v.title)+'</h1><div class="sub">'+esc(v.number)+' · '+v.dateStr+'</div>'+
    '<div class="who"><div><div class="k">'+v.t("Fra","From")+'</div><b>'+esc(v.seller.name)+'</b><br>'+A(v.seller.addr)+
      '<br>'+esc(v.seller.email)+'</div>'+
      '<div><div class="k">'+v.t("Til","To")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+A(v.buyer.addr)+'</div>'+
      '<div class="badge"><span>'+v.t("Å betale innen","Due by")+' '+v.dueStr+'</span><b>'+v.fc(v.total)+'</b></div></div>'+
  '<table><thead><tr><th>'+v.t("Leveranse","Deliverable")+'</th><th class="r">'+v.t("Antall","Qty")+
    '</th><th class="r">'+v.t("Pris","Rate")+'</th><th class="r">'+v.t("Sum","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Totalt","Total")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft"><span>'+esc(payLine(v))+'</span><span>'+esc(v.terms||"")+'</span></div></div>';
});

/* ============ 10 Typografisk XL ============ */
reg(10,"Typografisk XL","Fakturanummeret er selve grafikken. Få linjer, stor virkning.",function(v){
  var rows=v.items.map(function(i){return '<div class="li"><div><b>'+esc(i.d)+'</b><small>'+q(i.q)+
    (i.u?" "+esc(i.u):"")+' × '+v.f(i.p)+(i.vat?' · '+i.vat+' % '+v.t("mva","VAT"):"")+'</small></div>'+
    '<div class="amt">'+v.f(i.sum)+'</div></div>';}).join("");
  return '<div class="xl">'+esc(v.number)+'</div><div class="xls">'+esc(v.title)+'</div>'+
  '<div class="cols"><div><div class="k">'+v.t("Fra","From")+'</div>'+esc(v.seller.name)+'<br>'+A(v.seller.addr)+'</div>'+
    '<div><div class="k">'+v.t("Til","To")+'</div>'+esc(v.buyer.name)+'<br>'+A(v.buyer.addr)+'</div>'+
    '<div><div class="k">'+v.t("Dato","Date")+'</div>'+v.dateStr+'<div class="k" style="margin-top:4mm">'+
      v.t("Forfall","Due")+'</div>'+v.dueStr+'</div>'+
    '<div><div class="k">'+v.t("Betaling","Payment")+'</div>'+(payLine(v)||esc(v.seller.email)).split(" · ").join("<br>")+'</div></div>'+
  rows+
  '<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><b>'+v.fc(v.total)+'</b></div>'+
  '<div class="ft">'+esc(v.terms||"")+' '+esc(v.legal||"")+'</div>';
});

/* ============ 11 Split 50/50 ============ */
reg(11,"Split","Grå kolonne med fakta, hvit kolonne med linjer. Rolig og lesbar.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="l">'+logo(v)+'<div class="blk"><div class="k">'+v.t("Avsender","From")+'</div><b>'+esc(v.seller.name)+
    '</b><br>'+A(v.seller.addr)+'<br>'+esc(v.seller.email)+'<br>'+esc(v.seller.phone)+
    (v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</div>'+
    '<div class="blk"><div class="k">'+v.t("Mottaker","Bill to")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
    '<div class="blk"><div class="k">'+v.t("Betaling","Payment")+'</div>'+(payLine(v)||"—").split(" · ").join("<br>")+'</div>'+
    '<div class="due"><div class="k">'+v.t("Å betale innen","Due by")+' '+v.dueStr+'</div><b>'+v.fc(v.total)+'</b></div></div>'+
  '<div class="r2"><h1>'+esc(v.title)+'</h1>'+
    '<div class="blk" style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:6mm">'+
    '<div><div class="k">'+v.t("Nummer","Number")+'</div><b>'+esc(v.number)+'</b></div>'+
    '<div><div class="k">'+v.t("Dato","Date")+'</div><b>'+v.dateStr+'</b></div>'+
    '<div><div class="k">'+v.t("Referanse","Reference")+'</div><b>'+esc(v.theirRef||v.ourRef||"—")+'</b></div></div>'+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Ant.","Qty")+
    '</th><th class="r">'+v.t("Pris","Price")+'</th><th class="r">'+v.t("Sum","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Totalt","Total")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft">'+esc(v.terms||"")+'</div></div>';
});

/* ============ 12 Opphold & reise ============ */
reg(12,"Opphold og reise","Dato per linje, avgiftstabell og betalingsoversikt. Hotell og transport.",function(v){
  var rows=v.items.map(function(i,ix){
    var d=new Date(v.date.getTime()); d.setDate(d.getDate()+ix);
    return "<tr><td class=\"num\">"+dmy(d)+"</td><td>"+esc(i.d)+"</td><td class=\"c num\">"+q(i.q)+
    "</td><td class=\"c num\">"+i.vat+" %</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="hd"><div><h1>'+esc(v.title)+'</h1><div class="muted" style="font-size:8.5pt">'+
    v.t("Original","Original")+' · '+esc(v.number)+' · '+v.dateStr+'</div></div>'+
    '<div class="est"><b>'+esc(v.seller.name)+'</b>'+A(v.seller.addr)+'<br>'+esc(v.seller.phone)+
    (v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</div></div>'+
  '<div class="det"><div><div class="k">'+v.t("Kunde","Client")+'</div>'+esc(v.buyer.name)+'</div>'+
    '<div><div class="k">'+v.t("Kundenr.","Client no.")+'</div>'+esc(v.buyer.org||"—")+'</div>'+
    '<div><div class="k">'+v.t("Referanse","Reference")+'</div>'+esc(v.theirRef||v.ourRef||"—")+'</div>'+
    '<div><div class="k">'+v.t("Periode","Stay")+'</div>'+esc(v.delivery||v.dateStr)+'</div></div>'+
  '<table><thead><tr><th style="width:20mm">'+v.t("Dato","Date")+'</th><th>'+v.t("Beskrivelse","Description")+
    '</th><th class="c">'+v.t("Ant.","Qty")+'</th><th class="c">'+v.t("Sats","Rate")+'</th><th class="r">'+
    v.t("Pris","Unit")+'</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="totals">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<table class="vat"><thead><tr><th>'+v.t("Sats","Rate")+'</th><th class="r">'+v.t("Grunnlag","Net")+
    '</th><th class="r">'+v.t("Avgift","Tax")+'</th><th class="r">'+v.t("Sum","Total")+'</th></tr></thead><tbody>'+vatRows(v)+'</tbody></table>'+
  '<div class="pay"><div class="k">'+v.t("Betaling","Payments")+'</div>'+(payLine(v)||esc(v.pay.note||"—"))+'</div>'+
  '<div class="ft">'+esc(v.legal||v.terms||"")+'</div>';
});

/* ============ 13 Timer & prosjekt ============ */
reg(13,"Timer og prosjekt","Periode, prosjektbolker og timer × sats. Konsulent og advokat.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+"</td><td>"+
    esc(i.u)+"</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  var hrs=v.items.reduce(function(a,b){return a+(/^(t|time|timer|hr|hrs|hour|hours)$/i.test((b.u||"").trim())?b.q:0);},0);
  return '<div class="hd"><div><h1>'+esc(v.seller.name)+'</h1><span class="per">'+esc(v.title)+' · '+v.period+'</span></div>'+
    '<div class="m">'+v.t("Nr.","No.")+' <b>'+esc(v.number)+'</b><br>'+v.t("Dato","Date")+' <b>'+v.dateStr+'</b><br>'+
    v.t("Forfall","Due")+' <b>'+v.dueStr+'</b></div></div>'+
  '<div class="who"><div><div class="k">'+v.t("Fakturamottaker","Bill to")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
    '<div><div class="k">'+v.t("Oppdrag","Engagement")+'</div>'+esc(v.theirRef||"—")+
    '<div class="k" style="margin-top:3mm">'+v.t("Ansvarlig","Responsible")+'</div>'+esc(v.ourRef||"—")+'</div></div>'+
  '<div class="proj"><h3><span>'+v.t("Utført arbeid","Work performed")+'</span><span class="num">'+q(hrs)+' '+
    v.t("timer","hrs")+'</span></h3>'+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Antall","Qty")+'</th><th>'+
    v.t("Enhet","Unit")+'</th><th class="r">'+v.t("Sats","Rate")+'</th><th class="r">'+v.t("Beløp","Amount")+
    '</th></tr></thead><tbody>'+rows+'</tbody><tfoot><tr><td>'+v.t("Sum honorar","Total fees")+'</td><td colspan="3"></td>'+
    '<td class="r num">'+v.f(v.net)+'</td></tr></tfoot></table></div>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft"><div>'+A(v.seller.addr)+'</div><div>'+esc(v.seller.email)+'<br>'+esc(v.seller.phone)+'</div>'+
    '<div>'+esc(payLine(v))+'</div></div>';
});

/* ============ 14 Kontinental ============ */
reg(14,"Kontinental","Brevformat med avsenderlinje, ingress og streng bunntekst. DE og FR.",function(v){
  var rows=v.items.map(function(i,ix){return "<tr><td class=\"c\">"+(ix+1)+"</td><td>"+esc(i.d)+"</td><td class=\"r num\">"+
    q(i.q)+" "+esc(i.u)+"</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+i.vat+" %</td><td class=\"r num\">"+
    v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="sender">'+esc(v.seller.name)+' · '+v.seller.addr.map(esc).join(", ")+'</div>'+
  '<div class="addr"><b>'+esc(v.buyer.name)+'</b><br>'+(v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
  '<div class="meta"><h1>'+esc(v.title)+' '+esc(v.number)+'</h1>'+
    '<dl><dt>'+v.t("Dato","Date")+'</dt><dd>'+v.dateLong+'</dd>'+
    '<dt>'+v.t("Kundenr.","Customer no.")+'</dt><dd>'+esc(v.buyer.org||"—")+'</dd>'+
    '<dt>'+v.t("Deres ref.","Your ref.")+'</dt><dd>'+esc(v.theirRef||"—")+'</dd></dl></div>'+
  '<div class="intro">'+esc(v.intro||v.t("Vi tillater oss å fakturere følgende:","We hereby invoice the following:"))+'</div>'+
  '<table><thead><tr><th class="c">'+v.t("Nr.","No.")+'</th><th>'+v.t("Ytelse","Description")+'</th><th class="r">'+
    v.t("Mengde","Qty")+'</th><th class="r">'+v.t("Enhetspris","Unit price")+'</th><th class="r">'+v.t("Sats","VAT")+
    '</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Fakturabeløp","Invoice total")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="close">'+esc(v.terms||v.t("Beløpet bes innbetalt innen "+v.dueStr+".","Payment is due by "+v.dueStr+"."))+'</div>'+
  '<div class="ft"><div>'+esc(v.seller.name)+'<br>'+A(v.seller.addr)+'</div>'+
    '<div>'+esc(v.seller.phone)+'<br>'+esc(v.seller.email)+'</div>'+
    '<div>'+(v.seller.org?v.t("Org.nr","Reg. no.")+" "+esc(v.seller.org)+"<br>":"")+esc(v.seller.vat||"")+
    '<br>'+esc(payLine(v))+'</div></div>';
});

/* ============ 15 Teknisk boks ============ */
reg(15,"Teknisk boks","Alt i rammer, monospace tall. Verksted, logistikk, industri.",function(v){
  var rows=v.items.map(function(i,ix){return "<tr><td>"+pad(ix+1)+"</td><td>"+esc(i.d)+"</td><td class=\"r num\">"+
    q(i.q)+"</td><td>"+esc(i.u)+"</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  var x=v.seller.x||{};
  return '<div class="b"><div class="bc hdgrid"><div><h1>'+esc(v.title)+'</h1><div style="margin-top:2mm">'+esc(v.seller.name)+
    '<br>'+A(v.seller.addr)+'</div></div>'+
    '<div class="kv"><span>NO</span><b>'+esc(v.number)+'</b><span>DATE</span><b>'+iso(v.date)+'</b>'+
    '<span>DUE</span><b>'+iso(v.dueDate)+'</b><span>CUR</span><b>'+v.cur+'</b>'+
    (x.hs?'<span>HS</span><b>'+esc(x.hs)+'</b>':"")+'</div></div></div>'+
  '<div class="b"><div class="bt">'+v.t("Mottaker","Consignee")+'</div><div class="bc">'+esc(v.buyer.name)+'<br>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+(v.buyer.org?'<br>ORG '+esc(v.buyer.org):"")+'</div></div>'+
  '<div class="b"><div class="bt">'+v.t("Linjer","Line items")+'</div><div class="bc" style="padding:0">'+
    '<table><thead><tr><th style="width:10mm">#</th><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+
    v.t("Ant","Qty")+'</th><th style="width:16mm">'+v.t("Enh","Unit")+'</th><th class="r">'+v.t("Pris","Price")+
    '</th><th class="r">'+v.t("Sum","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table></div></div>'+
  '<div class="grid2"><div class="b"><div class="bt">'+v.t("Betaling","Payment")+'</div><div class="bc">'+
    (payLine(v)||"—").split(" · ").join("<br>")+(v.pay.note?'<br><br>'+esc(v.pay.note):"")+'</div></div>'+
    '<div class="b"><div class="bt">'+v.t("Oppgjør","Settlement")+'</div><div class="bc sum">'+sumDivs(v)+
    '<div class="tot"><span>TOTAL</span><span class="num">'+v.f(v.total)+' '+v.cur+'</span></div></div></div></div>'+
  '<div class="ft">'+esc(v.terms||"")+' '+esc(v.legal||"")+'</div>';
});

/* ============ 16 Kortstil ============ */
reg(16,"Kortstil","Mykt kort med skygge og pillemerke. SaaS og abonnement.",function(v){
  var rows=v.items.map(function(i){return '<div class="it"><div><b>'+esc(i.d)+'</b><small>'+q(i.q)+
    (i.u?" "+esc(i.u):"")+' × '+v.f(i.p)+'</small></div><div class="num">'+v.f(i.sum)+'</div></div>';}).join("");
  return '<div class="card"><div class="hd"><div><h1>'+esc(v.seller.name)+'</h1>'+
    '<span class="pill">'+esc(v.title)+' '+esc(v.number)+'</span></div>'+
    '<div class="amt"><span>'+v.t("Å betale innen","Due")+' '+v.dueStr+'</span><b>'+v.fc(v.total)+'</b></div></div>'+
  '<div class="who"><div><div class="k">'+v.t("Faktureres","Billed to")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+
    A(v.buyer.addr)+(v.buyer.email?'<br>'+esc(v.buyer.email):"")+'</div>'+
    '<div><div class="k">'+v.t("Detaljer","Details")+'</div>'+v.t("Fakturadato","Issued")+': '+v.dateStr+'<br>'+
    v.t("Periode","Period")+': '+esc(v.delivery||v.period)+(v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</div></div>'+
  rows+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Amount due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft"><span>'+esc(v.pay.link?v.t("Betal på nett: ","Pay online: ")+v.pay.link:payLine(v))+'</span>'+
    '<span>'+esc(v.seller.email)+'</span></div></div>';
});

/* ============ 17 Redaksjonell serif ============ */
reg(17,"Redaksjonell","Magasinaktig antikva med ingress og luft. Design, arkitekt, foto.",function(v){
  var rows=v.items.map(function(i){return '<div class="it"><div><b>'+esc(i.d)+'</b><small>'+q(i.q)+
    (i.u?" "+esc(i.u):"")+' × '+v.f(i.p)+'</small></div><div class="amt">'+v.f(i.sum)+'</div></div>';}).join("");
  return '<div class="kicker">'+esc(v.seller.name)+' — '+esc(v.title)+' '+esc(v.number)+'</div>'+
  '<h1>'+esc(v.buyer.name)+'</h1>'+
  '<div class="lead">'+esc(v.intro||v.t("Faktura for arbeid utført i perioden "+v.period+". Beløpet forfaller "+v.dueStr+".",
    "Invoice for work delivered in "+v.period+". Payment is due "+v.dueStr+"."))+'</div>'+
  '<div class="cols"><div><div class="k">'+v.t("Fra","From")+'</div>'+esc(v.seller.name)+'<br>'+A(v.seller.addr)+
    '<br>'+esc(v.seller.email)+'</div>'+
    '<div><div class="k">'+v.t("Til","To")+'</div>'+esc(v.buyer.name)+'<br>'+(v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
    '<div><div class="k">'+v.t("Dato","Date")+'</div>'+v.dateLong+'<br><br><div class="k">'+v.t("Forfall","Due")+'</div>'+v.dueLong+'</div></div>'+
  rows+
  '<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><b>'+v.fc(v.total)+'</b></div>'+
  '<div class="ft"><div>'+esc(payLine(v))+'</div><div>'+esc(v.seller.vat||"")+'</div><div>'+esc(v.terms||"")+'</div></div>';
});

/* ============ 18 Stempel ============ */
reg(18,"Stempel","Skrivemaskin, doble streker og stempelmerke. Klassisk og folkelig.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+" "+esc(i.u)+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  var st=v.type==="kreditnota"?[v.t("KREDIT","CREDIT"),""]:(v.type==="proforma"?["PROFORMA",""]:
    [v.t("UBETALT","UNPAID"),v.t("forfaller","due")+" "+v.dueStr]);
  return '<div class="hd"><h1>'+esc(v.title)+'</h1><div class="co">'+esc(v.seller.name)+'<br>'+A(v.seller.addr)+
    '<br>'+esc(v.seller.phone)+'</div></div><div class="rule2"></div>'+
  '<div class="who"><div><div class="k">'+v.t("Til","To")+'</div>'+esc(v.buyer.name)+'<br>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
    '<div><div class="k">'+v.t("Opplysninger","Details")+'</div>'+v.t("Nr.","No.")+' '+esc(v.number)+'<br>'+
    v.t("Dato","Date")+' '+v.dateStr+'<br>'+v.t("Forfall","Due")+' '+v.dueStr+
    (v.theirRef?'<br>'+v.t("Ref.","Ref.")+' '+esc(v.theirRef):"")+'</div></div>'+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Antall","Qty")+
    '</th><th class="r">'+v.t("Pris","Price")+'</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("SUM","TOTAL")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="stampbox"><b>'+esc(st[0])+'</b><span>'+esc(st[1])+'</span></div>'+
  '<div class="ft">'+esc(payLine(v))+(v.terms?'<br>'+esc(v.terms):"")+'</div>';
});

/* ============ 19 Bygg & prosjekt ============ */
reg(19,"Bygg og prosjekt","Kontrakt, fremdrift og innestående. Entreprenør og håndverk.",function(v){
  var contract=v.items.reduce(function(a,b){return a+b.sum;},0);
  var rows=v.items.map(function(i){
    var pct=Math.min(100,Math.round(i.q*100)/1);
    return "<tr><td>"+esc(i.d)+'<div class="prog"><i style="width:'+Math.min(100,Math.abs(i.q)*10)+'%"></i></div></td>'+
    "<td class=\"r num\">"+q(i.q)+" "+esc(i.u)+"</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+
    i.vat+" %</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="hd"><div><h1>'+esc(v.seller.name)+'</h1><small>'+esc(v.title)+'</small></div>'+
    '<div class="m">'+v.t("Fakturanr.","Invoice no.")+' <b>'+esc(v.number)+'</b><br>'+v.t("Dato","Date")+' <b>'+v.dateStr+
    '</b><br>'+v.t("Forfall","Due")+' <b>'+v.dueStr+'</b></div></div>'+
  '<div class="strip"><div><div class="k">'+v.t("Prosjekt","Project")+'</div>'+esc(v.theirRef||"—")+'</div>'+
    '<div><div class="k">'+v.t("Byggherre","Client")+'</div>'+esc(v.buyer.name)+'</div>'+
    '<div><div class="k">'+v.t("Vår ref.","Our ref.")+'</div>'+esc(v.ourRef||"—")+'</div>'+
    '<div><div class="k">'+v.t("Periode","Period")+'</div>'+esc(v.delivery||v.period)+'</div>'+
    '<div><div class="k">'+v.t("Kontraktsum","Contract")+'</div><span class="num">'+v.f(contract)+'</span></div></div>'+
  '<div class="who"><div><div class="k">'+v.t("Faktureres til","Bill to")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+
    A(v.buyer.addr)+(v.buyer.org?'<br>'+v.t("Org.nr","Org. no.")+' '+esc(v.buyer.org):"")+'</div>'+
    '<div><div class="k">'+v.t("Utførende","Contractor")+'</div><b>'+esc(v.seller.name)+'</b><br>'+A(v.seller.addr)+
    (v.seller.vat?'<br>'+esc(v.seller.vat):"")+'</div></div>'+
  '<table><thead><tr><th>'+v.t("Post og fremdrift","Item and progress")+'</th><th class="r">'+v.t("Mengde","Qty")+
    '</th><th class="r">'+v.t("Enhetspris","Unit price")+'</th><th class="r">'+v.t("MVA","VAT")+'</th><th class="r">'+
    v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft"><div>'+esc(v.seller.email)+'</div><div>'+esc(v.seller.phone)+'</div><div>'+esc(payLine(v))+
    '</div><div>'+esc(v.terms||"")+'</div></div>';
});

/* ============ 20 EHF / Offentlig ============ */
reg(20,"EHF og offentlig","Strenge felt, referansekrav, KID og giroblokk i bunn. Offentlig sektor.",function(v){
  var rows=v.items.map(function(i,ix){return "<tr><td>"+(ix+1)+"</td><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+
    "</td><td>"+esc(i.u)+"</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+i.vat+" %</td><td class=\"r num\">"+
    v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="hd"><div><h1>'+esc(v.title)+'</h1><div class="co">'+esc(v.seller.name)+'<br>'+A(v.seller.addr)+
    '<br>'+esc(v.seller.email)+' · '+esc(v.seller.phone)+
    (v.seller.vat?'<br><b>'+esc(v.seller.vat)+'</b>':"")+'</div></div>'+
    '<div class="facts">'+
    '<div><span>'+v.t("Fakturanummer","Invoice number")+'</span><b>'+esc(v.number)+'</b></div>'+
    '<div><span>'+v.t("Fakturadato","Invoice date")+'</span><b>'+v.dateStr+'</b></div>'+
    '<div><span>'+v.t("Forfallsdato","Due date")+'</span><b>'+v.dueStr+'</b></div>'+
    '<div><span>'+v.t("Leveringsdato","Delivery date")+'</span><b>'+esc(v.delivery||v.dateStr)+'</b></div>'+
    '<div><span>'+v.t("Valuta","Currency")+'</span><b>'+v.cur+'</b></div>'+
    '<div><span>'+v.t("Å betale","Total due")+'</span><b>'+v.f(v.total)+'</b></div></div></div>'+
  '<div class="who"><div><div class="k">'+v.t("Fakturamottaker","Invoice recipient")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+(v.buyer.org?'<br>'+v.t("Org.nr","Org. no.")+' '+esc(v.buyer.org):"")+'</div>'+
    '<div><div class="k">'+v.t("Leveringsadresse","Delivery address")+'</div>'+esc(v.buyer.name)+'<br>'+A(v.buyer.addr)+'</div></div>'+
  '<div class="refs"><div><div class="k">'+v.t("Deres referanse","Your reference")+'</div>'+esc(v.theirRef||"—")+'</div>'+
    '<div><div class="k">'+v.t("Vår referanse","Our reference")+'</div>'+esc(v.ourRef||"—")+'</div>'+
    '<div><div class="k">'+v.t("Bestillingsnr.","Order no.")+'</div>'+esc(v.theirRef||"—")+'</div>'+
    '<div><div class="k">'+v.t("Betalingsbetingelser","Payment terms")+'</div>'+v.dueDays+' '+v.t("dager","days")+'</div></div>'+
  '<table><thead><tr><th style="width:8mm">#</th><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+
    v.t("Antall","Qty")+'</th><th style="width:16mm">'+v.t("Enhet","Unit")+'</th><th class="r">'+v.t("Pris","Price")+
    '</th><th class="r">'+v.t("Sats","VAT")+'</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="grid2"><table class="vt"><thead><tr><th>'+v.t("Sats","Rate")+'</th><th class="r">'+v.t("Grunnlag","Base")+
    '</th><th class="r">'+v.t("MVA","VAT")+'</th><th class="r">'+v.t("Sum","Total")+'</th></tr></thead><tbody>'+vatRows(v)+'</tbody></table>'+
    '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.f(v.total)+' '+v.cur+'</span></div></div></div>'+
  '<div class="giro"><div><div class="k">'+v.t("Betales til","Pay to")+'</div>'+esc(v.seller.name)+'<br>'+
    (v.pay.bank?esc(v.pay.bank)+'<br>':"")+(v.pay.iban?'IBAN '+esc(v.pay.iban)+'<br>':"")+(v.pay.swift?'SWIFT '+esc(v.pay.swift):"")+'</div>'+
    '<div><div class="k">'+v.t("Kontonummer","Account")+'</div><b>'+esc(v.pay.account||"—")+'</b>'+
    '<div class="k" style="margin-top:2mm">KID</div><b>'+esc(v.pay.kid||"—")+'</b></div>'+
    '<div><div class="k">'+v.t("Beløp","Amount")+'</div><b style="font-size:13pt">'+v.f(v.total)+'</b><br>'+v.cur+
    '<div class="k" style="margin-top:2mm">'+v.t("Forfall","Due")+'</div><b>'+v.dueStr+'</b></div></div>';
});

/* ============ 21 Klinikk og bemanning ============ */
reg(21,"Klinikk og bemanning","Rolig oppsett med vaktoversikt i myke flater. Bemanning, helse og omsorg.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+" "+esc(i.u||v.t("t","hrs"))+
    "</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  var timer=v.items.reduce(function(a,b){return a+b.q;},0);
  return '<div class="band"><div class="cross" aria-hidden="true"></div><div><span class="tag">'+esc(v.title)+'</span>'+
    '<h1>'+esc(v.seller.name)+'</h1></div>'+
    '<div class="meta"><div><span>'+v.t("Fakturanr.","Invoice no.")+'</span><b>'+esc(v.number)+'</b></div>'+
    '<div><span>'+v.t("Dato","Date")+'</span><b>'+v.dateStr+'</b></div>'+
    '<div><span>'+v.t("Forfall","Due")+'</span><b>'+v.dueStr+'</b></div></div></div>'+
  '<div class="bd">'+
  '<div class="who"><div><div class="k">'+v.t("Fakturamottaker","Bill to")+'</div><b>'+esc(v.buyer.name)+'</b><br>'+
    (v.buyer.att?esc(v.buyer.att)+'<br>':"")+A(v.buyer.addr)+'</div>'+
    '<div><div class="k">'+v.t("Periode","Period")+'</div>'+esc(v.delivery||v.period)+
    '<div class="k" style="margin-top:3mm">'+v.t("Vår ref.","Our ref.")+'</div>'+esc(v.ourRef||"—")+'</div></div>'+
  '<div class="stats"><div><b>'+q(timer)+'</b><span>'+v.t("timer totalt","hours total")+'</span></div>'+
    '<div><b>'+v.items.length+'</b><span>'+v.t("registrerte vakter","shifts logged")+'</span></div>'+
    '<div><b>'+v.fc(v.total)+'</b><span>'+v.t("totalbeløp","amount due")+'</span></div></div>'+
  '<table><thead><tr><th>'+v.t("Ansatt / oppgave","Staff / task")+'</th><th class="r">'+v.t("Timer","Hours")+
    '</th><th class="r">'+v.t("Timesats","Hourly rate")+'</th><th class="r">'+v.t("Beløp","Amount")+
    '</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="ft"><div>'+esc(payLine(v)||"")+'</div><div>'+esc(v.terms||"")+'</div></div></div>';
});

/* ============ 22 Medlemskap og kontingent ============ */
reg(22,"Medlemskap og kontingent","Vennlig kortstil med medlemsnummer og betalingsstubb. Klubb og forening.",function(v){
  var rows=v.items.map(function(i){return '<div class="it"><div><b>'+esc(i.d)+'</b><small>'+q(i.q)+
    (i.u?" "+esc(i.u):"")+' × '+v.f(i.p)+'</small></div><div class="num">'+v.f(i.sum)+'</div></div>';}).join("");
  return '<div class="stripe"></div><div class="bd">'+
  '<div class="top"><div><span class="k">'+esc(v.seller.name)+'</span><h1>'+esc(v.title)+'</h1></div>'+
    '<div class="chip">'+esc(v.number)+'</div></div>'+
  '<div class="who"><div><span class="k">'+v.t("Medlem","Member")+'</span><b>'+esc(v.buyer.name)+'</b>'+
    (v.buyer.org?'<br><span class="dim">'+v.t("Medlemsnr.","Member no.")+' '+esc(v.buyer.org)+'</span>':"")+'</div>'+
    '<div><span class="k">'+v.t("Sesong / periode","Season / period")+'</span><b>'+esc(v.delivery||v.period)+'</b></div>'+
    '<div><span class="k">'+v.t("Forfall","Due")+'</span><b>'+v.dueStr+'</b></div></div>'+
  '<div class="items">'+rows+'</div>'+
  '<div class="sum">'+sumDivs(v)+'<div class="tot"><span>'+v.t("Å betale","Total due")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  '<div class="stub"><div class="k">'+v.t("Betalingsinformasjon","Payment details")+'</div>'+
    (payLine(v)?esc(payLine(v)):esc(v.pay.note||""))+
    (v.terms?'<div class="note">'+esc(v.terms)+'</div>':"")+'</div></div>';
});

/* ============ 23 Eksport og produksjon ============ */
reg(23,"Eksport og produksjon","Referansestrip med batch og kolleksjon, forskudd/restbelop i bunn. Tekstil- og produksjonseksport.",function(v){
  var rows=v.items.map(function(i,idx){return "<tr><td class=\"num dim\">"+(idx+1)+"</td><td>"+esc(i.d)+"</td><td class=\"r num\">"+q(i.q)+
    (i.u?" "+esc(i.u):"")+"</td><td class=\"r num\">"+v.f(i.p)+"</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  var tags=[["#",v.number],[v.t("Dato","Dated"),v.dateStr]];
  if(v.batchNr) tags.push([v.t("Batch","Batch No."),v.batchNr]);
  if(v.delivery) tags.push([v.t("Levering","Delivery"),v.delivery]);
  var tagRow=tags.map(function(x){return '<div class="tag"><span>'+esc(x[0])+'</span><b>'+esc(x[1])+'</b></div>';}).join("");
  var facts=[];
  if(v.buyer.land) facts.push([v.t("Bestemmelse","Destination"),v.buyer.land]);
  if(v.collection) facts.push([v.t("Kolleksjon","Collection"),v.collection]);
  facts.push([v.t("Betalingsvilkår","Payment term"),v.terms||v.t("Forskudd","Advance")]);
  var factRow=facts.map(function(x){return '<div class="fc"><span>'+esc(x[0])+'</span><b>'+esc(x[1])+'</b></div>';}).join("");
  var showBal=v.paidOre>0;
  return '<div class="hd"><div class="mk"><span class="ey">'+esc(v.title)+'</span><h1>'+esc(v.seller.name)+'</h1>'+
    (v.seller.x&&v.seller.x.hs?'<div class="hs">HS '+esc(v.seller.x.hs)+'</div>':"")+'</div>'+
    '<div class="cn"><span class="ey">'+v.t("Konsignatar","Consignee")+'</span><b>'+esc(v.buyer.name)+'</b>'+
    (v.buyer.att?'<br>'+esc(v.buyer.att):"")+(v.buyer.addr.length?'<br>'+A(v.buyer.addr):"")+'</div></div>'+
  '<div class="tags">'+tagRow+'</div>'+
  '<div class="facts">'+factRow+'</div>'+
  '<table><thead><tr><th></th><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Antall","Qty")+
    '</th><th class="r">'+v.t("Enhetspris","Unit price")+'</th><th class="r">'+v.t("Beløp","Total")+
    '</th></tr></thead><tbody>'+rows+'</tbody>'+
    '<tfoot><tr><td colspan="2" class="dim">'+v.qtyTotal+' '+v.t("stk totalt","pcs total")+'</td><td colspan="3"></td></tr></tfoot></table>'+
  '<div class="sum"><div class="tot"><span>'+v.t("Fakturabeløp","Invoice total")+'</span><span class="num">'+v.fc(v.total)+'</span></div>'+
    (showBal?('<div class="adv"><span>'+v.t("Mottatt forskudd","Advance received")+'</span><span class="num">'+v.fc(v.paid)+'</span></div>'+
      '<div class="bal"><span>'+v.t("Restbeløp","Balance due")+'</span><span class="num">'+v.fc(v.balance)+'</span></div>'):"")+'</div>'+
  '<div class="ft"><div><span class="ey">'+v.t("Betaling","Payment")+'</span>'+esc(payLine(v)||v.pay.note||"")+'</div>'+
    '<div><span class="ey">'+v.t("Merknad","Note")+'</span>'+esc(v.legal||"")+'</div></div>';
});

/* ============ 24 Foderasjon og sertifisering ============ */
reg(24,"Føderasjon og sertifisering","Formelt brevhode med rund emblemlogo, dobbel rammelinje og sentrert bunntekst. Forbund, føderasjoner og sertifiseringsorgan.",function(v){
  var rows=v.items.map(function(i){return "<tr><td>"+esc(i.d)+"</td><td class=\"r num\">"+(i.q&&i.q!==1?q(i.q):"")+
    "</td><td class=\"r num\">"+v.f(i.sum)+"</td></tr>";}).join("");
  return '<div class="hd"><div class="brand">'+
    (v.seller.logo?'<img class="crest" src="'+v.seller.logo+'" alt="">':'<div class="crest ph"></div>')+
    '<div class="fn"><h1>'+esc(v.seller.name)+'</h1><div class="sub">'+v.t("Internasjonalt forbund","International federation")+'</div></div></div>'+
    '<div class="doc"><div class="dt">'+esc(v.title)+'</div><div class="meta">'+
      '<div><span>'+v.t("Nr.","Invoice #")+'</span><b>'+esc(v.number)+'</b></div>'+
      '<div><span>'+v.t("Dato","Date")+'</span><b>'+v.dateStr+'</b></div></div></div></div>'+
  '<div class="rule"></div>'+
  '<div class="bd">'+
  '<div class="who"><div><span class="k">'+v.t("Fakturamottaker","Bill to")+'</span><b>'+esc(v.buyer.name)+'</b>'+
    (v.buyer.att?'<br>'+esc(v.buyer.att):"")+(v.buyer.addr.length?'<br>'+A(v.buyer.addr):"")+
    (v.buyer.email?'<br>'+esc(v.buyer.email):"")+'</div>'+
    '<div class="due"><span class="k">'+v.t("Forfall","Due")+'</span><b>'+v.dueStr+'</b></div></div>'+
  '<table><thead><tr><th>'+v.t("Beskrivelse","Description")+'</th><th class="r">'+v.t("Antall","Qty")+
    '</th><th class="r">'+v.t("Beløp","Amount")+'</th></tr></thead><tbody>'+rows+'</tbody></table>'+
  '<div class="sum"><div class="tot"><span>'+v.t("Total","Total")+'</span><span class="num">'+v.fc(v.total)+'</span></div></div>'+
  (v.terms?'<div class="pay">'+esc(v.terms)+'</div>':"")+
  '<div class="ft">'+esc(v.seller.name)+(v.seller.addr.length?' · '+v.seller.addr.map(function(x){return esc(x);}).join(", "):"")+
    (v.legal?'<br>'+esc(v.legal):"")+'</div></div>';
});


/* =====================================================================
   Visningsmodellen. Alle beløp inn er heltall i øre, slik resten av
   systemet regner. Malene får dem ferdig formatert.
   ===================================================================== */

export function lagVisning({ faktura, linjer, kunde, org, avsender }) {
  const d = faktura.fakturadato ? new Date(faktura.fakturadato) : new Date();
  const forfall = faktura.forfall ? new Date(faktura.forfall) : d;
  const valuta = faktura.valuta || "NOK";
  const sprak = faktura.sprak || "no";
  const t = (no, en) => (sprak === "en" ? en : no);

  const items = (linjer || []).map((l) => {
    const antall = Number(l.antall) || 0;
    const sum = Math.round(antall * (l.pris_ore || 0));
    return { d: l.beskrivelse || "", q: antall, u: l.enhet || "",
             p: (l.pris_ore || 0) / 100, vat: l.mva_sats || 0, sum: sum / 100,
             sumOre: sum };
  });

  const nettoOre = items.reduce((a, b) => a + b.sumOre, 0);
  const grupper = {};
  items.forEach((i) => { grupper[i.vat] = (grupper[i.vat] || 0) + i.sumOre; });
  const vatGroups = Object.keys(grupper).map((r) => ({
    rate: Number(r), base: grupper[r] / 100,
    amt: Math.round(grupper[r] * Number(r) / 100) / 100
  })).sort((a, b) => a.rate - b.rate);
  const mvaOre = vatGroups.reduce((a, b) => a + Math.round(b.amt * 100), 0);

  const titler = {
    faktura: ["Faktura", "Invoice"],
    proforma: ["Proforma faktura", "Proforma invoice"],
    kreditnota: ["Kreditnota", "Credit note"]
  };
  const tt = titler[faktura.type] || titler.faktura;
  const a = avsender || {};

  const f = (n) => belop(Math.round(n * 100), valuta);

  return {
    lang: sprak, t, type: faktura.type || "faktura", title: t(tt[0], tt[1]),
    seller: {
      name: a.navn || org?.navn || "", addr: (a.adresse || "").split("\n").filter((x) => x.trim()),
      email: a.epost || "", phone: a.telefon || "", org: a.orgnr || "",
      vat: a.mva || "", accent: a.farge || "#087F7A", logo: a.logo || "",
      x: a.eksport || {}
    },
    buyer: {
      name: kunde?.navn || "", att: kunde?.att || "",
      addr: (kunde?.adresse || "").split("\n").filter((x) => x.trim()),
      org: kunde?.orgnr || "", email: kunde?.epost || "", land: kunde?.land || ""
    },
    number: faktura.nummer || t("(ikke utstedt)", "(not issued)"),
    date: d, dateStr: dmy(d),
    dateLong: t(d.getDate() + ". " + MND[d.getMonth()] + " " + d.getFullYear(),
                MNE[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()),
    dueDate: forfall, dueStr: dmy(forfall),
    dueLong: t(forfall.getDate() + ". " + MND[forfall.getMonth()] + " " + forfall.getFullYear(),
               MNE[forfall.getMonth()] + " " + forfall.getDate() + ", " + forfall.getFullYear()),
    dueDays: Math.round((forfall - d) / 86400000),
    period: t(MND[d.getMonth()] + " " + d.getFullYear(), MNE[d.getMonth()] + " " + d.getFullYear()),
    cur: valuta, items, qtyTotal: items.reduce((x, y) => x + y.q, 0),
    net: nettoOre / 100, disc: 0, discAmt: 0, netAfter: nettoOre / 100,
    vatGroups, vatTotal: mvaOre / 100, roundAmt: 0, total: (nettoOre + mvaOre) / 100,
    hasVat: mvaOre > 0,
    pay: {
      bank: a.bank || "", account: a.kontonummer || "", iban: a.iban || "",
      swift: a.swift || "", kid: faktura.kid || "", link: a.lenke || "", note: a.betalingsnotat || ""
    },
    ourRef: faktura.var_ref || "", theirRef: faktura.deres_ref || "",
    delivery: faktura.levering_fra
      ? (faktura.levering_til && faktura.levering_til !== faktura.levering_fra
          ? dmy(new Date(faktura.levering_fra)) + " – " + dmy(new Date(faktura.levering_til))
          : dmy(new Date(faktura.levering_fra)))
      : (faktura.levering_til ? dmy(new Date(faktura.levering_til)) : ""),
    batchNr: faktura.batch_nr || "", collection: faktura.kolleksjon || "",
    paidOre: faktura.betalt_ore || 0, paid: (faktura.betalt_ore || 0) / 100,
    balance: Math.max(0, (nettoOre + mvaOre - (faktura.betalt_ore || 0)) / 100),
    intro: "", terms: faktura.notat || a.vilkar || "", legal: a.fotnote || "",
    f, fc: (n) => f(n) + " " + valuta, cf: (n) => valuta + " " + f(n)
  };
}

export const MALER = T;
export function malMedId(id) { return T.find((m) => m.id === Number(id)) || T[0]; }

/** Returnerer én ferdig fakturaside som HTML-streng. */
export function tegnFaktura(v, malId) {
  const m = malMedId(malId);
  const stil = "--ac:" + (v.seller.accent || "#087F7A") +
               ";--acs:" + hexA(v.seller.accent, 0.13) + ";";
  return '<div class="inv inv-' + m.id + '" style="' + stil + '">' + m.render(v) + "</div>";
}
