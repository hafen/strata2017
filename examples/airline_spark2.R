## installation
# install.packages("devtools")
# install.packages("tidyverse")
# install.packages("nycflights13")
# install.packages("sparklyr") # 0.5.1
# devtools::install_github("hafen/trelliscopejs")
# library(sparklyr)
# spark_install(version = "1.6.2")

# download the data file
# you can change the location of dat_path if you'd like
# to make sure it persists across R sessions
data_path <- tempfile(fileext = ".csv.gz")
download.file(
  "http://ml.stat.purdue.edu/hafen/strata2017/flights2008.csv.gz",
  data_path)

library(nycflights13)
library(tidyverse)
library(forcats)
library(sparklyr)
library(trelliscopejs)

all_airlines <- rbind(
  airlines,
  tribble(
     ~carrier, ~name,
     "OH",     "Comair Inc.",
     "NW",     "Northwest Airlines Inc.",
     "CO",     "Continental Airlines Inc.",
     "XE",     "ExpressJet Airlines Inc.",
     "AQ",     "Aloha Air"
   )
) %>%
  mutate(
    # shorten the names
    name = gsub(
      " Airlines Inc\\.| Airlines Co\\.| Inc\\.| Air Lines Inc\\.| Airways Corporation| Airways",
      "",
      name)) %>%
  as.data.frame() %>%
  print()


sc <- spark_connect(master = "local")

flights_tbl <- spark_read_csv(sc, "flights_csv", data_path)

## first: look at arrival delay summary stats per carrier

# use dplyr functions to compute summaries and collect results
# ideally we would compute quartiles and median
# but sparklyr doesn't support this...
cr_arr_delay <- flights_tbl %>%
  group_by(carrier) %>%
  summarise(
    mean_delay = mean(arr_delay),
    n = n()) %>%
  arrange(mean_delay) %>%
  collect()

cr_arr_delay

# merge the airline info so we know who the carriers are
cr_arr_delay <- left_join(cr_arr_delay, airlines)

cr_arr_delay

# visualize the local results...

ggplot(cr_arr_delay, aes(fct_reorder(name, mean_delay), mean_delay)) +
  geom_point() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  xlab(NULL) + ylab("Arrival Delay (minutes)")

ggplot(cr_arr_delay, aes(fct_reorder(name, n), n)) +
  geom_point() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  xlab(NULL) + ylab("Total Flights")

# # ideally plot median with quartile lines...
# ggplot(cr_arr_delay, aes(fct_reorder(name, arr_delay50), arr_delay50)) +
#   geom_pointrange(aes(ymin = arr_delay25, ymax = arr_delay75)) +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#   xlab(NULL) + ylab("Arrival Delay (minutes)")

# the top 7 airlines
cr_arr_delay %>% filter(n > 380000) %>% select(carrier)

top7 <- c("US", "WN", "OO", "DL", "MQ", "UA", "AA")

# let's summarize just by month
mn_arr_delay <- flights_tbl %>%
  group_by(month) %>%
  summarise(mean_delay = mean(arr_delay)) %>%
  arrange(month) %>%
  collect()

## is there more to these high-level summaries?
## let's see how these means vary over time - aggregate monthly

cr_mn_arr_delay <- flights_tbl %>%
  group_by(carrier, month) %>%
  summarise(
    mean_delay = mean(arr_delay),
    n = n()) %>%
  collect() %>%
  left_join(airlines)

# look at monthly mean delay
ggplot(cr_mn_arr_delay, aes(month, mean_delay)) +
  geom_point() + geom_line() +
  facet_grid(~ fct_reorder(name, mean_delay))

# look at number of flights
ggplot(cr_mn_arr_delay, aes(month, n)) +
  geom_point() + geom_line() +
  scale_y_log10() +
  facet_grid(~ fct_reorder(name, mean_delay))
# skywest has very few flights - let's get rid of it

# same plot without log y scale
ggplot(cr_mn_arr_delay, aes(month, n)) +
  geom_point() + geom_line() +
  facet_grid(~ fct_reorder(name, mean_delay))

# overlay them all
cr_mn_arr_delay %>%
  filter(carrier %in% top7) %>%
  ggplot(aes(month, mean_delay, color = name)) +
    geom_point() + geom_line()

## we just got some more detail by month and saw that there appears
## to be an effect there...
## can we get into more detail?
## questions:
## - are different destinations more prone to delays?
## - does variability across airlines change for different destinations?
## let's look into these by grouping by dest, month, and name
## we'll look at mean delay for those with enough observations

# group by, origin, dest, carrier, month and get mean delay and # obs
# and pull this back into R
route_summ <- flights_tbl %>%
  group_by(origin, dest, carrier, month) %>%
  summarise(
    mean_delay = mean(arr_delay),
    n = n()) %>%
  filter(n >= 50) %>%
  collect()
  
nrow(route_summ)
# much smaller data set of ~51k summaries

# let's visualize this in more detail
# let's make a plot for each route (origin/dest combination)
# overlaying each airline's average delay across months of 2008
# let's just look at the top 7 airlines
# also, we want to add in the carrier name so let's join that too
# we want carrier to be a factor for our plots

route_summ7 <- 
  filter(route_summ, carrier %in% top7) %>%
  left_join(airlines) %>%
  rename(carrier_name = name) %>%
  mutate(carrier_name = factor(carrier_name))

# now let's nest the data by origin and dest (need to explain this...)
by_route <- route_summ7 %>%
  group_by(origin, dest) %>%
  nest()

by_route

# there are ~2.2k routes, the data for each is stored in the 'data' column

# some routes have data that is pretty sparse
# let's filter this to only include routes that have data for every month
# we can do this by looking in 'data' to count the unique number of months
# and add this as a new variable to filter on
# we might as well calculate the unique number of carriers while we're at it

by_route <- by_route %>%
  mutate(
    n_months = map_int(data, ~ n_distinct(.$month)),
    n_carriers = map_int(data, ~ n_distinct(.$carrier))
    # miny = map_dbl(data, ~ min(.$mean_delay, na.rm = TRUE)),
    # maxy = map_dbl(data, ~ max(.$mean_delay, na.rm = TRUE))
  )

by_route

by_route <- filter(by_route, n_months == 12) %>%
  select(-n_months)

# now we have 1.7k routes

# let's make a plot column for each route
by_route <- by_route %>%
  mutate(
    plot = map_plot(data, function(x) {
      ggplot(x, aes(month, mean_delay, color = carrier_name)) +
        geom_line(aes(month, mean_delay), data = mn_arr_delay,
          color = "gray", size = 1) +
        geom_point() + geom_line() +
        ylim(c(-33.5, 96.25)) +
        scale_color_discrete(drop = FALSE)
    })
  )

by_route

trelliscope(by_route2, name = "test", nrow = 2, ncol = 4)







# we can do this if we want to add the airport name in
airport_names <- airports %>%
  select(faa, name) %>%
  rename(airport_name = name)

by_route <- by_route %>%
  left_join(airport_names, by = c("origin" = "faa")) %>%
  left_join(airport_names, by = c("dest" = "faa")) %>%
  rename(
    origin_name = airport_name.x,
    dest_name = airport_name.y)
