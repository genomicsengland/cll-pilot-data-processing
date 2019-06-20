select patno,
    othtxname12m,
    null as othtxnameoth12m,
    to_date('15/'||othtxsdate12mn, 'DD/MM/YYYY') as othtxsdate12m,
    othtxstop12m,
    to_date('15/'||othtxedate12mn, 'DD/MM/YYYY') as othtxedate12m,
    othtxresp12m,
    othtxreas12m,
    null as othtxreasoth12m,
    trial12m,
    null as trialname12m,
    null as trialnameoth12m 
from admire_v5.othtx12m;
