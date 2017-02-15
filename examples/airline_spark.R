## installation
# install.packages("devtools")
# install.packages("tidyverse")
# install.packages("nycflights13")
# install.packages("sparklyr") # 0.5.1
# devtools::install_github("hafen/trelliscopejs")
# library(sparklyr)
# spark_install(version = "1.6.2")

library(nycflights13)
library(tidyverse)
library(forcats)
library(sparklyr)
library(trelliscopejs)

sc <- spark_connect(master = "local")

# copy flights data to Spark
flights_tbl <- copy_to(sc, nycflights13::flights, "flights")

## first: look at arrival delay summary stats per carrier

# use dplyr functions to compute summaries and collect results
# ideally we would compute quartiles and median
# but sparklyr doesn't support this...
cr_arr_delay <- flights_tbl %>%
  group_by(carrier) %>%
  summarise(
    mean_delay = mean(arr_delay),
    # arr_delay25 = quantile(arr_delay, 0.25, na.rm = TRUE),
    # arr_delay50 = median(arr_delay, na.rm = TRUE),
    # arr_delay75 = quantile(arr_delay, 0.75, na.rm = TRUE),
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

# the top 5 airlines
cr_arr_delay %>% filter(n > 30000) %>% select(carrier)

top5 <- c("AA", "DL", "UA", "B6", "EV")

## is there more to these high-level summaries?
## let's see how these means vary over time - aggregate monthly

cr_mn_arr_delay <- flights_tbl %>%
  group_by(carrier, month) %>%
  summarise(
    mean_delay = mean(arr_delay),
    # med_delay = median(arr_delay, na.rm = TRUE),
    n = n()) %>%
  collect() %>%
  left_join(airlines)

# look at monthly mean delay
ggplot(cr_mn_arr_delay, aes(month, mean_delay)) +
  geom_point() + geom_line() +
  facet_grid(~ fct_reorder(name, mean_delay))
# skywest is strange

# look at number of flights
ggplot(cr_mn_arr_delay, aes(month, n)) +
  geom_point() + geom_line() +
  scale_y_log10() +
  facet_grid(~ fct_reorder(name, mean_delay))
# skywest has very few flights - let's get rid of it

# same plot without log y scale
ggplot(cr_mn_arr_delay, aes(month, n)) +
  geom_point() + geom_line() +
  facet_grid(~ fct_reorder(name, med_delay))

# get rid of skywest
cr_mn_arr_delay2 <- filter(cr_mn_arr_delay,
  name != "SkyWest Airlines Inc.")

# delay plot without skywest
ggplot(cr_mn_arr_delay2, aes(month, mean_delay)) +
  geom_point() + geom_line() +
  facet_grid(~ fct_reorder(name, mean_delay))

# overlay them all
ggplot(cr_mn_arr_delay2, aes(month, mean_delay, color = name)) +
  geom_point() + geom_line()

## we just got some more detail by month and saw that there appears
## to be an effect there...
## can we get into more detail?
## questions:
## - are different destinations more prone to delays?
## - does variability across airlines change for different destinations?
## let's look into these by grouping by dest, month, and name
## we'll look at mean delay for those with enough observations

# group by dest, carrier, month and get mean delay and # obs
# this should be broken down and explained...
dest_cr_mn_arr <- flights_tbl %>%
  group_by(dest, carrier, month) %>%
  summarise(
    mean_delay = mean(arr_delay),
    # med_delay = median(arr_delay, na.rm = TRUE),
    n = n()) %>%
  filter(n >= 30) %>%
  collect() %>%
  filter(carrier %in% top5) %>%
  left_join(airlines) %>%
  ungroup() %>%
  left_join(airports, by = c("dest" = "faa")) %>%
  rename(carrier_name = name.x, dest_name = name.y) %>%
  mutate(carrier_name = factor(carrier_name))

# function to pad the ylim range
pad <- function(a, fct = 0.07)
  a + c(-1, 1) * diff(a) * fct

# make a trelliscope display, one panel for each destination
# plotting the mean delay over time for each airline
ggplot(dest_cr_mn_arr, aes(month, mean_delay, color = carrier_name)) +
  geom_point() + geom_line() +
  ylim(pad(range(dest_cr_mn_arr$mean_delay))) +
  scale_color_discrete(drop = FALSE) +
  facet_trelliscope(~ dest_name, name = "test", nrow = 2, ncol = 4)

# this entire analysis would be *much* more interesting if we could
# apply it to all origin/dest combinations over a longer period of time
# it would produce more panels in the trellisope display
# which would greater emphasize its utility
# also, it would greater emphasize the idea of computing summaries
# on larger data in spark and pull the results local for visualization


## another way to group the data and create a trelliscope display
## using the tidyverse "nest()" function...
dest_cr_mn_arr2 <- flights_tbl %>%
  group_by(dest, carrier, month) %>%
  summarise(
    med_delay = mean(arr_delay, na.rm = TRUE),
    # med_delay = median(arr_delay, na.rm = TRUE),
    n = n()) %>%
  filter(n >= 30) %>%
  collect() %>%
  filter(carrier %in% top5) %>%
  left_join(airlines) %>%
  ungroup() %>%
  mutate(carrier = factor(carrier)) %>%
  rename(carrier_name = name)

# local object to visualize
by_dest <- dest_cr_mn_arr %>%
  group_by(dest) %>%
  nest() %>%
  left_join(airports, by = c("dest" = "faa")) %>%
  rename(dest_name = name)

# todo: trelliscope code for this case
