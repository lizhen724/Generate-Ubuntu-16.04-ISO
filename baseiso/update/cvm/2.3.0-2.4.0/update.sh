#!/bin/bash

# add ha_state to table instances

mysql -e "use nova; alter table instances add column ha_state varchar(233) default NULL;"

