# pod and pod_coverage pod_spelling test

use strict ;
use warnings ;

use Test::Spelling;

add_stopwords
	(
	qw(
		AnnoCPAN
		CPAN
		perlsec
		deserialized
		validator
		
		CanonizeName
		CheckOptionNames
		CleanupPackage
		EvalSetup
		EvalCleanup
		GetCallContextWrapper
		GetPackageName
		GetInstalledVariablesCode
		GetVariablesSetFromCaller
		GetPersistentVariablesSetFromCaller
		GetSharedVariablesSetFromCaller
		GetPersistantVariables
		GetPersistentVariableNames
		RemoveEvalSidePersistenceHandlers
		RemovePersistent
		SetEvalSidePersistenceHandlers
		SetInteractionDefault
		SetupSafeCompartment
		VerifyCodeInput
		VerifyAndCompleteOptions
		
		
		Nadim
		nadim
		Khemir
		khemir
		)
	) ;
	
all_pod_files_spelling_ok();
