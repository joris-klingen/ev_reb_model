# Fetch annual petrol and marginal household electricity prices from CBS StatLine ----
#   80416ned  Pompprijzen motorbrandstoffen, per dag: Euro95, euro/liter (annual mean of days)
#   Electricity: marginal price per kWh = variable delivery tariff + ODE + energy tax, incl. VAT
#   (the price of an extra kWh, e.g. for charging; fixed costs and the tax refund excluded)
#     84672NED  Gemiddelde energietarieven voor consumenten, 2018 - May 2023 (monthly)
#     85592NED  Gemiddelde energietarieven voor consumenten, 2021 onwards (monthly; contract price)
#     2015-2017 backcast: delivery price excl. taxes from 85666NED (households 2.5-5 MWh) plus the
#     statutory energy tax and ODE (first band), times 1.21 VAT; checked against 2018-2019.
# Written to data/statline_prices.csv

library(data.table)
library(jsonlite)

if (!exists("tcat")) tcat <- function(...) cat(format(Sys.time(), "[%Y-%m-%d %H:%M:%S] "), ..., "\n", sep = "")

odata <- function(table, query) {
  url <- sprintf("https://opendata.cbs.nl/ODataApi/odata/%s/TypedDataSet?$format=json&%s", table, query)
  as.data.table(fromJSON(URLencode(url))$value)
}

# Petrol: annual mean of daily Euro95 pump prices ----
tcat("Fetching Euro95 pump prices (80416ned)")
petrol <- odata("80416ned", "$filter=Perioden ge '2015' and Perioden lt '2027'&$select=Perioden,BenzineEuro95_1")
petrol[, year := as.integer(substr(Perioden, 1, 4))]
petrol <- petrol[!is.na(BenzineEuro95_1), .(petrol = mean(BenzineEuro95_1), petrol_days = .N), by = year]

# Electricity: monthly marginal tariffs incl. VAT ----
tcat("Fetching consumer electricity tariffs (84672NED, 85592NED)")
tariff_old <- odata("84672NED", paste0(
  "$filter=Btw eq 'A048944'",
  "&$select=Perioden,VariabelLeveringstarief_8,OpslagDuurzameEnergieODE_9,Energiebelasting_10"
))
tariff_old <- tariff_old[grepl("MM", Perioden), .(
  Perioden, marginal = VariabelLeveringstarief_8 + OpslagDuurzameEnergieODE_9 + Energiebelasting_10
)]
tariff_new <- odata("85592NED", paste0(
  "$filter=Btw eq 'A048944'",
  "&$select=Perioden,VariabelLeveringstariefContractprijs_9,OpslagDuurzameEnergieODE_13,Energiebelasting_14"
))
tariff_new <- tariff_new[grepl("MM", Perioden), .(
  Perioden, marginal = VariabelLeveringstariefContractprijs_9 + fcoalesce(OpslagDuurzameEnergieODE_13, 0) + Energiebelasting_14
)]
# Newest table wins where the two overlap
tariff <- rbind(tariff_old[!Perioden %in% tariff_new$Perioden], tariff_new)[!is.na(marginal)]
tariff[, year := as.integer(substr(Perioden, 1, 4))]
elec <- tariff[, .(electricity = mean(marginal), electricity_months = .N), by = year]
elec[, electricity_source := "StatLine 84672NED/85592NED"]

# Backcast 2015-2017 ----
tcat("Fetching household delivery prices for the backcast (85666NED)")
delivery <- odata("85666NED", paste0(
  "$filter=Prijscomponenten eq 'A047657' and Belastingen eq 'A047661'",
  "&$select=Perioden,k_25Tot5MWh_11"
))[grepl("JJ", Perioden)]
delivery[, year := as.integer(substr(Perioden, 1, 4))]
# Statutory energy tax and ODE, first band, euro/kWh excl. VAT (Belastingdienst)
statutory <- data.table(
  year = 2015:2019,
  energy_tax = c(0.1196, 0.1007, 0.1013, 0.10458, 0.09863),
  ode = c(0.0036, 0.0056, 0.0074, 0.0132, 0.0189)
)
backcast <- merge(delivery[, .(year, delivery = k_25Tot5MWh_11)], statutory, by = "year")
backcast[, electricity := 1.21 * (delivery + energy_tax + ode)]
check <- merge(backcast[, .(year, backcast = electricity)], elec[, .(year, electricity)], by = "year")
tcat(paste(sprintf("Backcast check %d: %.3f vs %.3f euro/kWh", check$year, check$backcast, check$electricity), collapse = "; "))
elec <- rbind(
  backcast[year < min(elec$year), .(year, electricity, electricity_months = NA_integer_,
                                   electricity_source = "backcast 85666NED + statutory taxes")],
  elec
)

prices <- merge(petrol, elec, by = "year", all = TRUE)[year >= 2015]
setorder(prices, year)
# Carry the last observed electricity price forward if the latest year is missing
prices[is.na(electricity), electricity_source := "carried forward"]
prices[, electricity := nafill(electricity, type = "locf")]

fwrite(prices, "data/statline_prices.csv")
tcat("Written data/statline_prices.csv")
print(prices)
