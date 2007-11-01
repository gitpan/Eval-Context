# pod and pod_coverage pod_spelling test

use strict ;
use warnings ;

use Test::Spelling;

add_stopwords
	(
	qw(
		AnnoCPAN
		CPAN
		
		CanonizeName
		CheckOptionNames
		GetPackageName
		SetInteractionDefault
		
		Nadim
		nadim
		Khemir
		khemir
		)
	) ;
	
all_pod_files_spelling_ok();
