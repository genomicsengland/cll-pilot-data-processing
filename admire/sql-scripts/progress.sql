select patno,
    to_date('15/'||pprogdatepn, 'DD/MM/YYYY') as pprogdatep,
    txstopp,
    to_date('15/'||txstopdatepn, 'DD/MM/YYYY') as txstopdatep,
    othtxprogp 
from admire_v5.progress;
