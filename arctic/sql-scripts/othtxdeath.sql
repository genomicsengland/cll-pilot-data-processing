select patno,
    null as othtxnamed,
    othtxnameothd,
    to_date('15/'||othtxsdatedn, 'DD/MM/YYYY') as othtxsdated,
    othtxstopd,
    to_date('15/'||othtxedatedn, 'DD/MM/YYYY') as othtxedated,
    othtxrespd,
    othtxreasd,
    null as othtxreasothd,
    triald,
    null as trialnamed,
    null as trialnameothd 
from arctic_v5.othtxdeath;
