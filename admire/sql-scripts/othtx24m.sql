select patno
	,date(othtxsdate24m) as othtxsdate24m
	,othtxstop24m
	,othtxresp
	,othtxreas24m
	trial24m
from admire_v5.othtx24m;
