select patno,
    othtxname,
    null as othtxnameoth,
    othtxprevrep,
    to_date('15/'||othtxsdaten, 'DD/MM/YYYY') as othtxsdate,
    othtxstop,
    to_date('15/'||othtxedaten, 'DD/MM/YYYY') as othtxedate,
    othtxreas,
    null as othtxreasoth 
from admire_v5.othtxdet;
