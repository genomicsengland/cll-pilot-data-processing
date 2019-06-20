select patno,
    othtxnamep,
    null as othtxnameothp,
    to_date('15/'||othtxsdatepn, 'DD/MM/YYYY') as othtxsdatep,
    othtxstopp,
    to_date('15/'||othtxedatepn, 'DD/MM/YYYY') as othtxedatep,
    othtxrespp,
    othtxreasp,
    null as othtxreasothp,
    trialp,
    null as trialnamep,
    null as trialnameothp 
from admire_v5.othtxprogp;
