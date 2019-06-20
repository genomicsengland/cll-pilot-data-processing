select patno,
    /*patinitf03,*/
    extract(year from dob) as yobf03,
    /*nhsnof03,*/
    sexf03,
    ethnicityf03,
    trialnof03 
from arctic_v5.rand;
