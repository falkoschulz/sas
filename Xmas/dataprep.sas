cas; 
caslib _all_ assign;

proc casutil; 
	droptable casdata='xmas';
run;

data casuser.xmas(promote=yes replace=yes);
	length date x y color_num 8.;
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
		x=0.5;y=9;id=id+1;size=5+mod(2000 - year,3);output;
		x=2.5;y=7;id=id+1;size=5;output;
		x=1.5;y=5;id=id+1;size=5;output;
		x=-2;y=4;id=id+1;size=6;output;
		x=3;y=4;id=id+1;size=6+mod(2000 - year,3);output;
		x=2.5;y=1.5;id=id+1;size=6;output;
		x=-.5;y=7;id=id+1;size=8;output;
		x=-2.5;y=1.5;id=id+1;size=8+mod(2000 - year,3);output;
		x=3.5;y=3;id=id+1;size=8;output;

		/* tree */
		offset = 0;size = 1;
		do y = 11 to 1 by -1;
			offset = offset + .5;
			do x = 1 - offset to 12 - y - offset by 1;
				/* do not create a bubble for some if overlaid on a stripe */
				if (not (x eq 2 and y eq 8) and not (x eq -2.5 and y eq 5)) then do;
					id = id + 1;
	
					if ((x eq 1 and y eq 8) or (x eq -1.5 and y eq 5)) then do;
						/* bubbles on stripes get animated */
						tempx = x;
						if (x ge 0) then x = x + (1 - (2000 - year) / 50); else x = x - (1 - (2000 - year) / 50);
						color_num = 2;
						output;
						x = tempx;
					end;else do;
						color_num = rand('integer',5);
						output;
					end;
				end; 
			end;
		end;
	
		/* tree stumb */
		x=0.5;y=0;id=id+1;output;
		x=0.5;y=-1;id=id+1;output;
	end;

	drop offset r tempx;
run;
