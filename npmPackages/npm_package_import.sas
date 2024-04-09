%let root=C:\Temp;
%let local_path=&root.\data\npm_packages.json;
%let NPM_RESPONSE_SIZE=250;
 
libname data "&root.";
filename resp "&local_path";

%macro search(searchTerm);
	%let TMP_NPM_COUNT=&searchResultSize.;
	%let TMP_NPM_TOTAL=0;

	%do %while (&TMP_NPM_COUNT eq &NPM_RESPONSE_SIZE.);
		proc http url="https://registry.npmjs.org/-/v1/search?text=&searchTerm.&size=&NPM_RESPONSE_SIZE.&from=&TMP_NPM_TOTAL." method="GET" out=resp;
		run;

		libname npms JSON fileref=resp;

		proc sql;
			create table work.npm_packages(compress=yes) as
			select distinct
					b.name,
					c.name as author_name,
					c.email as author_email,
					c.username as author_username,
					b.scope, 
					b.version, 
					b.description, 
					input(b.date, anydtdtm22.) as date format=datetime22.,
					d.final as score_final,
					e.quality as score_quality,
					e.popularity as score_popularity,
					e.maintenance as score_maintenance,
					compress(compress(lowcase(catx(' ', f.keywords1, f.keywords2, f.keywords3, f.keywords4, f.keywords5, f.keywords6, f.keywords7, f.keywords8, f.keywords9, f.keywords10)), '.'), '-') as keywords
			from 	npms.objects a
					left join
					npms.objects_package b
					on a.ordinal_objects eq b.ordinal_objects
					left join
					npms.package_author c
					on b.ordinal_package eq c.ordinal_package
					left join
					npms.objects_score d
					on a.ordinal_objects eq d.ordinal_objects
					left join
					npms.score_detail e
					on d.ordinal_score eq e.ordinal_score
					left join
					npms.package_keywords f
					on b.ordinal_package eq f.ordinal_package
		;quit;run;

		libname npms;

		proc append base=data.npm_packages data=work.npm_packages force;run;

		proc sql noprint;
			select count(name) into:TMP_NPM_COUNT from work.npm_packages;
			select count(name) into:TMP_NPM_TOTAL from data.npm_packages;
		quit;
	%end;
%mend;

/* some clean-up */
proc datasets library=data nolist;
    delete npm_packages;
quit;

/* do the search */
%search(llm);
%search(openai);

/* sort packages by name */
proc sort data=data.npm_packages nodupkey;
	by name;
run;

/* create a unique identifier - mostly used for text topics analytics in VA */
data data.npm_packages(compress=yes);
	set data.npm_packages;
	package_id = compress(put(_n_,best12.));
run;

/* create a network data set given the keyword relationship  */
proc sql;
	create table work.npm_package_keywords as
	select 	input(a.package_id, 8.) as from_id,
			a.keywords as from_keywords,
			input(b.package_id, 8.) as to_id,
			b.keywords as to_keywords,
			case when calculated from_id lt calculated to_id then compress(a.package_id || b.package_id)
			else compress(b.package_id || a.package_id) end as link_id
	from	data.npm_packages a
			full join
			data.npm_packages b
			on a.package_id ne b.package_id;
;quit;run;

/* sort by unique link identifier */
proc sort data=work.npm_package_keywords nodupkey;
	by link_id;
run;

/* only keep records where we find a matching keyword */
data data.npm_package_network(compress=yes);
	set work.npm_package_keywords;

	length keyword $20.;

	do i=1 to countw(from_keywords);
		keyword = scan(from_keywords, i, ' ');
		if (findw(to_keywords,keyword,' ','sit')) then do;
			output;
		end;
	end;

	drop i from_keywords to_keywords;
run;

/* sort yet again  */
proc sort data=data.npm_package_network nodupkey;
	by from_id to_id keyword;
run;

/* find any potential missing leaf nodes in the source column */
proc sql;
	create table missing as select distinct to_id as from_id
	from data.npm_package_network
	where to_id not in (select distinct from_id from data.npm_package_network);
quit;

/* add any missing leaf nodes if required */
proc append base=data.npm_package_network data=missing force;
run;

/* create another network data set with joined package details and calculated weight */
proc sql;
	create table data.npm_package_network_compressed(compress=yes) as
	select  a.*, b.*, c.weight as keyword_weight
	from 	data.npm_package_network a
			left join
			data.npm_packages b
			on a.from_id eq input(b.package_id, 8.)
			left join
			(	select distinct from_id, to_id, count(*) as weight
				from data.npm_package_network
				group by from_id, to_id
			) c
			on a.from_id eq c.from_id and a.to_id eq c.to_id
;quit;run;

/* create the keywords network */
proc sql;
	create table work.npm_keyword_network as
	select 	a.from_id,
			a.to_id,
			b.keywords as from_keywords,
			c.keywords as to_keywords
	from	data.npm_package_network a
			left join
			data.npm_packages b
			on a.from_id eq input(b.package_id, 8.)
			left join
			data.npm_packages c
			on a.to_id eq input(c.package_id, 8.)
;quit;run;

/* write out a record with matching keywords */
data work.npm_keyword_network;
	set work.npm_keyword_network;

	length from_keyword $20. to_keyword $20.;

	do f=1 to countw(from_keywords);
		from_keyword = scan(from_keywords, f, ' ');
		do t=1 to countw(to_keywords);
			to_keyword = scan(to_keywords, t, ' ');
			output;
		end;
	end;

	keep from_keyword to_keyword;
run;

/* create final data set and drop any records with missing keywords */
proc sql;
	create table data.npm_keyword_network(compress=yes) as
	select distinct from_keyword, to_keyword, count(*) as count
	from work.npm_keyword_network
	where compress(from_keyword) ne '' and compress(to_keyword) ne '' and from_keyword ne to_keyword
	group by from_keyword, to_keyword
	having count ge 2
;quit;run;
