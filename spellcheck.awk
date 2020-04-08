# spellcheck.awk -- interactive spell checker
#
# Author: 
#
# Usage: awk -f spellcheck.awk [+dict] file

BEGIN {
	if (ARGC > 1) {
		if (ARGC > 2) {
			if (ARGV[1] ~ /^\+.*/) {
				SPELLDICT = ARGV[1]
			}
			else {
				SPELLDICT = "+" ARGV[1]
			}
			SPELLFILE = ARGV[2]
			delete ARGV[1]
			delete ARGV[2]
		}
		else {
			SPELLFILE = ARGV[1]
			# if dict file exists
			if (system ("test -r dict") == 0 ) {
				printf("Use local dict file? [y/n]")
				getline reply < "-"
				if (reply ~ /[yY](es)?/) {
					SPELLDICT = "+dict"
				}
			}
		}
	}
	else {
		print "Usage: awk -f spellcheck.awk [+dict] file"
		exit 1
	}
	wordlist = "sp_wordlist"
	spellsource = "sp_source"
	spellout = "sp_out"
	system("cp " SPELLFILE " " spellsource)
	print "Running spell checker..."
	if (SPELLDICT)
		SPELLCMD = "spell " SPELLDICT " "
	else
		SPELLCMD = "spell "
	system(SPELLCMD spellsource " > " wordlist)

	if (system("test -s " wordlist) != 0) {
		# if test return value is not zero, wordlist is empty
		print "No misspelled words found."
		system("rm " wordlist spellsource)
		exit
	}

	ARGV[1] = wordlist # Make awk read this file

	responseList = "Responses: \n\tChange each occurrence,"
	responseList = responseList "\n\tGlobal change,"
	responseList = responseList "\n\tAdd to Dict,"
	responseList = responseList "\n\tHelp,"
	responseList = responseList "\n\tQuit"
	responseList = responseList "\n\tCR to ignore: "
	printf("%s", responseList)
}

function make_change(toChange, len,		line, should_change, toPrint, carets) {
	if (match(toChange, misspelled)) {
		toPrint = $0
		gsub(/\t/, " ", toPrint)
		print toPrint
		carets = "^"
		for (i = 1; i < RLENGTH; ++i)
			carets = carets "^"

		# FORMAT_STR is %<number_of_spaces>s to specify how many spaces to printf before carets
		if (len)
			FORMAT_STR = "%" len+RSTART+RLENGTH-2 "s\n"
		else
			FORMAT_STR = "%" RSTART+RLENGTH-1 "s\n"
		printf(FORMAT_STR, carets)

		if (! corrected) {
			printf "Change to: "
			getline corrected < "-"
		}

		while (corrected && !should_change) {
			printf("Change %s to %s? (y/n): ", misspelled, corrected)
			getline should_change < "-"
			changed = ""

			if (should_change ~ /[yY](es)?/)
				changed = sub(misspelled, corrected, toChange)
			else if (should_change ~ /[nN]o?/) {
				printf("Change to: ")
				getline corrected < "-"
				should_change = ""
			}
		}

		if (len) {
			line = substr($0, 1, len - 1)
			$0 = line toChange
		}
		else {
			$0 = toChange
			if (changed)
				++changes
		}
		if (changed)
			changedLines[changes] = ">" $0

		len += RSTART + RLENGTH
		part1 =	substr($0, 1, len - 1)
		part2 = substr($0, len)
		make_change(part2, len)
	}
}

function make_global_change(	corrected, should_change, changes) {
	printf("Change all occurences to: ")
	getline corrected < "-"
	while (corrected && !should_change) {
		printf("Change all %s to %s ? (y/n): ", misspelled, corrected)
		getline should_change < "-"
		changed = ""

		if (should_change ~ /[yY](es)?/) {
			while ((getline < spellsource) > 0) {
				if ($0 ~ misspelled) {
					changed = gsub(misspelled, corrected)
					print ">", $0
					++changes
				}
				print > spellout
			}
			close(spellsource)
			close(spellout)
			printf("%d lines changed", changes)
			confirm_changes()
		}
		else if (should_change ~ /[nN]o?/) {
			printf("Change all occurences to: ")
			getline corrected < "-"
			should_change = ""
		}
	}
}

function confirm_changes(	save_changes) {
	while (!save_changes) {
		printf("Save changes ?(y/n): ")
		getline save_changes < "-"
	}

	if (save_changes ~ /[yY](es)?/) {
		system("mv " spellout " " spellsource)
	}
}

{
	misspelled = $1
	response = 1
	++word_count
	
	while (response !~ /(^[cCgGaAhHqQ])|^$/) {
		printf("\n%d - Found %s (C/G/A/H/Q/):", word_count, misspelled)
		getline response < "-"
	}

	if (response ~ /[hH](elp)?/) {
		printf("%s", responseList)
		printf("\n%d - Found %s (C/G/A/H/Q/):", word_count, misspelled)
		getline response < "-"
	}
	if (response ~ /[qQ](uit)?/)
		exit
	if (response ~ /[aA](dd)?/)
		dict[++dict_entry_count] = misspelled
	if (response ~ /[cC](ange)?/) {
		corrected = ""
		changes = ""
		while ((getline < spellsource) > 0) {
			make_change($0)
			print > spellout
		}
		close(spellout)
		close(spellsource)
		if (changes) {
			for (i = 1; i <= changes ; ++i) {
				print changedLines[i]
			}
			printf("%d lines changed. ", changes)
			confirm_changes()
		}
	}
	if (response ~ /[gG](lobal)?/)
		make_global_change()
}

END {
	if (NR <= 1)
		exit
	while (saveResponse !~ /([Yy](es)?)|([Nn]o?)/) {
		printf("Save corrections in %s (y/n)? ", SPELLFILE)
		getline saveResponse < "-"
	}

	if (saveResponse ~ /[Yy](es)?/) {
		system("cp " SPELLFILE " " SPELLFILE ".orig")
		system("mv " spellsource " " SPELLFILE)
	}
	if (saveResponse ~ /[Nn]o?/)
		system("rm " spellsource)

	if (dict_entry_count > 0) {
		printf("Save new words to dictionary (y/n)?")
		getline response < "-"

		if (response ~ /[yY](es)?/) {
			if (! SPELLDICT)
				SPELLDICT = "dict"
			sub(/^\+/, "", SPELLDICT)
			for (item in dict)
				print dict[item] >> SPELLDICT
			close(SPELLDICT)

			system("sort " SPELLDICT " > tmp_dict")
			system("mv tmp_dict " SPELLDICT)
		}
	}
	system("rm " wordlist)
}
