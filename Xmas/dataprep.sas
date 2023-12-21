cas; 
caslib _all_ assign;

proc casutil; 
	droptable casdata='xmas';
run;

data casuser.xmas(promote=yes replace=yes);
	length date x y color_num 8. color $1.;
	format date year.;

	id = 0;

	do year = 1950 to 2000 by 1;
		date = mdy(1,1,year);

		/* horizontal stripes */
		do r=0 to 1 by .1;
			x=1+r;y=8;size=1;color_num=1;id=id+1;output;
			x=-2.5+r;y=5;size=1;color_num=1;id=id+1;output;
			x=0.5+(r*2);y=3;size=1;color_num=1;id=id+1;output;
		end;

		/* larger background drops */
		x=0.5;y=9;id=id+1;size=5;output;
		x=2.5;y=7;id=id+1;size=5;output;
		x=1.5;y=5;id=id+1;size=5;output;
		x=-2;y=4;id=id+1;size=6;output;
		x=3;y=4;id=id+1;size=6;output;
		x=2.5;y=1.5;id=id+1;size=6;output;
		x=-.5;y=7;id=id+1;size=8;output;
		x=-2.5;y=1.5;id=id+1;size=8;output;
		x=3.5;y=3;id=id+1;size=8;output;

		offset = 0;
		do y = 11 to 1 by -1;
			offset = offset + .5;
			do x = 1 - offset to 12 - y - offset by 1;
				id = id + 1;
				color_num = rand('integer',5);
				color = char('glbro',color_num);
				size = 1;
				output;
			end;
		end;
	
		/* tree stumb */
		x=0.5;y=0;id=id+1;output;
		x=0.5;y=-1;id=id+1;output;

	end;

	drop offset r;
run;
