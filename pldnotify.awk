#!/bin/awk -f
#
# Copyright (C) 2000-2021 PLD-Team <feedback@pld-linux.org>
# Authors:
#	Sebastian Zagrodzki <zagrodzki@pld-linux.org>
#	Jacek Konieczny <jajcus@pld-linux.org>
#	Andrzej Krzysztofowicz <ankry@pld-linux.org>
#	Jakub Bogusz <qboosh@pld-linux.org>
#	Elan Ruusamäe <glen@pld-linux.org>
#
# See git log pldnotify.awk for list of contributors
#
# TODO:
# - "SourceXDownload" support (use given URLs if present instead of cut-down SourceX URLs)
# - "SourceXActiveFTP" support
# - support debian/watch http://wiki.debian.org/debian/watch/

# NOTE:
# to test run this, run:
# $ awk -vDEBUG=1 -f pldnotify.awk < specfile
#
# To get full out of it, you need to have following tools installed:
# - perl, sed, wget, coreutils, util-linux
# - perl-HTML-Tree (HTML::TreeBuilder module) for better links parser (-vUSE_PERL=0 to disable)
# - pear (php-pear-PEAR) for php-pear package updates
# - npm for nodejs packages
# - gem (ruby-rubygems) for ruby/rubygem packages
# - curl, jq to parse data from from release-monitoring.org
# 
# Additionally "mirrors" file in current dir, controls local mirrors you prefer

function d(s) {
	if (!DEBUG) {
		return
	}

#	print strftime("%Y-%m-%d %H:%M:%S ") s >> "/dev/stderr"
	print s >> "/dev/stderr"
}

function fixedsub(s1,s2,t,	ind) {
# substitutes fixed strings (not regexps)
	if (ind = index(t,s1)) {
		t = substr(t, 1, ind-1) s2 substr(t, ind+length(s1))
	}
	return t
}

function ispre(s) {
	if ((s~"pre")||(s~"PRE")||(s~"beta")||(s~"BETA")||(s~"alpha")||(s~"ALPHA")||(s~"rc")||(s~"RC")) {
		d("pre-version")
		return 1
	} else {
		return 0
	}
}

function compare_ver(v1,v2) {
# compares version numbers
	while (match(v1,/[a-zA-Z][0-9]|[0-9][a-zA-Z]/))
		v1=(substr(v1,1,RSTART) "." substr(v1,RSTART+RLENGTH-1))
	while (match(v2,/[a-zA-Z][0-9]|[0-9][a-zA-Z]/))
		v2=(substr(v2,1,RSTART) "." substr(v2,RSTART+RLENGTH-1))
	sub("^0*","",v1)
	sub("^0*","",v2)
	gsub("\.0*",".",v1)
	gsub("\.0*",".",v2)
	d("v1 == " v1)
	d("v2 == " v2)
	count=split(v1,v1a,"\.")
	count2=split(v2,v2a,"\.")

	if (count<count2) mincount=count
	else mincount=count2

	for (i=1; i<=mincount; i++) {
		if (v1a[i]=="") v1a[i]=0
		if (v2a[i]=="") v2a[i]=0
		d("i == " i)
		d("v1[i] == " v1a[i])
		d("v2[i] == " v2a[i])
		if ((v1a[i]~/[0-9]/)&&(v2a[i]~/[0-9]/)) {
			if (length(v2a[i])>length(v1a[i]))
				return 1
			else if (v2a[i]>v1a[i])
				return 1
			else if (length(v1a[i])>length(v2a[i]))
				return 0
			else if (v1a[i]>v2a[i])
				return 0
		} else if ((v1a[i]~/[A-Za-z]/)&&(v2a[i]~/[A-Za-z]/)) {
			if (v2a[i]>v1a[i])
				return 1
			else if (v1a[i]>v2a[i])
				return 0
		} else if (ispre(v1a[i]) == 1)
			return 1
		else
			return 0
	}
	if ((count2==mincount)&&(count!=count2)) {
		for (i=count2+1; i<=count; i++)
			if (ispre(v1a[i]) == 1)
				return 1
		return 0
	} else if (count!=count2) {
		for (i=count+1; i<=count2; i++)
			if (ispre(v2a[i]) == 1)
				return 0
		return 1
	}
	return 0
}

function compare_ver_dec(v1,v2) {
# compares version numbers as decimal floats
	while (match(v1,/[0-9][a-zA-Z]/))
		v1=(substr(v1,1,RSTART) "." substr(v1,RSTART+RLENGTH-1))
	while (match(v2,/[0-9][a-zA-Z]/))
		v2=(substr(v2,1,RSTART) "." substr(v2,RSTART+RLENGTH-1))
	sub("^0*","",v1)
	sub("^0*","",v2)
	d("v1 == " v1)
	d("v2 == " v2)
	count=split(v1,v1a,"\.")
	count2=split(v2,v2a,"\.")

	if (count<count2) mincount=count
	else mincount=count2

	for (i=1; i<=mincount; i++) {
		if (v1a[i]=="") v1a[i]=0
		if (v2a[i]=="") v2a[i]=0
		d("i == " i)
		d("v1[i] == " v1a[i])
		d("v2[i] == " v2a[i])
		if ((v1a[i]~/[0-9]/)&&(v2a[i]~/[0-9]/)) {
			if (i==2) {
				if (0+("." v2a[i])>0+("." v1a[i]))
					return 1
				else if (0+("." v1a[i])>0+("." v2a[i]))
					return 0
			} else {
				if (length(v2a[i])>length(v1a[i]))
					return 1
				else if (v2a[i]>v1a[i])
					return 1
				else if (length(v1a[i])>length(v2a[i]))
					return 0
				else if (v1a[i]>v2a[i])
					return 0
			}
		} else if ((v1a[i]~/[A-Za-z]/)&&(v2a[i]~/[A-Za-z]/)) {
			if (v2a[i]>v1a[i])
				return 1
			else if (v1a[i]>v2a[i])
				return 0
		} else if (ispre(v1a[i]) == 1)
			return 1
		else
			return 0
	}
	if ((count2==mincount)&&(count!=count2)) {
		for (i=count2+1; i<=count; i++)
			if (ispre(v1a[i]) == 1)
				return 1
		return 0
	} else if (count!=count2) {
		for (i=count+1; i<=count2; i++)
			if (ispre(v2a[i]) == 1)
				return 0
		return 1
	}
	return 0
}

function link_seen(link) {
	for (seenlink in frameseen) {
		if (seenlink == link) {
			d("Link: [" link "] seen already, skipping...")
			return 1
		}
	}
	frameseen[link]=1
	return 0
}

function mktemp(   _cmd, _tmpfile) {
	_cmd = "mktemp /tmp/XXXXXX"
	_cmd | getline _tmpfile
	close(_cmd)
	return _tmpfile
}

# fix link to artificial one that will be recognized rest of this script
function postfix_link(url, link,   oldlink) {
	oldlink = link
	if ((url ~/^(http|https):\/\/github.com\//) && (link ~ /.*\/tarball\//)) {
		gsub(".*\/tarball\/", "", link)
		link = link ".tar.gz"
	}
	if (oldlink != link) {
		d("POST FIXED URL [ " oldlink " ] to [ " link " ]")
	}
	return link
}

# use perl HTML::TreeBuilder module to extract links from html
# it returns TAGNAME LINK in output which is pretty stright forward to parse in awk
function extract_links_cmd(tmpfile) {
	return "perl -MHTML::TreeBuilder -e ' \
	my $content = join q//, <>; \
	my $root = new HTML::TreeBuilder; \
	$root->parse($content); \
	\
	my %links = (); \
	for (@{$root->extract_links(qw(a iframe))}) { \
		my($link, $element, $attr, $tag) = @$_; \
		$links{$link} = $tag; \
	} \
	\
	while (my($link, $tag) = each %links) { \
		print $tag, q/ /, $link, $/; \
	} \
	' " tmpfile
}

# get all <A HREF=..> tags from specified URL
function get_links(url,filename,   errno,link,oneline,retval,odp,wholeodp,lowerodp,tmpfile,cmd) {

	wholeerr=""

	tmpfile = mktemp()
	tmpfileerr = mktemp()

	if (url ~ /^http:\/\/(download|downloads|dl)\.(sf|sourceforge)\.net\//) {
		newurl = url
		# http://dl.sourceforge.net/threestore/
		# http://downloads.sourceforge.net/project/mediainfo/source/mediainfo/
		gsub("^http://(download|downloads|dl)\.(sf|sourceforge)\.net/", "", newurl)
		gsub("^project/", "", newurl)
		gsub("/.*", "", newurl)
		url = "http://sourceforge.net/projects/" newurl "/rss?path=/"
		d("sf url, mangled url to: " url)

	} else if (url ~ /^http:\/\/(.*)\.googlecode\.com\/files\//) {
		gsub("^http://", "", url)
		gsub("\..*", "", url)
		url = "http://code.google.com/p/" url "/downloads/list"
		d("googlecode url, mangled url to: " url)

	} else if (url ~ /^http:\/\/pecl.php.net\/get\//) {
		gsub("-.*", "", filename)
		url = "http://pecl.php.net/package/" filename
		d("pecl.php.net url, mangled url to: " url)

	} else if (url ~/http:\/\/cdn.mysql.com\//) {
		gsub("http:\/\/cdn.mysql.com\/", "", url)
		url = "http://vesta.informatik.rwth-aachen.de/mysql/" url
		d("mysql CDN, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/launchpad\.net\/(.*)\//) {
		gsub("^(http|https):\/\/launchpad\.net\/", "", url)
		gsub("\/.*/", "", url)
		url = "https://code.launchpad.net/" url "/+download"
		d("main launchpad url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/edge\.launchpad\.net\/(.*)\//) {
		gsub("^(http|https):\/\/edge\.launchpad\.net\/", "", url)
		gsub("\/.*/", "", url)
		url = "https://edge.launchpad.net/" url "/+download"
		d("edge launchpad url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/github.com\/.*\/(.*)\/tarball\//) {
		gsub("\/tarball\/.*", "/downloads", url)
		d("github tarball url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/github.com\/.*\/(.*)\/archive\//) {
		gsub("\/archive\/.*", "/tags", url)
		d("github archive url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/github.com\/.*\/(.*)\/releases\/download\//) {
		gsub("\/download\/.*", "/", url)
		d("github download url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/bitbucket.org\/.*\/get\/.*/) {
		# https://bitbucket.org/logilab/pylint/get/tip.tar.bz2 -> https://bitbucket.org/logilab/pylint/downloads
		gsub("\/get\/.*", "/downloads", url)
		d("github bitbucket url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/cgit\..*\/(.*)\/snapshot\//) {
		gsub("\/snapshot\/.*", "/", url)
		d("cgit snapshot tarball url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/www2\.aquamaniac\.de\/sites\/download\//) {
		url = "http://www2.aquamaniac.de/sites/download/packages.php"
		d("aquamaniac.de tarball url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/www.process-one.net\/downloads\/ejabberd\//) {
		url = "http://www.process-one.net/en/ejabberd/archive/"
		d("ejabberd tarball url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/llvm.org\/releases\//) {
		url = "http://llvm.org/releases/download.html"
		d("llvm tarball url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/download\.owncloud\.org\/community\//) {
		url = "http://owncloud.org/changelog/"
		d("owncloud tarball url, mangled url to: " url)

	} else if (url ~ /^(http|https):\/\/hackage\.haskell\.org\/packages\/archive\//) {
		gsub("\/packages\/archive","/package",url)
		d("hackage haskell tarball url, mangled url to: " url)

	} else if (url ~ /^http:\/\/www.taskwarrior.org\/download\//) {
		url = "http://taskwarrior.org/projects/taskwarrior/wiki/Download"
		d("taskwarrior tarball url, mangled url to: " url)
	} else if (url ~/^http:\/\/www.rarlab.com\/rar\// && filename ~ /^unrarsrc/) {
		url = "http://www.rarlab.com/rar_add.htm"
		d("unrar tarball url, mangled url to: " url)
	} else if (url ~/^http:\/\/www.rarlab.com\/rar\//) {
		url = "http://www.rarlab.com/download.htm"
		d("rar tarball url, mangled url to: " url)
	} else if (url ~/^(http|https):\/\/pypi.python.org\/packages\/source\/.*/) {
		gsub("/packages/source/[a-zA-Z0-9]/", "/pypi/", url)
		d("pypi.python.org 1 url, mangled url to: " url)
	} else if (url ~/^(http|https):\/\/pypi.python.org\/packages\/.*/) {
		project = filename
		gsub("-[0-9]+.*", "", project)
		gsub("/packages/.*/", "/pypi/" project, url)
		d("pypi.python.org 2 url, mangled url to: " url)
	} else if (url ~/^(http|https):\/\/files\.pythonhosted\.org\/packages\/.*/) {
		project = filename
		gsub("-[0-9]+.*", "", project)
		gsub("/packages/.*/", "/pypi/" project, url)
		gsub("files\.pythonhosted\.org", "pypi.python.org", url)
		d("files.pythonhosted.org url, mangled url to: " url)
	} else if (url ~/^ftp:\/\/ftp.debian.org\//) {
		gsub("ftp://ftp.debian.org/", "http://ftp.debian.org/", url)
		d("ftp://ftp.debian.org url, mangled url to: " url)
	}

	d("Retrieving: " url)
	user_agent = "Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2) Gecko/20100129 PLD/3.0 (Th) Iceweasel/3.6"
	cmd = "wget -t 2 -T 45 --user-agent \"" user_agent "\" -nv -O - \"" url "\" --passive-ftp --no-check-certificate > " tmpfile " 2> " tmpfileerr
	d("Execute: " cmd)
	errno = system(cmd)
	d("Execute done")

	if (errno != 0) {
		d("Reading failure response...")
		wholeerr = ""
		while (getline oneline < tmpfileerr)
			wholeerr = (wholeerr " " oneline)
		d("Error Response: " wholeerr)

		system("rm -f " tmpfile)
		system("rm -f " tmpfileerr)
		retval = ("WGET ERROR: " errno ": " wholeerr)
		return retval
	}
	system("rm -f " tmpfileerr)

	urldir = url;
	sub(/[^\/]+$/, "", urldir)

if (USE_PERL) {
	cmd = extract_links_cmd(tmpfile)
	while (cmd | getline) {
		tag = $1
		link = substr($0, length(tag) + 2)

		if (tag == "iframe") {
			d("Frame: " link)
			if (url !~ /\//) {
				link = (urldir link)
				d("Frame->: " link)
			}

			if (link_seen(link)) {
				continue
			}
			retval = (retval " " get_links(link))
		}

		if (link_seen(link)) {
			continue
		}

		retval = (retval " " link)
		d("href(): " link)
	}
	close(cmd)

}

	wholeodp = ""
	d("Reading success response...")
	while (getline oneline < tmpfile) {
		wholeodp = (wholeodp " " oneline)
#		d("Response: " wholeodp)
	}
	d("Reponse read done...")
	system("rm -f " tmpfile)

	# MATCH one of these:
	#while (match(wholeodp, /<([aA]|[fF][rR][aA][mM][eE])[ \t][^>]*>/) > 0) {
	#while (match(wholeodp, /<link>[^<]*<\/link>/) > 0) {

	while (match(wholeodp, /(<link>[^<]*<\/link>|<([aA]|[fF][rR][aA][mM][eE])[ \t][^>]*>)/) > 0) {
		d("Processing links...")
		odp = substr(wholeodp,RSTART,RLENGTH);
		wholeodp = substr(wholeodp,RSTART+RLENGTH);

		lowerodp = tolower(odp);
		if (lowerodp ~ /<frame[ \t]/) {
			sub(/[sS][rR][cC]=[ \t]*/, "src=", odp);
			match(odp, /src="[^"]+"/)
			newurl = substr(odp, RSTART+5, RLENGTH-6)
			d("Frame: " newurl)
			if (newurl !~ /\//) {
				newurl=(urldir newurl)
				d("Frame->: " newurl)
			}

			if (link_seen(newurl)) {
				newurl = ""
				continue
			}

			retval = (retval " " get_links(newurl))
			d("href('condition1': " newurl)
		} else if (lowerodp ~ /href=[ \t]*"[^"]*"/) {
			sub(/[hH][rR][eE][fF]=[ \t]*"/,"href=\"",odp)
			match(odp,/href="[^"]*"/)
			link=substr(odp,RSTART,RLENGTH)
			odp=substr(odp,1,RSTART) substr(odp,RSTART+RLENGTH)
			link=substr(link,7,length(link)-7)
			link=postfix_link(url, link)

			if (link_seen(link)) {
				link=""
				continue
			}

			# link ends with at least 2 digit version
			mlink = ""
			if (link ~ /^.*\/[v]*[0-9\.]+[0-9]\/$/)
				mlink = get_links(link)

			retval = (retval " " link " " mlink)
			d("href('condition2'): " link)
		} else if (lowerodp ~ /href=[ \t]*'[^']*'/) {
			sub(/[hH][rR][eE][fF]=[ \t]*'/,"href='",odp)
			match(odp,/href='[^']*'/)
			link=substr(odp,RSTART,RLENGTH)
			odp=substr(odp,1,RSTART) substr(odp,RSTART+RLENGTH)
			link=substr(link,7,length(link)-7)
			link=postfix_link(url, link)

			if (link_seen(link)) {
				link=""
				continue
			}

			retval = (retval " " link)
			d("href('condition3'): " link)
		} else if (lowerodp ~ /href=[ \t]*[^ \t>]*/) {
			sub(/[hH][rR][eE][fF]=[ \t]*/,"href=",odp)
			match(odp,/href=[^ \t>]*/)
			link=substr(odp,RSTART,RLENGTH)
			odp=substr(odp,1,RSTART) substr(odp,RSTART+RLENGTH)
			link=substr(link,6,length(link)-5)

			if (link_seen(link)) {
				link=""
				continue
			}

			retval = (retval " " link)
			d("href('condition4'): " link)
		} else if (lowerodp ~ /<link>/) {
			link=lowerodp
			sub("/<link>/", link)
			sub("/\/download<\/link>/", link)

			if (link_seen(link)) {
				link=""
				continue
			}

			retval = (retval " " link)
			d("href('condition5'): " link)
		} else {
			# <a ...> but not href - skip
			d("skipping <a > without href: " odp)
		}
	}

	d("Returning: [" retval "]")
	return retval
}

function subst_defines(var,defs) {
# substitute all possible RPM macros
	while ((var ~ /%{.*}/) || (var ~ /%[A-Za-z0-9_]+/)) {
		oldvar=var
		for (j in defs) {
			gsub("%{" j "}", defs[j], var)
			gsub("%" j , defs[j], var)
			# conditional macros like %{?patchlevel:.5} - drop these for now
			gsub("%{\?" j ":.*?}", "", var)
		}
		if (var==oldvar) {
			if (DEBUG) {
				for (i in defs) {
					d(i " == " defs[i])
				}
			}
			return var
		}
	}
	return var
}

function find_mirror(url) {

	while (succ = (getline line < "mirrors")) {
	    if (succ==-1) { return url }
		nf=split(line,fields,"|")
		if (nf>1){
			origin=fields[1]
			mirror=fields[2]
			mname=fields[3]
			prefix=substr(url,1,length(origin))
			if (prefix==origin){
				d("Mirror found at " mname)
				close("mirrors")
				return mirror substr(url,length(origin)+1)
			}
		}
	}

	return url
}

# fetches file list, and compares version numbers
function process_source(number, lurl, name, version) {
	d("Processing " lurl)

	if (index(lurl, version) == 0) {
		d("There is no version number ["version"] in ["lurl"]")
		return 0
	}

	sub("://",":",lurl)
	sub("/",":/",lurl)
	gsub("[^/]*$",":&",lurl)
	split(lurl,url,":")
	acc=url[1]
	host=url[2]
	dir=url[3]
	filename=url[4]

	if (index(dir,version)) {
		# directory name as version maching mode:
		# if /something/version/name-version.tarball then check
		# in /something/ looking for newer directory
		dir=substr(dir,1,index(dir,version)-1)
		sub("[^/]*$","",dir)
		sub("(\.tar\.(bz|bz2|gz|lzma|xz)|zip)$","",filename)
	}

	d("Will check a directory: " dir)
	d("and a file: " filename)

	filenameexp=filename
	gsub("[+]","\\+",filenameexp)
	sub(version,"[A-Za-z0-9.]+",filenameexp)
	gsub("[.]","\\.",filenameexp)
	sub("\.(bz|bz2|gz|lzma|xz|zip)$",".(bz|bz2|gz|lzma|xz|zip)",filenameexp)
	d("Expression: " filenameexp)
	match(filename,version)
	prever=substr(filename,1,RSTART-1)
	postver=substr(filename,RSTART+RLENGTH)
	d("Before number: " prever)
	d("and after: " postver)
	newurl=find_mirror(acc "://" host dir)
	#print acc "://" host dir
	#newurl=url[1]"://"url[2]url[3]url[4]
	#newurl=acc "://" host dir filename
	d("Looking at " newurl)

	references=0
	finished=0
	oldversion=version
	odp = get_links(newurl, filename)
	if( odp ~ "ERROR: ") {
		print name "(" number ") " odp
	} else {
		d("WebPage downloaded")
		c=split(odp,linki)
		for (nr=1; nr<=c; nr++) {
			addr=linki[nr]

			d("Found link: " addr)

			# Try not to treat foobar or foo-bar as (possibly newer) version of bar
			# (practical cases: KXL, lineakconfig, mhash...)
			# but don't skip cases where name is like "/some/link/0.12.2.tar.gz"
			if ((addr ~ "[-_.0-9A-Za-z~]" filenameexp) && addr !~ "[-_.0-9A-Za-z~]/" filenameexp)  {
				continue
			}

			if (addr ~ filenameexp) {
				match(addr,filenameexp)
				newfilename=substr(addr,RSTART,RLENGTH)
				d("Hypothetical new: " newfilename)
				newfilename=fixedsub(prever,"",newfilename)
				newfilename=fixedsub(postver,"",newfilename)
				d("Version: " newfilename)
				if (newfilename ~ /\.(asc|sig|pkg|bin|binary|built)$/) continue
				# strip ending (happens when in directiory name as version matching mode)
				sub("(\.tar\.(bz|bz2|gz|lzma|xz)|zip)$","",newfilename)
				if (NUMERIC) {
					if ( compare_ver_dec(version, newfilename)==1 ) {
						d("Yes, there is new one")
						version=newfilename
						finished=1
					}
				} else if ( compare_ver(version, newfilename)==1 ) {
					d("Yes, there is new one")
					version=newfilename
					finished=1
				}
			}
		}
		if (finished == 0)
			print name "(" number ") seems ok: " oldversion
		else
			print name "(" number ") [OLD] " oldversion " [NEW] " version
	}
}

function rss_upgrade(name, ver, url, regex, cmd) {
	regex = "s/.*<title>" regex "<\/title>.*/\\1/p"
	cmd = "wget -t 2 -T 45 -q -O - " url " | sed -nre '" regex "' | head -n1"

	d("rss_upgrade_cmd: " cmd)
	cmd | getline ver
	close(cmd)

	return ver
}

# check for ZF upgrade from rss
function zf_upgrade(name, ver) {
	return rss_upgrade(name, ver, \
		"http://devzone.zend.com/tag/Zend_Framework_Management/format/rss2.0", \
		"Zend Framework ([^\\s]+) Released" \
	);
}

# upgrade check for pear package using PEAR CLI
function pear_upgrade(name, ver,    cmd) {
	sub(/^php-pear-/, "", name);

	cmd = "pear remote-info " name " | awk '/^Latest/{print $NF}'"
	d("PEAR: " cmd)
	cmd | getline ver
	close(cmd)

	return ver
}

function vim_upgrade(name, ver,     cmd) {
	# %patchset_source -f ftp://ftp.vim.org/pub/editors/vim/patches/7.2/7.2.%03g 1 %{patchlevel}
	cmd = "wget -q -O - ftp://ftp.vim.org/pub/editors/vim/patches/" DEFS["ver"] "/MD5SUMS|grep -vF .gz|tail -n1|awk '{print $2}'"
	d("VIM: " cmd)
	cmd | getline ver
	close(cmd)
	return ver
}

function nodejs_upgrade(name, ver,   cmd) {
	d("NODEJS " name " (as " DEFS["pkg"] ") " ver);
	if (DEFS["pkg"]) {
		cmd = "npm info " DEFS["pkg"] " dist-tags.latest"
	} else {
		cmd = "npm info " name " dist-tags.latest"
	}
	cmd | getline ver
	close(cmd)

	return ver
}

function rubygem_upgrade(name, ver,   cmd, pkg) {
	if (DEFS["gem_name"]) {
		pkg = DEFS["gem_name"];

	} else if (DEFS["gemname"]) {
		pkg = DEFS["gemname"];

	} else if (DEFS["pkgname"]) {
		pkg = DEFS["pkgname"];

	} else {
		pkg = name;
		gsub(/^ruby-/, "", pkg);
	}

	cmd = "gem list --remote '^" pkg "$' | awk '/" pkg "/ {v=$2; sub(/\(/, \"\", v); sub(/\)$/, \"\", v); print v}'"
	d("RUBYGEM " name " (as " pkg ") " ver ": " cmd);
	cmd | getline ver

	close(cmd)

	return ver
}

function google_linux_repo(name, ver, reponame,   cmd, sourceurl) {
	sourceurl = "http://dl.google.com/linux/" reponame "/rpm/stable/x86_64/repodata/primary.xml.gz"
	cmd = "curl -m 45 -s " sourceurl " | zcat | perl -ne 'm{<name>" name "-" DEFS["state"] "</name>} and m{<version .*ver=.([\d.]+)} and print $1'"
	d("google repo: " cmd);
	cmd | getline ver
	close(cmd)

	return ver
}

function jenkins_upgrade(name, ver, urls,  url, i, c, chunks, nver) {
	for (i in urls) {
		url = urls[i]
		# http://mirrors.jenkins-ci.org/war-stable/1.509.1/jenkins.war?/jenkins-1.509.1.war
		gsub("/" ver "/jenkins.war\?/jenkins-" ver ".war", "/", url);
		c = split(get_links(url), chunks, "/")
		# new version is second one from the bottom
		nver = chunks[c - 2]
		gsub(/ /, "", nver)
		return nver;
	}
}

# check for update from release-monitoring.org
function rmo_check(name,    sourceurl, cmd, ver) {
	sourceurl = "https://release-monitoring.org/api/project/pld-linux/" name
	cmd = "curl -m 45 -sSf " sourceurl " | jq -r .version"
	d("rmo: " cmd);
	cmd | getline ver
	close(cmd)
	d("rmo: -> " ver);

	if (ver == "null") {
		return ""
	}

	# strip vX.Y -> X.y
	sub("^v", "", ver)

	return ver
}

# check github rss
function githubrss(name, sourceurl) {
	# https://github.com/giampaolo/psutil/archive/release-5.3.7/psutil-5.3.7.tar.gz
	gsub(".*github.com\/", "", sourceurl)
	gsub("\/archive\/.*", "", sourceurl)
	gsub("\/releases\/.*", "", sourceurl)
	repo = sourceurl
	relurl = "https://github.com/" repo "/releases.atom"
	cmd = "curl -m 45 -sSf " relurl " | grep '<title>' | sed -e 's#.*<title>##g' -e 's#</title>##g' | head -n 2 | tail -n 1"
	d("githubrss rel: " cmd);
	cmd | getline ghrel
	close(cmd)
	d("githubrss tag: " ghrel)

	# strip whatever until -
	sub("^.*-", "", ghrel)
	sub(" .*", "", ghrel)
	sub(":.*", "", ghrel)
	if (ghrel) {
		return ghrel
	}

	tagsurl = "https://api.github.com/" repo "/tags.atom"
	cmd = "curl -m 45 -sSf " tagsurl " | grep '<title>' | sed -e 's#.*<title>##g' -e 's#</title>##g' | head -n 2 | tail -n 1"
	d("githubrss tag: " cmd);
	cmd | getline ghtag
	close(cmd)
	d("githubrss tag: " ghtag)

	sub("^.*-", "", ghtag)
	sub(" .*", "", ghtag)
	sub(":.*", "", ghtag)
	if (ghtag) {
		return ghtag
	}
}


function array_first(arr) {
	for (i in arr)
		return arr[i]
}

function process_data(name, ver, rel, src, nver, i) {
	if (name ~ /^php-pear-/) {
		nver = pear_upgrade(name, ver);
	} else if (name == "ZendFramework") {
		nver = zf_upgrade(name, ver);
	} else if (name == "vim") {
		nver = vim_upgrade(name, ver);
	} else if (name == "google-chrome") {
		nver = google_linux_repo(name, ver, "chrome");
	} else if (name == "google-talkplugin") {
		nver = google_linux_repo(name, ver, "talkplugin");
	} else if (name ~ "^nodejs-") {
		nver = nodejs_upgrade(name, ver);
	} else if (name ~ "^ruby-" || name == "chef") {
		nver = rubygem_upgrade(name, ver);
	} else if (name ~ "jenkins") {
		nver = jenkins_upgrade(name, ver, src);
	} else if (name && array_first(src) ~ /github.com/) {
		nver = githubrss(name, array_first(src));
	} else if (name) {
		nver = rmo_check(name);
	}

	if (nver) {
		if (compare_ver(ver, nver)) {
			print name " [OLD] " ver " [NEW] " nver
			return
		}
	}

	if (name == "xulrunner") {
		ver = subst_defines(DEFS["firefox_ver"], DEFS)
		d("package xulrunner, change version to firefox ["ver"]")
	}

# this function checks if substitutions were valid, and if true:
# processes each URL and tries to get current file list
	for (i in src) {
		if (src[i] ~ /%{nil}/) {
			gsub(/\%\{nil\}/, "", src[i])
		}
		if ( src[i] !~ /%{.*}/ && src[i] !~ /%[A-Za-z0-9_]/ )  {
			d("Source: " src[i])
			process_source(i, src[i], name, ver)
		} else {
			print FNAME ":" i ": impossible substitution: " src[i]
		}
	}
}

BEGIN {
	# use perl links extraction by default
	USE_PERL = 1

	# if you want to use DEBUG, run script with "-v DEBUG=1"
	# or uncomment the line below
	# DEBUG = 1

	errno=system("wget --help > /dev/null 2>&1")
	if (errno && errno != 3) {
		print "No wget installed!"
		exit 1
	}
	if (ARGC>=3 && ARGV[2]=="-n") {
		NUMERIC=1
		for (i=3; i<ARGC; i++) ARGV[i-1]=ARGV[i]
		ARGC=ARGC-1
	}
}

FNR==1 {
	if ( ARGIND != 1 ) {
		# clean frameseen for each ARG
		for (i in frameseen) {
			delete frameseen[i]
		}
		frameseen[0] = 1

		process_data(NAME,VER,REL,SRC)
		NAME="" ; VER="" ; REL=""
		for (i in DEFS) delete DEFS[i]
		for (i in SRC) delete SRC[i]
	}
	FNAME=FILENAME
	DEFS["_alt_kernel"]=""
	DEFS["20"]="\\ "
	DEFS["nil"]=""
}

/^[Uu][Rr][Ll]:/&&(URL=="") { URL=subst_defines($2,DEFS) ; DEFS["url"]=URL }
/^[Nn]ame:/&&(NAME=="") { NAME=subst_defines($2,DEFS) ; DEFS["name"]=NAME }
/^[Vv]ersion:/&&(VER=="") { VER=subst_defines($2,DEFS) ; DEFS["version"]=VER }
/^[Rr]elease:/&&(REL=="") { REL=subst_defines($2,DEFS) ; DEFS["release"]=REL }
/^[Ss]ource[0-9]*:/ { if (/(ftp|http|https):\/\//) SRC[FNR]=subst_defines($2,DEFS) }
/%define/ { DEFS[$2]=subst_defines($3,DEFS) }

END {
	process_data(NAME,VER,REL,SRC)
}
