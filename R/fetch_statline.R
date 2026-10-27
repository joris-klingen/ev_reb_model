# Fetch BEV share of the Dutch passenger car fleet from CBS StatLine ----
# Fleet in use (annual) and mean annual km, full electric (BEV/hydrogen) vs total:
#   83703NED  Verkeersprestaties personenauto's, brandstof uitgebreid, 2015-2020
#   85405NED  Verkeersprestaties personenauto's, brandstof uitgebreid, 2018-2024
# Years after the last fleet year are extended with new BEV sales:
#   85898NED  Verkochte wegvoertuigen; nieuw en tweedehands, brandstof (quarterly)
#   stock_t = stock_{t-1} + new BEV sales_t   (scrappage of young BEVs and used imports ignored)
#   total_t = total_{t-1} * growth of the active fleet in 85237NED (1 January)
# Note: the brandstof 'Elektriciteit' in 85237NED/71405ned includes hybrids, so it is not used for the share.

library(data.table)
library(jsonlite)

if (!exists("tcat")) tcat <- function(...) cat(format(Sys.time(), "[%Y-%m-%d %H:%M:%S] "), ..., "\n", sep = "")

odata <- function(table, query) {
  url <- sprintf("https://opendata.cbs.nl/ODataApi/odata/%s/TypedDataSet?$format=json&%s", table, query)
  as.data.table(fromJSON(URLencode(url))$value)
}

# Fleet in use ----
tcat("Fetching fleet in use (83703NED, 85405NED)")
fleet_query <- paste0(
  "$filter=LeeftijdVoertuig eq '10000' and (BrandstofsoortVoertuig eq 'T001051' or BrandstofsoortVoertuig eq 'A041292')",
  "&$select=Perioden,BrandstofsoortVoertuig,NederlandsePersonenautoSInGebruik_3,GemiddeldJaarkilometrage_2"
)
fleet <- rbind(
  odata("83703NED", fleet_query)[, table := "83703NED"],
  odata("85405NED", fleet_query)[, table := "85405NED"]
)
fleet[, year := as.integer(substr(Perioden, 1, 4))]
fleet <- dcast(fleet, table + year ~ BrandstofsoortVoertuig,
               value.var = c("NederlandsePersonenautoSInGebruik_3", "GemiddeldJaarkilometrage_2"))
setnames(fleet,
         c("NederlandsePersonenautoSInGebruik_3_T001051", "NederlandsePersonenautoSInGebruik_3_A041292",
           "GemiddeldJaarkilometrage_2_T001051", "GemiddeldJaarkilometrage_2_A041292"),
         c("cars_total", "cars_bev", "km_total", "km_bev"))
# Newest table wins where the two overlap
fleet <- fleet[order(year, -(table == "85405NED"))][, .SD[1], by = year]
fleet[, source := paste0("StatLine ", table)][, table := NULL]

# New BEV sales (passenger cars) ----
tcat("Fetching new BEV sales (85898NED)")
sales <- odata(
  "85898NED",
  "$filter=Wegvoertuigen eq 'A018943' and BrandstofsoortVoertuig eq 'A041293'&$select=Perioden,NieuwVerkochteWegvoertuigen_2"
)
sales <- sales[grepl("KW", Perioden)]
sales[, year := as.integer(substr(Perioden, 1, 4))]
sales <- sales[, .(new_bev = sum(NieuwVerkochteWegvoertuigen_2), n_quarters = .N), by = year]
# Incomplete last year: scale the available quarters to a full year
sales[, new_bev_annual := new_bev * 4 / n_quarters]

# Active fleet growth (1 January) ----
tcat("Fetching active fleet totals (85237NED)")
active <- odata("85237NED", "$filter=Bouwjaar eq 'T001378'&$select=Perioden,Totaal_14")
active[, year := as.integer(substr(Perioden, 1, 4))]
active <- active[order(year), .(year, growth = Totaal_14 / shift(Totaal_14))]

# Validation of the sales extension on the last observed fleet year ----
last_obs <- fleet[, max(year)]
check <- fleet[year == last_obs - 1, cars_bev] + sales[year == last_obs, new_bev]
tcat(sprintf(
  "Check %d: stock(t-1) + new sales = %s vs observed %s (%.1f%%)\n",
  last_obs, format(check, big.mark = ","), format(fleet[year == last_obs, cars_bev], big.mark = ","),
  100 * (check / fleet[year == last_obs, cars_bev] - 1)
))

# Extend ----
ext_years <- sales[year > last_obs, year]
for (y in ext_years) {
  prev <- fleet[year == y - 1]
  g <- active[year == y + 1, growth] # growth from 1 Jan y to 1 Jan y+1 approximates growth during y
  if (length(g) == 0 || is.na(g)) g <- active[year == y, growth]
  fleet <- rbind(fleet, data.table(
    year = y,
    cars_total = prev$cars_total * g,
    cars_bev = prev$cars_bev + sales[year == y, new_bev_annual],
    km_total = NA_real_,
    km_bev = NA_real_,
    source = sprintf("extended with 85898NED new BEV sales (%d quarters)", sales[year == y, n_quarters])
  ))
}
fleet[, `:=`(bev_share = cars_bev / cars_total, km_ratio = km_bev / km_total)]
setorder(fleet, year)

fwrite(fleet, "data/statline_bev_share.csv")
tcat("Written data/statline_bev_share.csv")
print(fleet)
