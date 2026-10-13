# EHF-mapping (fasit for app/ehf.js)

Utdrag av prosjektets spesifikasjon «EHF-mapping og nummerserie» (26.08.2026). Krav: **O** obligatorisk, **O\*** betinget, **V** valgfri.

## Faste verdier
| Felt | Verdi |
|---|---|
| `cbc:CustomizationID` | `urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0` |
| `cbc:ProfileID` | `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0` |
| `cbc:InvoiceTypeCode` | 380 faktura · 384 korrigert · 386 forskudd · 326 delfaktura. Kreditnota = `CreditNote` m/ 381. 325 proforma ikke tillatt. |
| Enhetskoder | UN/ECE Rec 20: stk `H87`, time `HUR`, kg `KGM`, døgn `DAY`, m `MTR`, l `LTR` |
| Betalingsmåte | UNCL4461 `30` kredittoverføring |

## Dokumentnivå (`Invoice`)
| Datamodell | UBL | BT | Krav |
|---|---|---|---|
| `nummer` | `cbc:ID` | BT-1 | O |
| `fakturadato` | `cbc:IssueDate` | BT-2 | O |
| `forfall` | `cbc:DueDate` | BT-9 | V |
| type | `cbc:InvoiceTypeCode` | BT-3 | O |
| `valuta` | `cbc:DocumentCurrencyCode` | BT-5 | O |
| — | `cbc:TaxCurrencyCode` | BT-6 | O\* når valuta ≠ NOK (da også ekstra TaxTotal i NOK, BT-111) |
| `deres_ref` | `cbc:BuyerReference` | BT-10 | O\* — denne ELLER BT-13 (PEPPOL-EN16931-R003) |
| `bestillingsnr` | `cac:OrderReference/cbc:ID` | BT-13 | O\* |
| `var_ref` | `cac:OrderReference/cbc:SalesOrderID` | BT-14 | V |
| `notat` | `cbc:Note` | BT-22 | V |
| `levering_fra/til` | `cac:InvoicePeriod/cbc:StartDate`+`EndDate` | BT-73/74 | V |
| `krediterer` | `cac:BillingReference/cac:InvoiceDocumentReference/cbc:ID` | BT-25 | O\* kreditnota |
| kontonummer | `cac:PaymentMeans/cac:PayeeFinancialAccount/cbc:ID` | BT-84 | O\* |
| KID | `cac:PaymentMeans/cbc:PaymentID` | BT-83 | V |
| — | `cac:PaymentMeans/cbc:PaymentMeansCode` = 30 | BT-81 | O\* når PaymentMeans finnes |

## Selger (`cac:AccountingSupplierParty/cac:Party`)
| Datamodell | UBL | BT | Krav |
|---|---|---|---|
| orgnr | `cbc:EndpointID @schemeID="0192"` | BT-34 | O |
| orgnr | `cac:PartyLegalEntity/cbc:CompanyID @schemeID="0192"` | BT-30 | O\* (BR-CO-26) |
| navn | `cac:PartyLegalEntity/cbc:RegistrationName` | BT-27 | O |
| navn | `cac:PartyName/cbc:Name` | BT-28 | V |
| adresse, postnr, sted | `cac:PostalAddress/cbc:StreetName`, `PostalZone`, `CityName` | BT-35/38/37 | V |
| land | `cac:PostalAddress/cac:Country/cbc:IdentificationCode` | BT-40 | O (BR-09) |
| `NO<orgnr>MVA` | `cac:PartyTaxScheme/cbc:CompanyID` + `cac:TaxScheme/cbc:ID`=`VAT` | BT-31 | O\* ved S/Z/E/G/AE |
| foretaksregistrert | `cac:PartyLegalEntity/cbc:CompanyLegalForm` = `Foretaksregisteret` | BT-33 | O\* AS/ASA/NUF (NO-R-002) |
| epost, telefon | `cac:Contact/cbc:ElectronicMail`, `cbc:Telephone` | BT-43/42 | V |

## Kjøper (`cac:AccountingCustomerParty/cac:Party`)
| Datamodell | UBL | BT | Krav |
|---|---|---|---|
| `ehf_mottaker` / orgnr | `cbc:EndpointID @schemeID="0192"` | BT-49 | O (PEPPOL-EN16931-R010) |
| orgnr | `cac:PartyLegalEntity/cbc:CompanyID @schemeID="0192"` | BT-47 | O\* |
| navn | `cac:PartyLegalEntity/cbc:RegistrationName` | BT-44 | O (BR-07) |
| att | `cac:Contact/cbc:Name` | BT-56 | V |
| gate/postnr/sted/land | `cac:PostalAddress/*` — land O (BR-11) | BT-50…55 | land O |
| epost | `cac:Contact/cbc:ElectronicMail` | BT-58 | V |
| mvanr | `cac:PartyTaxScheme/cbc:CompanyID` | BT-48 | O\* ved AE |

## Linje (`cac:InvoiceLine`)
| Datamodell | UBL | BT | Krav |
|---|---|---|---|
| løpenr 1,2,… | `cbc:ID` | BT-126 | O |
| antall | `cbc:InvoicedQuantity` | BT-129 | O |
| enhetskode | `cbc:InvoicedQuantity/@unitCode` | BT-130 | O (Rec 20) |
| beregnet | `cbc:LineExtensionAmount` | BT-131 | O — = antall × pris (PEPPOL-EN16931-R120, avvik 0,01 avviser) |
| beskrivelse | `cac:Item/cbc:Name` | BT-153 | O |
| pris | `cac:Price/cbc:PriceAmount` | BT-146 | O (aldri negativ, BR-27) |
| kategori | `cac:Item/cac:ClassifiedTaxCategory/cbc:ID` | BT-151 | O |
| sats | `cac:Item/cac:ClassifiedTaxCategory/cbc:Percent` | BT-152 | O\* (ikke ved O) |
| — | `cac:Item/cac:ClassifiedTaxCategory/cac:TaxScheme/cbc:ID` = `VAT` | | O |

## Summer
`cac:LegalMonetaryTotal`: `LineExtensionAmount` (Σ linjer, BR-CO-10), `TaxExclusiveAmount` (BR-CO-13), `TaxInclusiveAmount` (BR-CO-15), `PayableAmount` (BR-CO-16). `cac:TaxTotal/cbc:TaxAmount` (BR-CO-14) med én `cac:TaxSubtotal` per (kategori, sats): `TaxableAmount`, `TaxAmount`, `TaxCategory/ID`, `Percent`, evt. `TaxExemptionReason`/`TaxExemptionReasonCode`, `TaxScheme/ID`=`VAT`. Alle beløp to desimaler, `currencyID`.

## Mva-kategorier (BT-118/151)
| Situasjon | Kategori | Sats | Begrunnelse | Regel |
|---|---|---|---|---|
| Alminnelig/redusert | `S` | 25/15/12/6 | ingen | BR-S-02 krever selgers mva-nr |
| Utførsel av varer (mval. § 6-21) | `G` | 0 | BT-120 fritekst «Merverdiavgiftsloven § 6-21 — utførsel av varer» | BR-G-10 krever begrunnelse |
| Innenlands fritak | `Z` | 0 | **ingen** (BR-Z-10) | BR-Z-02 |
| Omvendt avgiftsplikt | `AE` | 0 | BT-121 `VATEX-EU-AE` | selger + kjøper mva-nr |
| Unntatt (mval. kap. 3) | `E` | 0 | BT-120/121 | BR-E-02 |
| Utenfor avgiftsområdet | `O` | ingen Percent | `VATEX-EU-O` | BR-O-02 forbyr selgers mva-nr; BR-O-11 ingen andre kategorier |

## Vanligste valideringsfeil
PEPPOL-EN16931-R003 (mangler BuyerReference/OrderReference) · R004 (CustomizationID feilstavet) · R010 (kjøpers EndpointID) · R120 (linjesum) · BR-CO-13/14/15 (summer avrundet flere ganger) · BR-CO-26 (selger uten ID) · BR-08/09/10/11 (adresse/land) · BR-23 (enhetskode) · BR-Z-10/BR-G-10 (begrunnelse feil vei) · BR-27 (negativ pris).

Validator: https://anskaffelser.dev/service/validator/ · Regelsett: Peppol BIS Billing 3.0 v3.0.21, EHF Billing 3.0 v3.0.3.
